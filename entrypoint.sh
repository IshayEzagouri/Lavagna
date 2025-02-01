#!/bin/bash

set -e

# Wait for MySQL to be ready on the RDS endpoint
while ! nc -z "${DB_HOST}" 3306; do
  sleep 10
  echo "Waiting for MySQL to respond on port 3306..."
done

echo "MySQL is ready. Starting Lavagna with:"
echo "  Dialect: ${DB_DIALECT}"
echo "  URL: ${DB_URL}"
echo "  Username: ${DB_USERNAME}"

# To disable migration, you could add:
#   -Ddatasource.disable.migration=true \
# in the java command below.

exec java \
  -Ddatasource.dialect="${DB_DIALECT:-MYSQL}" \
  -Ddatasource.url="${DB_URL}" \
  -Ddatasource.username="${DB_USERNAME}" \
  -Ddatasource.password="${DB_PASSWORD}" \
  -Dspring.profile.active="${SPRING_PROFILE:-dev}" \
  -jar /app/lavagna-jetty-console.war
