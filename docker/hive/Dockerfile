FROM bigdata-hadoop-base:local

ARG HIVE_VERSION=4.1.0
ARG HBASE_VERSION=2.5.11

ENV HIVE_HOME=/opt/hive \
    HBASE_HOME=/opt/hbase \
    HIVE_CONF_DIR=/opt/hive/conf \
    HBASE_CONF_DIR=/opt/hbase/conf \
    HIVE_AUX_JARS_PATH=/opt/hbase/lib:/opt/hbase/lib/client-facing-thirdparty \
    HADOOP_CLASSPATH=/opt/hbase/lib/*:/opt/hbase/lib/client-facing-thirdparty/* \
    PATH=/opt/hive/bin:/opt/hbase/bin:$PATH

# ------------------------------------------------------------------
# Install Hive
# ------------------------------------------------------------------

COPY downloads/apache-hive-${HIVE_VERSION}-bin.tar.gz /tmp/hive.tgz

RUN tar -xzf /tmp/hive.tgz -C /opt \
 && mv /opt/apache-hive-${HIVE_VERSION}-bin /opt/hive \
 && rm -f /tmp/hive.tgz \
 && rm -f /opt/hive/lib/guava-*.jar \
 && cp /opt/hadoop/share/hadoop/common/lib/guava-*.jar /opt/hive/lib/ \
 && chmod -R 755 /opt/hive

# ------------------------------------------------------------------
# Install HBase client
# ------------------------------------------------------------------

COPY downloads/hbase-${HBASE_VERSION}-bin.tar.gz /tmp/hbase.tgz

RUN tar -xzf /tmp/hbase.tgz -C /opt \
 && mv /opt/hbase-${HBASE_VERSION} /opt/hbase \
 && rm -f /tmp/hbase.tgz

# ------------------------------------------------------------------
# Hive JDBC
# ------------------------------------------------------------------

COPY downloads/postgresql-42.7.4.jar \
     /opt/hive/lib/postgresql-42.7.4.jar

# ------------------------------------------------------------------
# Configuration
# ------------------------------------------------------------------

COPY config/hive/ /opt/hive/conf/

COPY config/hbase/hbase-site.xml \
     /opt/hive/conf/hbase-site.xml

COPY config/hbase/hbase-site.xml \
     /opt/hbase/conf/hbase-site.xml

# ------------------------------------------------------------------
# Verify HBase integration
# ------------------------------------------------------------------

RUN test -f /opt/hive/lib/hive-hbase-handler-4.1.0.jar

RUN test -f /opt/hbase/lib/hbase-client-2.5.11.jar

# ------------------------------------------------------------------
# Startup
# ------------------------------------------------------------------

COPY scripts/wait-for.sh /opt/bigdata/bin/wait-for.sh
COPY scripts/start-hive.sh /opt/bigdata/bin/start-hive.sh

RUN chmod +x /opt/bigdata/bin/*.sh

CMD ["/opt/bigdata/bin/start-hive.sh"]