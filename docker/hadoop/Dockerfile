FROM bigdata-hadoop-base:local
COPY scripts/wait-for.sh /opt/bigdata/bin/wait-for.sh
COPY scripts/start-hadoop.sh /opt/bigdata/bin/start-hadoop.sh
RUN chmod +x /opt/bigdata/bin/*.sh
CMD ["/opt/bigdata/bin/start-hadoop.sh"]
