# WSO2 Micro Integrator Dashboard, built from the downloaded distribution (optional viewing tool).
# MI registers itself here on startup ([dashboard_config] in MI's deployment.toml).
ARG JAVA_BASE_IMAGE=eclipse-temurin:17-jre

FROM ${JAVA_BASE_IMAGE} AS unpack
ARG MI_DASHBOARD_VERSION
RUN apt-get update && apt-get install -y --no-install-recommends unzip && rm -rf /var/lib/apt/lists/*
WORKDIR /tmp/dist
COPY --from=dist wso2mi-dashboard-${MI_DASHBOARD_VERSION}.zip checksums.txt ./
COPY verify-unpack.sh /tmp/verify-unpack.sh
RUN bash /tmp/verify-unpack.sh wso2mi-dashboard-${MI_DASHBOARD_VERSION}.zip /opt/dashboard

FROM ${JAVA_BASE_IMAGE}
ENV DASHBOARD_HOME=/home/wso2/dashboard
RUN groupadd --system wso2 && useradd --system --gid wso2 --uid 10804 --create-home --home-dir /home/wso2 wso2
COPY --from=unpack --chown=wso2:wso2 /opt/dashboard ${DASHBOARD_HOME}
USER wso2
WORKDIR /home/wso2
EXPOSE 9743
HEALTHCHECK --interval=15s --timeout=3s --start-period=60s --retries=10 \
  CMD bash -c 'exec 3<>/dev/tcp/127.0.0.1/9743' || exit 1
ENTRYPOINT ["bash", "-c", "exec ${DASHBOARD_HOME}/bin/dashboard.sh"]
