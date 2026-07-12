# syntax=docker/dockerfile:1

# ---- Build stage ----------------------------------------------------------
# Matches the wrapper's pinned Gradle 8.8 + JDK 21 so the image builds with the
# same toolchain we use locally.
FROM gradle:8.8-jdk21 AS build
WORKDIR /build

# Copy only the build configuration first and resolve dependencies. This layer
# is cached and only re-runs when the build files change — not on every source
# edit — so incremental image builds don't re-download the world.
COPY build.gradle.kts settings.gradle.kts gradle.properties ./
RUN gradle dependencies --no-daemon --quiet || true

# Now the source, then the actual build.
COPY src ./src
# Skip tests in the image: they use Testcontainers, which needs a Docker daemon
# that isn't available inside the build stage. Tests run via `./gradlew build`
# locally / in CI before the image is ever built.
RUN gradle bootJar --no-daemon -x test

# ---- Runtime stage --------------------------------------------------------
FROM eclipse-temurin:21-jre AS runtime
WORKDIR /app

# curl is only needed for the container HEALTHCHECK below.
RUN apt-get update \
    && apt-get install -y --no-install-recommends curl \
    && rm -rf /var/lib/apt/lists/*

# Never run the app as root inside the container.
RUN groupadd --system spring && useradd --system --gid spring spring
USER spring:spring

# Only the executable boot jar is produced (we ran `bootJar`, not `build`), so
# the glob matches exactly one file.
COPY --from=build /build/build/libs/*.jar app.jar

# Deployable image defaults to the production profile; override with
# SPRING_PROFILES_ACTIVE at run time if needed.
ENV SPRING_PROFILES_ACTIVE=prod
EXPOSE 8080

# Actuator's health endpoint is public (see SecurityConfig + JwtAuthenticationFilter).
# It reports UP once the DB connection is live, so this doubles as a readiness signal.
HEALTHCHECK --interval=15s --timeout=3s --start-period=40s --retries=5 \
    CMD curl -fsS http://localhost:8080/actuator/health || exit 1

ENTRYPOINT ["java", "-jar", "app.jar"]
