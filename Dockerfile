# dockerfile modified from https://hub.docker.com/r/axiom/ncwms/dockerfile
FROM maven:3.6.3-jdk-8 as builder

WORKDIR /src/edal

ARG EDAL_CACHE_BUST=1

# ARG EDAL_SOURCE_ORG=axiom-data-science
ARG EDAL_SOURCE_ORG=jkalkhof
#ARG EDAL_SOURCE_ORG=Reading-eScience-Centre

#ARG EDAL_SOURCE_BRANCH=develop
#ARG EDAL_SOURCE_BRANCH=master
ARG EDAL_SOURCE_BRANCH=edal-1.4.1-ads

# we want ADS ncwms version of edal
# edal-java-edal-1.4.1-ads
# https://github.com/jkalkhof/edal-java.git

# Compile edal to use required features in dev branch
RUN echo "Using EDAL https://github.com/${EDAL_SOURCE_ORG}/edal-java.git@${EDAL_SOURCE_BRANCH}" && \
    git clone --depth 1 https://github.com/${EDAL_SOURCE_ORG}/edal-java.git -b ${EDAL_SOURCE_BRANCH} . \
    && mvn clean install

WORKDIR /src/ncwms

# Cache some dependencies
COPY pom.xml .
RUN mvn clean test dependency:go-offline

# Compile and install ncWMS
COPY . .
RUN mvn clean install

# FROM unidata/tomcat-docker:8.5
FROM tomcat:9-jdk8-openjdk
MAINTAINER Kyle Wilcox <kyle@axiomdatascience.com>

COPY --from=builder /src/ncwms/target/ncWMS2.war ./ncWMS2.war

ARG WEB_CONTEXT=ROOT
RUN unzip ./ncWMS2.war -d $CATALINA_HOME/webapps/${WEB_CONTEXT}/ && \
    rm ./ncWMS2.war

COPY ./config /ncWMS/config
COPY ./samples /ncWMS/samples
COPY entrypoint.sh /ncWMS/entrypoint.sh

RUN sed -i -e 's/<Context>/<Context privileged="true">/' conf/context.xml

# Set login-config to BASIC since it is handled through Tomcat
# cp /ncWMS/config/ehcache.xml $CATALINA_HOME/conf/ehcache.xml && \
# cp /ncWMS/config/ecache.xml $CATALINA_HOME/conf/ecache.xml && \
RUN sed -i -e 's/DIGEST/BASIC/' $CATALINA_HOME/webapps/${WEB_CONTEXT}/WEB-INF/web.xml && \
    cp /ncWMS/config/setenv.sh $CATALINA_HOME/bin/setenv.sh && \
    cp /ncWMS/config/tomcat-users.xml $CATALINA_HOME/conf/tomcat-users.xml && \
    mkdir -p $CATALINA_HOME/conf/Catalina/localhost/ && \
    cp /ncWMS/config/context.xml $CATALINA_HOME/conf/Catalina/localhost/${WEB_CONTEXT}.xml && \
    mkdir -p $CATALINA_HOME/.ncWMS2 && \
    cp /ncWMS/config/config.xml $CATALINA_HOME/.ncWMS2/config.xml

# ENTRYPOINT ["/ncWMS/entrypoint.sh"]

EXPOSE 8080 8443 9090
CMD ["catalina.sh", "run"]
