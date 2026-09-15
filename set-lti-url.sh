#!/usr/bin/env bash
set -e

if [ -z "$1" ]; then
    echo "Verwendung: ./set-lti-url.sh <BASE_URL>"
    echo "Beispiel:   ./set-lti-url.sh https://visible-iron-erratic.ngrok-free.dev"
    exit 1
fi

TARGET_URL="${1%/}" # Trailing Slash entfernen
DOMAIN=$(echo "$TARGET_URL" | awk -F[/:] '{print $4}')

# Container-Runtime erkennen (Docker bevorzugt, Podman als Fallback)
if command -v docker >/dev/null 2>&1 && docker info >/dev/null 2>&1; then
    CONTAINER_ENGINE="docker"
elif command -v podman >/dev/null 2>&1 && podman info >/dev/null 2>&1; then
    CONTAINER_ENGINE="podman"
else
    echo "Fehler: Weder Docker noch Podman gefunden bzw. deren Daemon läuft nicht."
    exit 1
fi

# Container-Namensschema: podman-compose (Compose v1) nutzt Unterstriche,
# Docker Compose v2 nutzt Bindestriche.
if [ "$CONTAINER_ENGINE" = "podman" ]; then
    DB_CONTAINER="moodle-docker_db_1"
    WEBSERVER_CONTAINER="moodle-docker_webserver_1"
else
    DB_CONTAINER="moodle-docker-db-1"
    WEBSERVER_CONTAINER="moodle-docker-webserver-1"
fi

echo "==> Aktualisiere LTI-Tool URL auf: $TARGET_URL (Domain: $DOMAIN)..."

$CONTAINER_ENGINE exec -i "$DB_CONTAINER" psql -U moodle -d moodle >/dev/null <<EOF
UPDATE m_lti_types 
SET baseurl = '${TARGET_URL}/api/lti/launch', tooldomain = '${DOMAIN}' 
WHERE id = 1;

UPDATE m_lti_types_config 
SET value = '${TARGET_URL}/api/lti/launch' 
WHERE typeid = 1 AND name = 'publickeyset';

UPDATE m_lti_types_config 
SET value = '${TARGET_URL}/api/lti/login' 
WHERE typeid = 1 AND name = 'initiatelogin';

UPDATE m_lti_types_config 
SET value = '${TARGET_URL}/api/lti/launch' 
WHERE typeid = 1 AND name = 'redirectionuris';
EOF

$CONTAINER_ENGINE exec "$WEBSERVER_CONTAINER" php admin/cli/purge_caches.php >/dev/null

echo "==> LTI-Tool erfolgreich aktualisiert!"
