## syntax=docker/dockerfile:1.4
#
#FROM --platform=$BUILDPLATFORM maven:3.8.5-eclipse-temurin-17 AS builder
FROM maven:3.8.5-eclipse-temurin-17 AS builder
#VOLUME /root/.m2
#ENV TESTCONTAINERS_HOST_OVERRIDE=host.docker.internal
WORKDIR /workdir/server
COPY pom.xml /workdir/server/pom.xml
RUN mvn dependency:go-offline

COPY src /workdir/server/src
#CMD ["mvn", "install"]
RUN mvn install

FROM builder AS dev-envs
RUN <<EOF
apt-get update
apt-get install -y --no-install-recommends git
EOF

RUN <<EOF
useradd -s /bin/bash -m vscode
groupadd docker
usermod -aG docker vscode
EOF
# install Docker tools (cli, buildx, compose)
COPY --from=gloursdocker/docker / /
CMD ["mvn", "spring-boot:run"]

FROM builder as prepare-production
RUN mkdir -p target/dependency
WORKDIR /workdir/server/target/dependency
RUN jar -xf ../*.jar

FROM eclipse-temurin:17-jre-focal

EXPOSE 9090
VOLUME /tmp
ARG DEPENDENCY=/workdir/server/target/dependency
COPY --from=prepare-production ${DEPENDENCY}/BOOT-INF/lib /app/lib
COPY --from=prepare-production ${DEPENDENCY}/META-INF /app/META-INF
COPY --from=prepare-production ${DEPENDENCY}/BOOT-INF/classes /app
ENTRYPOINT ["java","-cp","app:app/lib/*","com.mtech.productservice.ProductServiceApplication"]

#FROM maven:3
#WORKDIR /workdir/server
#COPY pom.xml /workdir/server/pom.xml
#RUN mvn dependency:go-offline
#COPY src /workdir/server/src
#CMD ["mvn", "clean", "validate", "compile", "test", "package"]
#RUN mvn test
#
##
## Package stage
##
#FROM openjdk:11-jre-slim
#COPY --from=build /home/app/target/demo-0.0.1-SNAPSHOT.jar /usr/local/lib/demo.jar
#EXPOSE 8080
#ENTRYPOINT ["java","-jar","/usr/local/lib/demo.jar"]