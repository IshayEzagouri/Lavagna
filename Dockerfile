# Stage 1: Build stage
FROM maven:3.8.2-eclipse-temurin-8 AS build
WORKDIR /app
COPY . .
RUN mvn clean install -DskipTests && ls -l /app/target
RUN ls -l /app/target/lavagna

FROM openjdk:8-jre-alpine
WORKDIR /app
# Copy the WAR file from the build stage
COPY --from=build /app/target/lavagna-jetty-console.war /app/lavagna-jetty-console.war
COPY entrypoint.sh /app/entrypoint.sh
RUN chmod +x /app/entrypoint.sh
# Add netcat for the health check
RUN apk add --no-cache bash netcat-openbsd
EXPOSE 8080
ENTRYPOINT ["/app/entrypoint.sh"]



