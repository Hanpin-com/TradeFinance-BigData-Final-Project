FROM bigdata-hadoop-base:local
ARG SPARK_VERSION=3.5.0
ENV SPARK_HOME=/opt/spark \
    SPARK_CONF_DIR=/opt/spark/conf \
    PATH=/opt/spark/bin:/opt/spark/sbin:$PATH
COPY downloads/spark-${SPARK_VERSION}-bin-hadoop3.tgz /tmp/spark.tgz
RUN tar -xzf /tmp/spark.tgz -C /opt \
    && mv /opt/spark-${SPARK_VERSION}-bin-hadoop3 /opt/spark \
    && rm /tmp/spark.tgz \
    && chmod -R 755 /opt/spark
COPY config/spark/ /opt/spark/conf/
COPY scripts/wait-for.sh /opt/bigdata/bin/wait-for.sh
COPY scripts/start-spark.sh /opt/bigdata/bin/start-spark.sh
RUN chmod +x /opt/bigdata/bin/*.sh
CMD ["/opt/bigdata/bin/start-spark.sh"]
