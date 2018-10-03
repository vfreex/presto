FROM fedora:28 as build

RUN yum -y update && yum clean all

RUN yum -y install java-1.8.0-openjdk maven \
    && yum clean all \
    && rm -rf /var/cache/yum

RUN mkdir /build
COPY . /build

# Install presto-server
RUN cd /build/presto-server && mvn -B -e -T 1C -DskipTests -DfailIfNoTests=false -Dtest=false package
# Install presto-cli
RUN cd /build/presto-cli && mvn -B -e -T 1C -DskipTests -DfailIfNoTests=false -Dtest=false package
# Install prometheus-jmx agent
RUN mvn dependency:get -Dartifact=io.prometheus.jmx:jmx_prometheus_javaagent:0.3.1:jar -Ddest=/build/jmx_prometheus_javaagent.jar

FROM centos:7

RUN yum -y install java-1.8.0-openjdk \
    && yum clean all \
    && rm -rf /var/cache/yum

RUN mkdir -p /opt/presto

ENV PRESTO_VERSION 0.212
ENV PRESTO_HOME /opt/presto/presto-server
ENV PRESTO_CLI /opt/presto/presto-cli
ENV PROMETHEUS_JMX_EXPORTER /opt/jmx_exporter/jmx_exporter.jar
ENV TERM linux
ENV HOME /opt/presto

RUN mkdir -p $PRESTO_HOME

RUN useradd presto -m -u 1003 -d /opt/presto

COPY --from=build /build/presto-server/target/presto-server-$PRESTO_VERSION $PRESTO_HOME
COPY --from=build /build/presto-cli/target/presto-cli-$PRESTO_VERSION.jar $PRESTO_CLI
COPY --from=build /build/jmx_prometheus_javaagent.jar $PROMETHEUS_JMX_EXPORTER

RUN ln $PRESTO_CLI /usr/local/bin/presto-cli \
        && chmod 755 /usr/local/bin/presto-cli

EXPOSE 8080
WORKDIR $PRESTO_HOME
CMD ["bin/launcher", "run"]
