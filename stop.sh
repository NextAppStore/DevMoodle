#!/usr/bin/env bash
set -e

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$DIR"

export MOODLE_DOCKER_WWWROOT="${DIR}/moodle-docker/moodle-src"
export MOODLE_DOCKER_DB=pgsql
export MOODLE_DOCKER_WEB_PORT="${MOODLE_DOCKER_WEB_PORT:-8000}"

echo "==> Moodle-Container werden gestoppt..."
cd "${DIR}/moodle-docker"
bin/moodle-docker-compose stop

echo "==> Moodle gestoppt."
