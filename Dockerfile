FROM openjdk:11-oracle
WORKDIR .
COPY target/*.jar spring.jar
ENTRYPOINT ["java", "-jar", "/spring.jar"]