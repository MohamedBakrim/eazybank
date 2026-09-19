FROM eclipse-temurin:21-jre
WORKDIR /app
COPY target/configserver-0.0.1-SNAPSHOT.jar app.jar
EXPOSE 8071
ENTRYPOINT ["java","-jar","app.jar"]