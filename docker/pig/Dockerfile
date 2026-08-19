FROM bigdata-hadoop-base:local
ARG PIG_VERSION=0.17.0
ENV PIG_HOME=/opt/pig \
    PIG_CLASSPATH=/opt/hadoop/etc/hadoop \
    PATH=/opt/pig/bin:$PATH
COPY downloads/pig-${PIG_VERSION}.tar.gz /tmp/pig.tgz
RUN tar -xzf /tmp/pig.tgz -C /opt \
    && mv /opt/pig-${PIG_VERSION} /opt/pig \
    && rm /tmp/pig.tgz \
    && chmod -R 755 /opt/pig
COPY config/pig.properties /opt/pig/conf/pig.properties
WORKDIR /workspace
CMD ["tail","-f","/dev/null"]
