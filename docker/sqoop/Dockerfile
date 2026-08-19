FROM bigdata-hadoop-base:local
ARG SQOOP_VERSION=1.4.7
ENV SQOOP_HOME=/opt/sqoop \
    PATH=/opt/sqoop/bin:$PATH
COPY downloads/sqoop-${SQOOP_VERSION}.bin__hadoop-2.6.0.tar.gz /tmp/sqoop.tgz
RUN tar -xzf /tmp/sqoop.tgz -C /opt \
    && mv /opt/sqoop-${SQOOP_VERSION}.bin__hadoop-2.6.0 /opt/sqoop \
    && rm /tmp/sqoop.tgz \
    && chmod -R 755 /opt/sqoop
COPY downloads/postgresql-42.7.4.jar /opt/sqoop/lib/postgresql-42.7.4.jar
COPY config/sqoop-env.sh /opt/sqoop/conf/sqoop-env.sh
WORKDIR /workspace
CMD ["tail","-f","/dev/null"]
