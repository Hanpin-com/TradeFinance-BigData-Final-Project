FROM mcr.microsoft.com/mssql/server:2022-latest

USER root

RUN mkdir -p /docker-entrypoint-initdb.d

COPY entrypoint.sh /entrypoint.sh

RUN sed -i 's/\r$//' /entrypoint.sh && \
    chmod +x /entrypoint.sh

RUN chmod +x /entrypoint.sh

USER mssql

ENTRYPOINT ["/entrypoint.sh"]