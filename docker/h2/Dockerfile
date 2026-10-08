# H2 database in server (TCP) mode for the Balance API.
ARG JAVA_BASE_IMAGE=eclipse-temurin:17-jre
FROM ${JAVA_BASE_IMAGE}
ARG H2_VERSION=2.2.224
RUN groupadd --system h2 && useradd --system --gid h2 --uid 10801 --home /opt/h2 h2 \
 && mkdir -p /opt/h2/scripts /data && chown -R h2:h2 /opt/h2 /data
ADD --chown=h2:h2 https://repo1.maven.org/maven2/com/h2database/h2/${H2_VERSION}/h2-${H2_VERSION}.jar /opt/h2/h2.jar
COPY --from=db --chown=h2:h2 schema.sql seed.sql /opt/h2/scripts/
COPY --chown=h2:h2 entrypoint.sh /opt/h2/entrypoint.sh
RUN chmod +x /opt/h2/entrypoint.sh
USER h2
VOLUME /data
EXPOSE 9092 8082
HEALTHCHECK --interval=10s --timeout=3s --start-period=15s --retries=5 \
  CMD bash -c 'exec 3<>/dev/tcp/127.0.0.1/9092' || exit 1
ENTRYPOINT ["/opt/h2/entrypoint.sh"]
