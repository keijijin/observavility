# Multi-stage build for Camel Observability Demo

# Stage 1: Build
FROM maven:3.9.5-eclipse-temurin-17 AS build
WORKDIR /app

# Copy pom.xml and download dependencies (for better layer caching)
COPY pom.xml .
RUN mvn dependency:go-offline -B

# Copy source code and build
COPY src ./src
RUN mvn clean package -DskipTests

# Stage 2: Runtime (ARM64 compatible)
FROM eclipse-temurin:17-jre
WORKDIR /app

# Copy JAR from build stage
COPY --from=build /app/target/camel-observability-demo-1.0.0.jar app.jar

# Create non-root user for security (Debian/Ubuntu syntax)
RUN groupadd --system appgroup && \
    useradd --system --gid appgroup --create-home --home-dir /app appuser && \
    chown -R appuser:appgroup /app
USER appuser

# Expose port
EXPOSE 8080

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=60s --retries=3 \
  CMD wget --no-verbose --tries=1 --spider http://localhost:8080/actuator/health || exit 1

# JVM optimization for containers
ENV JAVA_OPTS="-Djava.security.egd=file:/dev/./urandom \
               -XX:+UseContainerSupport \
               -XX:MaxRAMPercentage=75.0"

# Run application
ENTRYPOINT ["sh", "-c", "java ${JAVA_OPTS} -jar app.jar"]

