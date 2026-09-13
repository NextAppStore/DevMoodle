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

# 1. Docker-Check
if ! docker info >/dev/null 2>&1; then
    echo "Fehler: Docker Daemon läuft nicht oder Docker ist nicht installiert."
    exit 1
fi

# 2. Submodule initialisieren falls noetig
if [ ! -f "${DIR}/moodle-docker/bin/moodle-docker-compose" ]; then
    echo "==> Initialisiere Git Submodule (moodle-docker)..."
    git submodule update --init --recursive
fi

# 3. Moodle Quellcode pruefen
MOODLE_SRC="${DIR}/moodle-docker/moodle-src"
if [ ! -d "$MOODLE_SRC" ] || [ -z "$(ls -A "$MOODLE_SRC" 2>/dev/null)" ]; then
    echo "==> Moodle Quellcode fehlt. Klone Moodle 4.4 (MOODLE_404_STABLE)..."
    git clone --depth 1 -b MOODLE_404_STABLE https://github.com/moodle/moodle.git "$MOODLE_SRC"
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

# 6. Datenbank-Pruefung & Seed
DB_INITIALIZED=$(docker exec moodle-docker-db-1 psql -U moodle -d moodle -t -c "SELECT to_regclass('public.m_course');" 2>/dev/null | tr -d '[:space:]')

if [ -z "$DB_INITIALIZED" ] || [ "$DB_INITIALIZED" = "NULL" ]; then
    echo "==> Frische Umgebung erkannt: Spiele vorkonfiguriertes Moodle (seed.sql.gz) ein..."
    if [ -f "${DIR}/moodle-data/seed.sql.gz" ]; then
        gunzip -c "${DIR}/moodle-data/seed.sql.gz" | docker exec -i moodle-docker-db-1 psql -U moodle -d moodle >/dev/null
        docker exec moodle-docker-webserver-1 php admin/cli/purge_caches.php >/dev/null
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
