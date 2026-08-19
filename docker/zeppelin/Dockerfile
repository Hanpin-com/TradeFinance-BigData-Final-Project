FROM bigdata-hadoop-base:local

ARG ZEPPELIN_VERSION=0.12.0
ARG HIVE_VERSION=4.1.0
ARG PYTHON_BIN=python3

ENV ZEPPELIN_HOME=/opt/zeppelin \
    ZEPPELIN_CONF_DIR=/opt/zeppelin/conf \
    ZEPPELIN_LOG_DIR=/opt/zeppelin/logs \
    ZEPPELIN_NOTEBOOK_DIR=/opt/zeppelin/notebook \
    PYTHON_ENV=/opt/zeppelin/python-env \
    HIVE_JDBC_URL=jdbc:hive2://hive-server:10000/default \
    PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1 \
    PIP_NO_CACHE_DIR=1 \
    MPLBACKEND=Agg

ENV PATH="${PYTHON_ENV}/bin:${ZEPPELIN_HOME}/bin:${PATH}"

USER root

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# Python runtime, native libraries for scientific packages, and diagnostics.
RUN apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
       python3 \
       python3-pip \
       python3-venv \
       python3-dev \
       build-essential \
       gfortran \
       libopenblas-dev \
       liblapack-dev \
       libfreetype6-dev \
       libpng-dev \
       libjpeg-dev \
       curl \
       ca-certificates \
       tini \
       iproute2 \
       net-tools \
    && rm -rf /var/lib/apt/lists/*

# Install Apache Zeppelin with all bundled interpreters.
RUN curl -fSL \
      "https://archive.apache.org/dist/zeppelin/zeppelin-${ZEPPELIN_VERSION}/zeppelin-${ZEPPELIN_VERSION}-bin-all.tgz" \
      -o /tmp/zeppelin.tgz \
    && tar -xzf /tmp/zeppelin.tgz -C /opt \
    && mv "/opt/zeppelin-${ZEPPELIN_VERSION}-bin-all" "${ZEPPELIN_HOME}" \
    && rm -f /tmp/zeppelin.tgz \
    && mkdir -p \
       "${ZEPPELIN_LOG_DIR}" \
       "${ZEPPELIN_NOTEBOOK_DIR}" \
       "${ZEPPELIN_CONF_DIR}" \
       "${ZEPPELIN_HOME}/run"

# Install the Hive JDBC standalone driver directly in the JDBC interpreter
# classpath. This allows Zeppelin to load org.apache.hive.jdbc.HiveDriver
# without manual dependency configuration in the UI.
RUN curl -fSL \
      "https://repo.maven.apache.org/maven2/org/apache/hive/hive-jdbc/${HIVE_VERSION}/hive-jdbc-${HIVE_VERSION}-standalone.jar" \
      -o "${ZEPPELIN_HOME}/interpreter/jdbc/hive-jdbc-${HIVE_VERSION}-standalone.jar" \
    && test -s "${ZEPPELIN_HOME}/interpreter/jdbc/hive-jdbc-${HIVE_VERSION}-standalone.jar"

# Create the exact Python environment used by Zeppelin.
# Zeppelin 0.12.0 requires protobuf 3.20.x for its generated kernel code.
RUN "${PYTHON_BIN}" -m venv "${PYTHON_ENV}" \
    && "${PYTHON_ENV}/bin/python" -m pip install --upgrade pip setuptools wheel \
    && "${PYTHON_ENV}/bin/python" -m pip install \
       jupyter \
       ipython \
       ipykernel \
       grpcio \
       protobuf==3.20.3 \
       py4j \
       numpy \
       pandas \
       scipy \
       scikit-learn \
       statsmodels \
       matplotlib \
       seaborn \
       plotly \
       pandasql \
       sqlalchemy \
       pyarrow \
       openpyxl \
       xlrd \
       joblib \
       imbalanced-learn \
       xgboost \
       requests \
       pyyaml \
       happybase \
       thrift \
       thriftpy2 \
    && ln -sf "${PYTHON_ENV}/bin/python" /usr/local/bin/python \
    && ln -sf "${PYTHON_ENV}/bin/python" /usr/local/bin/python3 \
    && ln -sf "${PYTHON_ENV}/bin/pip" /usr/local/bin/pip \
    && ln -sf "${PYTHON_ENV}/bin/pip" /usr/local/bin/pip3

# Configure Zeppelin server defaults and keep Python as the default group.
RUN cat > "${ZEPPELIN_CONF_DIR}/zeppelin-site.xml" <<EOF_SITE
<?xml version="1.0"?>
<?xml-stylesheet type="text/xsl" href="configuration.xsl"?>
<configuration>
  <property>
    <name>zeppelin.server.addr</name>
    <value>0.0.0.0</value>
  </property>
  <property>
    <name>zeppelin.server.port</name>
    <value>8080</value>
  </property>
  <property>
    <name>zeppelin.notebook.dir</name>
    <value>${ZEPPELIN_NOTEBOOK_DIR}</value>
  </property>
  <property>
    <name>zeppelin.interpreter.group.default</name>
    <value>python</value>
  </property>
  <property>
    <name>zeppelin.interpreter.connect.timeout</name>
    <value>600s</value>
  </property>
</configuration>
EOF_SITE

# Configure Zeppelin, Hadoop, Spark, and Python process environments.
RUN cat > "${ZEPPELIN_CONF_DIR}/zeppelin-env.sh" <<EOF_ENV
#!/usr/bin/env bash
export ZEPPELIN_HOME="${ZEPPELIN_HOME}"
export ZEPPELIN_CONF_DIR="${ZEPPELIN_CONF_DIR}"
export ZEPPELIN_LOG_DIR="${ZEPPELIN_LOG_DIR}"
export ZEPPELIN_NOTEBOOK_DIR="${ZEPPELIN_NOTEBOOK_DIR}"
export HADOOP_HOME="${HADOOP_HOME}"
export HADOOP_CONF_DIR="${HADOOP_CONF_DIR}"
export SPARK_HOME="${SPARK_HOME}"
export PATH="${PYTHON_ENV}/bin:${ZEPPELIN_HOME}/bin:\${PATH}"
export PYSPARK_PYTHON="${PYTHON_ENV}/bin/python"
export PYSPARK_DRIVER_PYTHON="${PYTHON_ENV}/bin/python"
EOF_ENV

RUN chmod +x "${ZEPPELIN_CONF_DIR}/zeppelin-env.sh"

# Configure bundled Python interpreter defaults before first startup.
RUN mkdir -p "${ZEPPELIN_CONF_DIR}/interpreter" \
    && cat > "${ZEPPELIN_CONF_DIR}/interpreter/python.properties" <<EOF_PY
zeppelin.python=${PYTHON_ENV}/bin/python
zeppelin.python.useIPython=true
zeppelin.python.maxResult=10000
EOF_PY

# Configure the existing JDBC interpreter after Zeppelin creates its default
# settings. The resulting datasource is invoked as %jdbc(hive).
RUN cat > "${ZEPPELIN_HOME}/bin/configure-hive-jdbc.py" <<'EOF_PYTHON'
#!/usr/bin/env python3
import json
import os
import sys
import time
import urllib.error
import urllib.request

BASE_URL = "http://127.0.0.1:8080"
HIVE_URL = os.environ.get(
    "HIVE_JDBC_URL",
    "jdbc:hive2://hive-server:10000/default",
)


def request(method: str, path: str, payload=None):
    data = None
    headers = {"Content-Type": "application/json"}
    if payload is not None:
        data = json.dumps(payload).encode("utf-8")

    req = urllib.request.Request(
        BASE_URL + path,
        data=data,
        headers=headers,
        method=method,
    )
    with urllib.request.urlopen(req, timeout=15) as response:
        return json.loads(response.read().decode("utf-8"))


# Wait until Zeppelin REST API is available.
for attempt in range(90):
    try:
        response = request("GET", "/api/version")
        if response.get("status") == "OK":
            break
    except Exception:
        pass
    time.sleep(2)
else:
    print("Zeppelin REST API did not become ready.", file=sys.stderr)
    sys.exit(1)

settings_response = request("GET", "/api/interpreter/setting")
settings = settings_response.get("body") or []

jdbc_setting = next(
    (
        item
        for item in settings
        if item.get("group") == "jdbc" and item.get("name") == "jdbc"
    ),
    None,
)

hive_properties = {
    "hive.driver": {
        "name": "hive.driver",
        "value": "org.apache.hive.jdbc.HiveDriver",
        "type": "string",
    },
    "hive.url": {
        "name": "hive.url",
        "value": HIVE_URL,
        "type": "string",
    },
    "hive.user": {
        "name": "hive.user",
        "value": "",
        "type": "string",
    },
    "hive.password": {
        "name": "hive.password",
        "value": "",
        "type": "password",
    },
    "hive.validationQuery": {
        "name": "hive.validationQuery",
        "value": "SELECT 1",
        "type": "string",
    },
    "hive.testOnBorrow": {
        "name": "hive.testOnBorrow",
        "value": "true",
        "type": "checkbox",
    },
}

if jdbc_setting is None:
    payload = {
        "name": "jdbc",
        "group": "jdbc",
        "properties": hive_properties,
        "interpreterGroup": [
            {
                "class": "org.apache.zeppelin.jdbc.JDBCInterpreter",
                "name": "jdbc",
            }
        ],
        "dependencies": [],
        "option": {
            "remote": True,
            "isExistingProcess": False,
            "setPermission": False,
            "owners": [],
            "isUserImpersonate": False,
        },
    }
    result = request("POST", "/api/interpreter/setting", payload)
else:
    payload = dict(jdbc_setting)
    payload.setdefault("properties", {}).update(hive_properties)
    setting_id = payload.pop("id")
    result = request(
        "PUT",
        f"/api/interpreter/setting/{setting_id}",
        payload,
    )

if result.get("status") != "OK":
    print("Failed to configure Hive JDBC interpreter:", result, file=sys.stderr)
    sys.exit(1)

print(f"Hive JDBC datasource configured: {HIVE_URL}")
print("Use it in Zeppelin with: %jdbc(hive)")
EOF_PYTHON

RUN chmod +x "${ZEPPELIN_HOME}/bin/configure-hive-jdbc.py"

# Start Zeppelin, configure %jdbc(hive) through its supported REST API, and
# keep the Zeppelin process in the foreground for correct container signals.
RUN cat > "${ZEPPELIN_HOME}/bin/start-zeppelin.sh" <<'EOF_START'
#!/usr/bin/env bash
set -euo pipefail

/opt/zeppelin/bin/zeppelin.sh &
ZEPPELIN_PID=$!

terminate() {
  kill -TERM "${ZEPPELIN_PID}" 2>/dev/null || true
  wait "${ZEPPELIN_PID}" 2>/dev/null || true
}
trap terminate TERM INT

if ! /opt/zeppelin/python-env/bin/python \
    /opt/zeppelin/bin/configure-hive-jdbc.py; then
  echo "ERROR: Hive JDBC interpreter configuration failed." >&2
  terminate
  exit 1
fi

wait "${ZEPPELIN_PID}"
EOF_START

RUN chmod +x "${ZEPPELIN_HOME}/bin/start-zeppelin.sh"

# Fail the image build if Python or the Hive JDBC driver is incomplete.
RUN "${PYTHON_ENV}/bin/python" -c "import sys, happybase, thrift, thriftpy2, numpy, pandas, scipy, sklearn, statsmodels, matplotlib, seaborn, plotly, pyarrow, imblearn, xgboost, grpc, google.protobuf, py4j; assert google.protobuf.__version__ == '3.20.3'; print(sys.executable); print('protobuf=' + google.protobuf.__version__); print('Zeppelin Python environment verified')" \
    && "${PYTHON_ENV}/bin/python" --version \
    && test -s "${ZEPPELIN_HOME}/interpreter/jdbc/hive-jdbc-${HIVE_VERSION}-standalone.jar"

# Normalize generated shell and Python scripts to Linux LF line endings.
# This prevents both bash\r and python3\r interpreter errors.
RUN find /opt/zeppelin -type f \
       \( -name "*.sh" -o -name "*.py" \) \
       -exec sed -i 's/\r$//' {} + \
    && chmod +x /opt/zeppelin/conf/zeppelin-env.sh \
    && chmod +x /opt/zeppelin/bin/configure-hive-jdbc.py \
    && chmod +x /opt/zeppelin/bin/start-zeppelin.sh \
    && test "$(head -n 1 /opt/zeppelin/bin/start-zeppelin.sh)" = "#!/usr/bin/env bash" \
    && test "$(head -n 1 /opt/zeppelin/bin/configure-hive-jdbc.py)" = "#!/usr/bin/env python3"

WORKDIR ${ZEPPELIN_HOME}

EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=10s --start-period=120s --retries=5 \
  CMD curl -fsS http://localhost:8080/api/version || exit 1

ENTRYPOINT ["/usr/bin/tini", "--"]
CMD ["/opt/zeppelin/bin/start-zeppelin.sh"]
