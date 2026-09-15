#!/usr/bin/env bash
set -e

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$DIR"

LTI_URL=""
while [[ $# -gt 0 ]]; do
  case $1 in
    --lti-url)
      LTI_URL="$2"
      shift 2
      ;;
    -h|--help)
      echo "Verwendung: ./start.sh [--lti-url <URL>]"
      echo "Startet die lokale Moodle-Entwicklungsumgebung mit vorkonfiguriertem Kurs."
      exit 0
      ;;
    *)
      echo "Unbekannter Parameter: $1"
      exit 1
      ;;
  esac
done

# 1. Container-Runtime erkennen (Docker bevorzugt, Podman als Fallback)
if command -v docker >/dev/null 2>&1 && docker info >/dev/null 2>&1; then
    CONTAINER_ENGINE="docker"
elif command -v podman >/dev/null 2>&1 && podman info >/dev/null 2>&1; then
    CONTAINER_ENGINE="podman"
    echo "==> Docker nicht gefunden, verwende Podman."

    if ! command -v podman-compose >/dev/null 2>&1; then
        echo "Fehler: podman-compose ist nicht installiert (wird fuer den Compose-Fallback benoetigt)."
        exit 1
    fi

    # moodle-docker-compose ruft "docker"/"docker-compose" fest verdrahtet auf.
    # Wir legen daher lokale Shims an, die auf Podman umleiten, und stellen sie
    # nur fuer den Compose-Aufruf per PATH voran.
    PODMAN_SHIM_DIR="$(mktemp -d)"
    trap 'rm -rf "$PODMAN_SHIM_DIR"' EXIT

    cat > "${PODMAN_SHIM_DIR}/docker" <<'EOF'
#!/usr/bin/env bash
exec podman "$@"
EOF
    cat > "${PODMAN_SHIM_DIR}/docker-compose" <<'EOF'
#!/usr/bin/env bash
exec podman-compose "$@"
EOF
    chmod +x "${PODMAN_SHIM_DIR}/docker" "${PODMAN_SHIM_DIR}/docker-compose"

    export PATH="${PODMAN_SHIM_DIR}:${PATH}"
else
    echo "Fehler: Weder Docker noch Podman gefunden bzw. deren Daemon läuft nicht."
    exit 1
fi

# 2. Submodule initialisieren falls noetig
if [ ! -f "${DIR}/moodle-docker/bin/moodle-docker-compose" ]; then
    echo "==> Initialisiere Git Submodule (moodle-docker)..."
    git submodule update --init --recursive
fi

# 3. Moodle Quellcode pruefen
# Auf diesen Commit gepinnt, da er exakt zum Stand von moodle-data/seed.sql.gz
# passt (Moodle main, weekly release 5.3dev, Build 2026090300).
MOODLE_COMMIT="8eae8fc94d0e3932cbc64f1e81414903a1e2e83b"
MOODLE_SRC="${DIR}/moodle-docker/moodle-src"
if [ ! -d "$MOODLE_SRC" ] || [ -z "$(ls -A "$MOODLE_SRC" 2>/dev/null)" ]; then
    echo "==> Moodle Quellcode fehlt. Klone Moodle (gepinnt auf ${MOODLE_COMMIT}, passend zu seed.sql.gz)..."
    git init -q "$MOODLE_SRC"
    git -C "$MOODLE_SRC" remote add origin https://github.com/moodle/moodle.git
    git -C "$MOODLE_SRC" fetch --depth 1 origin "$MOODLE_COMMIT"
    git -C "$MOODLE_SRC" checkout -q FETCH_HEAD
fi

# 4. config.php sicherstellen
if [ ! -f "${MOODLE_SRC}/config.php" ]; then
    echo "==> Erstelle config.php aus Template..."
    cp "${DIR}/moodle-docker/config.docker-template.php" "${MOODLE_SRC}/config.php"
fi

# 5. Umgebungsvariablen setzen & Docker starten
export MOODLE_DOCKER_WWWROOT="$MOODLE_SRC"
export MOODLE_DOCKER_DB=pgsql
export MOODLE_DOCKER_WEB_PORT="${MOODLE_DOCKER_WEB_PORT:-8000}"

echo "==> Starte Moodle Docker Container..."
cd "${DIR}/moodle-docker"
bin/moodle-docker-compose up -d
bin/moodle-docker-wait-for-db
cd "$DIR"

# Container-Namensschema: podman-compose (Compose v1) nutzt Unterstriche,
# Docker Compose v2 nutzt Bindestriche.
if [ "$CONTAINER_ENGINE" = "podman" ]; then
    DB_CONTAINER="moodle-docker_db_1"
    WEBSERVER_CONTAINER="moodle-docker_webserver_1"
else
    DB_CONTAINER="moodle-docker-db-1"
    WEBSERVER_CONTAINER="moodle-docker-webserver-1"
fi

# 6. Datenbank-Pruefung & Seed
DB_INITIALIZED=$($CONTAINER_ENGINE exec "$DB_CONTAINER" psql -U moodle -d moodle -t -c "SELECT to_regclass('public.m_course');" 2>/dev/null | tr -d '[:space:]')

if [ -z "$DB_INITIALIZED" ] || [ "$DB_INITIALIZED" = "NULL" ]; then
    echo "==> Frische Umgebung erkannt: Spiele vorkonfiguriertes Moodle (seed.sql.gz) ein..."
    if [ -f "${DIR}/moodle-data/seed.sql.gz" ]; then
        gunzip -c "${DIR}/moodle-data/seed.sql.gz" | $CONTAINER_ENGINE exec -i "$DB_CONTAINER" psql -U moodle -d moodle >/dev/null
        $CONTAINER_ENGINE exec "$WEBSERVER_CONTAINER" php admin/cli/purge_caches.php >/dev/null
        echo "==> Vorkonfigurierter Zustand erfolgreich wiederhergestellt!"
    else
        echo "Warnung: moodle-data/seed.sql.gz nicht gefunden!"
    fi
else
    echo "==> Moodle-Datenbank ist bereits initialisiert."
fi

# 7. LTI-URL aktualisieren (falls uebergeben)
if [ -n "$LTI_URL" ]; then
    "${DIR}/set-lti-url.sh" "$LTI_URL"
fi

echo ""
echo "============================================================"
echo " Moodle ist erfolgreich gestartet!"
echo "============================================================"
echo " Moodle URL:      http://localhost:${MOODLE_DOCKER_WEB_PORT}"
echo " Login:           admin"
echo " Passwort:        test"
echo " Testkurs:        http://localhost:${MOODLE_DOCKER_WEB_PORT}/course/view.php?id=2"
echo ""
echo " LTI Mock Server:"
echo " 1. Starten:      cd lti-mock-server && uv run uvicorn ltimockserver.main:app --reload --port 8080"
echo " 2. Ngrok Tunnel: ngrok http 8080"
echo " 3. URL setzen:   ./set-lti-url.sh <deine-ngrok-url>"
echo "============================================================"
