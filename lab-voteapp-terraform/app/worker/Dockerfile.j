FROM eclipse-temurin:8-jdk
#FROM java:openjdk-8-jdk-alpine

RUN apt-get update && apt-get install -y ca-certificates wget && \
    MAVEN_VERSION=3.8.1 \
 && cd /usr/share \
 && wget http://archive.apache.org/dist/maven/maven-3/$MAVEN_VERSION/binaries/apache-maven-$MAVEN_VERSION-bin.tar.gz -O - | tar xzf - \
 && mv /usr/share/apache-maven-$MAVEN_VERSION /usr/share/maven \
 && ln -s /usr/share/maven/bin/mvn /usr/bin/mvn \
 && rm -rf /var/lib/apt/lists/*

WORKDIR /code

ADD pom.xml /code/pom.xml

# Adding source, compile and package into a fat jar
ADD src/main /code/src/main
RUN mvn clean package

CMD ["java", "-jar", "target/worker-jar-with-dependencies.jar"]
