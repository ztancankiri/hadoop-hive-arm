FROM ubuntu:latest

ENV JAVA_HOME=/opt/java/jdk
ENV HADOOP_HOME=/opt/hadoop
ENV HIVE_HOME=/opt/hive
ENV LD_LIBRARY_PATH=/usr/local/lib
ENV PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/opt/java/jdk/bin:/opt/maven/bin:/opt/hadoop/bin:/opt/hive/bin

# Dependencies
RUN apt-get update -y \
    && apt-get install -y wget curl git build-essential make cmake gcc g++ patch pkg-config libfuse-dev libtool autoconf automake unzip ssh \
    libssl-dev zlib1g-dev libbz2-dev libsnappy-dev libcurl4-openssl-dev libsasl2-dev liblz4-dev libzstd-dev python2 python3 python3-pip python3-venv

# Directories, Config
RUN mkdir /opt/java && mkdir /downloads && cd /downloads \
    && echo 'export JAVA_HOME=/opt/java/jdk' >> /root/.bashrc \
    && echo 'export HADOOP_HOME=/opt/hadoop' >> /root/.bashrc \
    && echo 'export HIVE_HOME=/opt/hive' >> /root/.bashrc \
    && echo 'export PATH=$PATH:$JAVA_HOME/bin:/opt/maven/bin:$HADOOP_HOME/bin:$HIVE_HOME/bin' >> /root/.bashrc \
    && echo 'export LD_LIBRARY_PATH=/usr/local/lib' >> /root/.bashrc \
    && ssh-keygen -t rsa -P '' -f ~/.ssh/id_rsa && cat ~/.ssh/id_rsa.pub >> ~/.ssh/authorized_keys && chmod 0600 ~/.ssh/authorized_keys

# Download source files
RUN cd /downloads \
    && wget https://github.com/protocolbuffers/protobuf/releases/download/v2.5.0/protobuf-2.5.0.tar.gz -O protobuf-2.5.0.tar.gz \
    && tar xzvf protobuf-2.5.0.tar.gz \
    && cd /downloads/protobuf-2.5.0 \
    && wget https://gist.githubusercontent.com/liusheng/64aee1b27de037f8b9ccf1873b82c413/raw/118c2fce733a9a62a03281753572a45b6efb8639/protobuf-2.5.0-arm64.patch -O protobuf-2.5.0-arm64.patch

RUN cd /downloads && git clone https://github.com/apache/hadoop.git && cd hadoop && git checkout rel/release-3.3.5

RUN cd /downloads && git clone https://git-wip-us.apache.org/repos/asf/hive.git && cd hive && git checkout rel/release-3.1.3

# Java & Maven
RUN wget https://github.com/adoptium/temurin8-binaries/releases/download/jdk8u372-b07/OpenJDK8U-jdk_aarch64_linux_hotspot_8u372b07.tar.gz -O OpenJDK.tar.gz \
    && tar xzvf OpenJDK.tar.gz -C /opt/java/ && mv /opt/java/jdk* /opt/java/jdk \
    && wget https://dlcdn.apache.org/maven/maven-3/3.9.1/binaries/apache-maven-3.9.1-bin.tar.gz -O maven.tar.gz \
    && tar xzvf maven.tar.gz -C /opt/ && mv /opt/apache-maven-* /opt/maven

# Protobuf
RUN cd /downloads/protobuf-2.5.0 \
    && sed -i 's/curl http:\/\/googletest.googlecode.com\/files\/gtest-1.5.0.tar.bz2 | tar jx/curl https:\/\/codeload.github.com\/google\/googletest\/tar.gz\/release-1.5.0 | tar zx/g' autogen.sh \
    && sed -i 's/mv gtest-1.5.0 gtest/mv googletest-release-1.5.0 gtest/g' autogen.sh \
    && patch -p1 < protobuf-2.5.0-arm64.patch \
    && ./autogen.sh && ./configure && make && make install

# Hadoop Build & Install
RUN cd /downloads/hadoop \
    && mvn clean package -Pdist,native -DskipTests -DskipITs -Dmaven.javadoc.skip=true -Dtar -Drequire.snappy -Drequire.openssl -Drequire.fuse \
    && tar xzvf hadoop-dist/target/hadoop-3.3.5.tar.gz -C /opt/ && mv /opt/hadoop* /opt/hadoop && cd /opt/hadoop

COPY core-site.xml /opt/hadoop/etc/hadoop/
COPY hdfs-site.xml /opt/hadoop/etc/hadoop/
COPY mapred-site.xml /opt/hadoop/etc/hadoop/
COPY yarn-site.xml /opt/hadoop/etc/hadoop/
COPY hadoop-env.sh /opt/hadoop/etc/hadoop/

# Hive Build & Install
COPY settings.xml /root/.m2/
RUN cd /downloads/hive \
    && mvn install:install-file -DgroupId=com.google.protobuf -DartifactId=protoc -Dversion=2.5.0 -Dclassifier=linux-aarch_64 -Dpackaging=exe -Dfile=/usr/local/bin/protoc \
    && mvn clean package -Pdist -DskipTests -DskipITs -Dmaven.javadoc.skip=true \
    && mv ./packaging/target/apache-hive-*/apache-hive-* /opt/hive

# Clean & Last Config
COPY start.sh /opt/hadoop/sbin/
RUN rm -rf /var/lib/apt/lists/* && rm -rf /downloads/* && chmod +x /opt/hadoop/sbin/start.sh

CMD ["/opt/hadoop/sbin/start.sh"]