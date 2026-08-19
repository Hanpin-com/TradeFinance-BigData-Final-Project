FROM bigdata-hadoop-base:local
ARG HBASE_VERSION=2.5.11
ENV HBASE_HOME=/opt/hbase \
    HBASE_CONF_DIR=/opt/hbase/conf \
    PATH=/opt/hbase/bin:$PATH
COPY downloads/hbase-${HBASE_VERSION}-bin.tar.gz /tmp/hbase.tgz
RUN tar -xzf /tmp/hbase.tgz -C /opt \
    && mv /opt/hbase-${HBASE_VERSION} /opt/hbase \
    && rm /tmp/hbase.tgz \
    && chmod -R 755 /opt/hbase
COPY config/hbase/ /opt/hbase/conf/
COPY scripts/wait-for.sh /opt/bigdata/bin/wait-for.sh
COPY scripts/start-hbase.sh /opt/bigdata/bin/start-hbase.sh
RUN chmod +x /opt/bigdata/bin/*.sh
CMD ["/opt/bigdata/bin/start-hbase.sh"]
