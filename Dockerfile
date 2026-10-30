FROM php:8.2-apache-bookworm

RUN apt-get update \
 && apt-get install -y --no-install-recommends mariadb-server goaccess \
 && rm -rf /var/lib/apt/lists/* \
 && docker-php-ext-install pdo_mysql \
 && a2enmod headers remoteip \
 && a2dissite 000-default \
 && mv "$PHP_INI_DIR/php.ini-production" "$PHP_INI_DIR/php.ini"

COPY Backend/ /var/www/backend/
COPY Frontend/ /var/www/frontend/
COPY deploy/apache.conf /etc/apache2/sites-available/banco.conf
COPY deploy/mariadb.cnf /etc/mysql/mariadb.conf.d/99-banco.cnf
COPY deploy/start.sh /usr/local/bin/start-banco

RUN sed -i 's/\r$//' /usr/local/bin/start-banco \
 && chmod +x /usr/local/bin/start-banco \
 && a2ensite banco \
 && mkdir -p /var/lib/banco /run/mysqld \
 && chown mysql:mysql /run/mysqld

ENV PORT=10000
EXPOSE 10000
CMD ["start-banco"]
