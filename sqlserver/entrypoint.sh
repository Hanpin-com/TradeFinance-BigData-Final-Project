#!/bin/bash

set -euo pipefail

SQLCMD="/opt/mssql-tools18/bin/sqlcmd"
SQLSERVER="/opt/mssql/bin/sqlservr"
SA_PASSWORD="${MSSQL_SA_PASSWORD}"

echo "========================================="
echo "Starting Microsoft SQL Server..."
echo "========================================="

${SQLSERVER} &
SQL_PID=$!

cleanup() {
    echo "Stopping SQL Server..."
    kill -TERM "${SQL_PID}" 2>/dev/null || true
    wait "${SQL_PID}" 2>/dev/null || true
}

trap cleanup SIGINT SIGTERM

echo "Waiting for SQL Server to become available..."

until ${SQLCMD} \
    -S localhost \
    -U sa \
    -P "${SA_PASSWORD}" \
    -C \
    -Q "SELECT 1" >/dev/null 2>&1
do
    sleep 2
done

echo "SQL Server is ready."

DB_EXISTS=$(
${SQLCMD} \
    -S localhost \
    -U sa \
    -P "${SA_PASSWORD}" \
    -C \
    -h -1 \
    -W \
    -Q "SET NOCOUNT ON; SELECT COUNT(*) FROM sys.databases WHERE name='LoblawRetailOperations';" \
    | tr -d '[:space:]'
)

if [ "${DB_EXISTS}" = "0" ]; then

    echo
    echo "========================================="
    echo "Initializing LoblawRetailOperations"
    echo "========================================="

    SQL_FILES=(
        "/sql/01_create_database.sql"
        "/sql/02_create_schema.sql"
        "/sql/03_seed_lookup_tables.sql"
        "/sql/04_import_products.sql"
        "/sql/05_import_stores.sql"
        "/sql/06_import_promotions.sql"
        "/sql/07_import_retail_events.sql"
        "/sql/08_validation.sql"
        "/sql/09_sqoop_source_views.sql"
    )

    for FILE in "${SQL_FILES[@]}"
    do

        if [ ! -f "${FILE}" ]; then
            echo "ERROR: ${FILE} not found."
            exit 1
        fi

        echo
        echo "-----------------------------------------"
        echo "Executing $(basename "${FILE}")"
        echo "-----------------------------------------"

        ${SQLCMD} \
            -S localhost \
            -U sa \
            -P "${SA_PASSWORD}" \
            -C \
            -b \
            -i "${FILE}"

    done

    echo
    echo "========================================="
    echo "Database initialization completed."
    echo "========================================="

else

    echo
    echo "LoblawRetailOperations already exists."
    echo "Skipping initialization."

fi

echo
echo "SQL Server is ready for connections."

wait "${SQL_PID}"