#!/usr/bin/env bash
set -e

if [ -z "$1" ]; then
    echo "Verwendung: ./set-lti-url.sh <BASE_URL>"
    echo "Beispiel:   ./set-lti-url.sh https://visible-iron-erratic.ngrok-free.dev"
    exit 1
fi

TARGET_URL="${1%/}" # Trailing Slash entfernen
DOMAIN=$(echo "$TARGET_URL" | awk -F[/:] '{print $4}')

echo "==> Aktualisiere LTI-Tool URL auf: $TARGET_URL (Domain: $DOMAIN)..."

docker exec -i moodle-docker-db-1 psql -U moodle -d moodle >/dev/null <<EOF
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

docker exec moodle-docker-webserver-1 php admin/cli/purge_caches.php >/dev/null

echo "==> LTI-Tool erfolgreich aktualisiert!"
