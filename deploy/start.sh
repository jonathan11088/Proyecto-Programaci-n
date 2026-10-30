#!/bin/sh
set -e

: "${ADMIN_PASSWORD:?Defina la variable ADMIN_PASSWORD}"

# Apache escucha en el puerto que asigna Render.
echo "Listen ${PORT}" > /etc/apache2/ports.conf

# Arranca MariaDB. Su disco es efimero en Render: cada arranque inicia con la BD en blanco.
[ -d /var/lib/mysql/mysql ] || mariadb-install-db --user=mysql --datadir=/var/lib/mysql --skip-test-db >/dev/null
mysqld_safe --user=mysql &
until mariadb-admin ping --silent 2>/dev/null; do sleep 1; done

if ! mariadb -e "USE banco_mariano" 2>/dev/null; then
  mariadb < /var/www/backend/database/01_schema.sql
  mariadb < /var/www/backend/database/02_procedures.sql
fi

# La aplicacion solo puede ejecutar procedimientos almacenados, sin acceso directo a las tablas.
DB_USER=banco_app
DB_PASS="$(head -c 32 /dev/urandom | od -An -tx1 | tr -d ' \n')"
export DB_USER DB_PASS
mariadb -e "CREATE OR REPLACE USER '${DB_USER}'@'localhost' IDENTIFIED BY '${DB_PASS}';
            GRANT EXECUTE ON banco_mariano.* TO '${DB_USER}'@'localhost';"

php /var/www/backend/scripts/crear_admin.php
unset ADMIN_PASSWORD

# Regenera cada minuto el reporte de GoAccess con el log de Apache.
touch /var/log/apache2/banco_access.log
(
  while true; do
    if [ -s /var/log/apache2/banco_access.log ]; then
      goaccess /var/log/apache2/banco_access.log --log-format=COMBINED \
        -o /var/lib/banco/reporte.tmp.html --no-global-config >/dev/null 2>&1 \
        && mv /var/lib/banco/reporte.tmp.html /var/lib/banco/reporte.html
    fi
    sleep 60
  done
) &

exec apache2-foreground
