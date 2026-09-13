#!/usr/bin/env bash
set -e

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$DIR"

mkdir -p moodle-data

echo "==> Exportiere Moodle-Datenbank nach moodle-data/seed.sql.gz..."
docker exec moodle-docker-db-1 pg_dump -U moodle --clean --if-exists moodle | gzip -c > moodle-data/seed.sql.gz

echo "==> Exportiere Kurs nach moodle-data/test_course.mbz..."
docker exec moodle-docker-webserver-1 php admin/cli/backup.php --courseid=2 --destination=/tmp/ >/dev/null
docker exec moodle-docker-webserver-1 sh -c 'mv /tmp/backup-moodle2-course-2-*.mbz /tmp/test_course.mbz'
docker cp moodle-docker-webserver-1:/tmp/test_course.mbz moodle-data/test_course.mbz
docker exec moodle-docker-webserver-1 rm -f /tmp/test_course.mbz

echo "==> Export erfolgreich abgeschlossen!"
ls -lh moodle-data/
