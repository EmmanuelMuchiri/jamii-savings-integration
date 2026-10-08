# WSO2 Micro Integrator, self-managed (Option C), built from the downloaded distribution.
# Build contexts (see docker-compose.yml): dist = ./dist (zip + checksums), mi_src = ./mi (artifacts).
# MI 4.3 supports JDK 11-17 only (its start script refuses JDK 21)
ARG JAVA_BASE_IMAGE=eclipse-temurin:17-jre

# ---------- unpack: verify and extract the MI zip, add the H2 JDBC driver ----------
FROM ${JAVA_BASE_IMAGE} AS unpack
ARG MI_VERSION
ARG H2_VERSION=2.2.224
RUN apt-get update && apt-get install -y --no-install-recommends unzip && rm -rf /var/lib/apt/lists/*
WORKDIR /tmp/dist
COPY --from=dist wso2mi-${MI_VERSION}.zip checksums.txt ./
RUN grep " wso2mi-${MI_VERSION}.zip$" checksums.txt | sha256sum -c - \
 && unzip -q wso2mi-${MI_VERSION}.zip -d /opt \
 && mv /opt/wso2mi-${MI_VERSION} /opt/mi \
 && chmod +x /opt/mi/bin/*.sh
# Must match the H2 server version in docker/h2 (TCP protocol compatibility)
ADD https://repo1.maven.org/maven2/com/h2database/h2/${H2_VERSION}/h2-${H2_VERSION}.jar /opt/mi/lib/h2-${H2_VERSION}.jar

# ---------- runtime ----------
FROM ${JAVA_BASE_IMAGE}
ENV MI_HOME=/home/wso2/mi
RUN groupadd --system wso2 && useradd --system --gid wso2 --uid 10802 --create-home --home-dir /home/wso2 wso2
COPY --from=unpack --chown=wso2:wso2 /opt/mi ${MI_HOME}

# Integration artifacts, hot-deployed from the integration project (a CAR replaces this in the pipeline)
ARG SYNAPSE=${MI_HOME}/repository/deployment/server/synapse-configs/default
COPY --from=mi_src --chown=wso2:wso2 src/main/wso2mi/artifacts/apis/        ${SYNAPSE}/api/
COPY --from=mi_src --chown=wso2:wso2 src/main/wso2mi/artifacts/sequences/   ${SYNAPSE}/sequences/
COPY --from=mi_src --chown=wso2:wso2 src/main/wso2mi/artifacts/templates/   ${SYNAPSE}/templates/
COPY --from=mi_src --chown=wso2:wso2 src/main/wso2mi/artifacts/endpoints/   ${SYNAPSE}/endpoints/
COPY --from=mi_src --chown=wso2:wso2 src/main/wso2mi/artifacts/data-services/ ${MI_HOME}/repository/deployment/server/dataservices/

COPY --chown=wso2:wso2 entrypoint.sh /home/wso2/entrypoint.sh
RUN chmod +x /home/wso2/entrypoint.sh
USER wso2
WORKDIR /home/wso2
# 8290 HTTP runtime (internal only), 8253 HTTPS runtime, 9164 management API
EXPOSE 8290 8253 9164
HEALTHCHECK --interval=15s --timeout=3s --start-period=60s --retries=10 \
  CMD bash -c 'exec 3<>/dev/tcp/127.0.0.1/8290' || exit 1
ENTRYPOINT ["/home/wso2/entrypoint.sh"]
