#!/usr/bin/env bash
set -e

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$DIR"

# Container-Runtime erkennen (Docker bevorzugt, Podman als Fallback)
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

export MOODLE_DOCKER_WWWROOT="${DIR}/moodle-docker/moodle-src"
export MOODLE_DOCKER_DB=pgsql
export MOODLE_DOCKER_WEB_PORT="${MOODLE_DOCKER_WEB_PORT:-8000}"

echo "==> Moodle-Container werden gestoppt..."
cd "${DIR}/moodle-docker"
bin/moodle-docker-compose stop

echo "==> Moodle gestoppt."
