FROM openjdk:11 as maven3-openjdk
RUN mkdir spring
COPY . /spring
WORKDIR /spring
RUN chmod +x mvnw
RUN ./mvnw sonar:sonar package -U -Dsonar.projectKey=com.dell:spring-application -Dsonar.host.url=http://sonarqubeops.eastus.cloudapp.azure.com:9000  -Dsonar.login=aaaef2c558a11f7b7359da0ae533d5260b8f9ab0

FROM maven3-openjdk
COPY --from=maven3-openjdk /spring/target/*.jar /spring/spring.jar
EXPOSE 8080
ENTRYPOINT ["java", "-jar", "/spring/spring.jar"]
