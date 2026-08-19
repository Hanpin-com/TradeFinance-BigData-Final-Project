FROM bigdata-hadoop-base:local
COPY scripts/wait-for.sh /opt/bigdata/bin/wait-for.sh
COPY scripts/validate-stack.sh /opt/bigdata/bin/validate-stack.sh
RUN chmod +x /opt/bigdata/bin/*.sh
CMD ["/opt/bigdata/bin/validate-stack.sh"]
