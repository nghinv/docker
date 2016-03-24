# to run, need to mount data volume for jenkins and mysql.
# docker run -v /java/docker_shared_data/SEC_TEST_AUTO_1/jenkins_home:/var/jenkins_home -v /java/docker_shared_data/SEC_TEST_AUTO_1/mysql:/var/lib/mysql -d nghinv/SEC_TEST_AUTO_1

FROM java:8-jdk

RUN apt-get update && apt-get install -y vim xvfb fluxbox x11vnc wget git curl zip apt-utils imagemagick graphviz lbzip2 libgtk-3-0 

#RUN debconf-set-selections <<< 'mysql-server mysql-server/root_password password exo'
#RUN debconf-set-selections <<< 'mysql-server mysql-server/root_password_again password exo'
#RUN apt-get install -y mysql-server

RUN echo "mysql-server mysql-server/root_password password root" | debconf-set-selections && echo "mysql-server mysql-server/root_password_again password root" | debconf-set-selections && apt-get install -y mysql-server
EXPOSE 3306



ENV JENKINS_HOME /var/jenkins_home
ENV JENKINS_SLAVE_AGENT_PORT 50000

# Jenkins is run with user `jenkins`, uid = 1000
# If you bind mount a volume from the host or a data container, 
# ensure you use the same uid
RUN useradd -d "$JENKINS_HOME" -u 1000 -m -s /bin/bash jenkins

# Jenkins home directory is a volume, so configuration and build history 
# can be persisted and survive image upgrades
VOLUME /var/jenkins_home

# `/usr/share/jenkins/ref/` contains all reference configuration we want 
# to set on a fresh new installation. Use it to bundle additional plugins 
# or config file with your custom jenkins Docker image.
RUN mkdir -p /usr/share/jenkins/ref/init.groovy.d

ENV TINI_SHA 066ad710107dc7ee05d3aa6e4974f01dc98f3888

# Use tini as subreaper in Docker container to adopt zombie processes 
RUN curl -fL https://github.com/krallin/tini/releases/download/v0.5.0/tini-static -o /bin/tini && chmod +x /bin/tini \
  && echo "$TINI_SHA /bin/tini" | sha1sum -c -

COPY init.groovy /usr/share/jenkins/ref/init.groovy.d/tcp-slave-agent-port.groovy

ENV JENKINS_VERSION 1.642.2
ENV JENKINS_SHA e72e06e64d23eefb13090459f517b0697aad7be0


# could use ADD but this one does not check Last-Modified header 
# see https://github.com/docker/docker/issues/8331
RUN curl -fL http://repo.jenkins-ci.org/public/org/jenkins-ci/main/jenkins-war/${JENKINS_VERSION}/jenkins-war-${JENKINS_VERSION}.war -o /usr/share/jenkins/jenkins.war \
  && echo "$JENKINS_SHA /usr/share/jenkins/jenkins.war" | sha1sum -c -

ENV JENKINS_UC https://updates.jenkins-ci.org
RUN chown -R jenkins "$JENKINS_HOME" /usr/share/jenkins/ref

# for main web interface:
EXPOSE 80

# for eXo PLF:
EXPOSE 8080


# will be used by attached slave agents:
EXPOSE 50000

# setup SSH server
RUN apt-get update && apt-get install -y openssh-server && rm -rf /var/lib/apt/lists/*
RUN sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
RUN mkdir /var/run/sshd

EXPOSE 22

ENV COPY_REFERENCE_FILE_LOG $JENKINS_HOME/copy_reference_file.log


# EXO working dir
ENV EXO_WORKING_DIR /java/exo-working
VOLUME ${EXO_WORKING_DIR}/

#USER jenkins

COPY jenkins.sh /usr/local/bin/jenkins.sh
ENTRYPOINT ["/bin/tini", "--", "/usr/local/bin/jenkins.sh"]

# from a derived Dockerfile, can use `RUN plugins.sh active.txt` to setup /usr/share/jenkins/ref/plugins from a support bundle
COPY plugins.sh /usr/local/bin/plugins.sh
