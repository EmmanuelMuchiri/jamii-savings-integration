# ---------- build: Maven + JDK 21 ----------
FROM maven:3.9-eclipse-temurin-21 AS build
WORKDIR /src
COPY pom.xml .
RUN mvn -B -q dependency:go-offline
COPY src ./src
RUN mvn -B clean package

# ---------- runtime: JRE 21, non-root ----------
FROM eclipse-temurin:21-jre
RUN groupadd --system jamii && useradd --system --gid jamii --uid 10001 jamii
WORKDIR /app
COPY --from=build /src/target/jamii-mock-backends.jar /app/app.jar
USER jamii
EXPOSE 8080
HEALTHCHECK --interval=15s --timeout=3s --start-period=40s --retries=5 \
  CMD bash -c 'exec 3<>/dev/tcp/127.0.0.1/8080 && printf "GET /actuator/health HTTP/1.0\r\n\r\n" >&3 && grep -q "UP" <&3' || exit 1
ENTRYPOINT ["java", "-XX:MaxRAMPercentage=75", "-jar", "/app/app.jar"]
