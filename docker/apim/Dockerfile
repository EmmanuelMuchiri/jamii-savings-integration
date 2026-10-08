# WSO2 API Manager (all-in-one), self-managed (Option C), built from the downloaded distribution
# and branded for Jamii Savings. Build context: docker/apim; named context dist = ./dist.
# JDK 17: supported by both APIM 4.4 and MI 4.3, so the WSO2 images share one runtime.
ARG JAVA_BASE_IMAGE=eclipse-temurin:17-jre

# ---------- unpack: verify, extract, configure, brand ----------
FROM ${JAVA_BASE_IMAGE} AS unpack
ARG APIM_VERSION
RUN apt-get update && apt-get install -y --no-install-recommends unzip zip python3 && rm -rf /var/lib/apt/lists/*
WORKDIR /tmp/dist
COPY --from=dist wso2am-${APIM_VERSION}.zip checksums.txt ./
COPY verify-unpack.sh /tmp/verify-unpack.sh
RUN bash /tmp/verify-unpack.sh wso2am-${APIM_VERSION}.zip /opt/apim
COPY configure.sh brand.py /tmp/
COPY branding /tmp/branding
RUN bash /tmp/configure.sh /opt/apim && python3 /tmp/brand.py /opt/apim /tmp/branding

# ---------- runtime ----------
FROM ${JAVA_BASE_IMAGE}
ENV APIM_HOME=/home/wso2/apim
RUN groupadd --system wso2 && useradd --system --gid wso2 --uid 10803 --create-home --home-dir /home/wso2 wso2
COPY --from=unpack --chown=wso2:wso2 /opt/apim ${APIM_HOME}
COPY --chown=wso2:wso2 entrypoint.sh /home/wso2/entrypoint.sh
RUN chmod +x /home/wso2/entrypoint.sh
USER wso2
WORKDIR /home/wso2
# 9443 Publisher / Developer Portal / Admin / Carbon, 8243 gateway HTTPS, 8280 gateway HTTP
EXPOSE 9443 8243 8280
HEALTHCHECK --interval=20s --timeout=5s --start-period=180s --retries=10 \
  CMD bash -c 'exec 3<>/dev/tcp/127.0.0.1/9443' || exit 1
ENTRYPOINT ["/home/wso2/entrypoint.sh"]
