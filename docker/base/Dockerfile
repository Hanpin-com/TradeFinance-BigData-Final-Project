FROM eclipse-temurin:17-jdk-jammy
ARG HADOOP_VERSION=3.5.0
ENV JAVA_HOME=/opt/java/openjdk \
    HADOOP_HOME=/opt/hadoop \
    HADOOP_CONF_DIR=/opt/hadoop/etc/hadoop \
    HADOOP_COMMON_HOME=/opt/hadoop \
    HADOOP_HDFS_HOME=/opt/hadoop \
    HADOOP_MAPRED_HOME=/opt/hadoop \
    HADOOP_YARN_HOME=/opt/hadoop \
    PATH=/opt/hadoop/bin:/opt/hadoop/sbin:$PATH
RUN apt-get update && apt-get install -y --no-install-recommends \
    bash curl ca-certificates procps netcat-openbsd python3 tini findutils coreutils \
    && rm -rf /var/lib/apt/lists/* \
    && mkdir -p /opt /opt/bigdata/bin /workspace /hadoop/dfs/name /hadoop/dfs/data /hadoop/yarn/local /hadoop/yarn/log /tmp/hadoop-root
COPY downloads/hadoop-${HADOOP_VERSION}.tar.gz /tmp/hadoop.tgz
RUN tar -xzf /tmp/hadoop.tgz -C /opt \
    && mv /opt/hadoop-${HADOOP_VERSION} /opt/hadoop \
    && rm /tmp/hadoop.tgz \
    && chmod -R 755 /opt/hadoop
COPY config/hadoop/ /opt/hadoop/etc/hadoop/
WORKDIR /workspace
ENTRYPOINT ["/usr/bin/tini","--"]
CMD ["bash"]
