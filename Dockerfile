FROM jenkins/jenkins:latest

USER root

#Update the username and password
ENV JENKINS_ADMIN_ID admin
ENV JENKINS_ADMIN_PASSWORD admin
ARG user=jenkins
ARG group=jenkins
ARG uid=1000
ARG gid=1000
ARG TINI_VERSION=v0.17.0

# allows to skip Jenkins setup wizard
ENV JAVA_OPTS="-Xmx8192m -Djenkins.install.runSetupWizard=false"
ENV CASC_JENKINS_CONFIG /var/jenkins_home/casc.yaml

RUN apt-get update && \
    apt-get -y install apt-transport-https \
      dos2unix \
      ca-certificates \
      curl \
      python3-pip \
      gnupg2 \
      software-properties-common && \
    curl -fsSL https://download.docker.com/linux/$(. /etc/os-release; echo "$ID")/gpg > /tmp/dkey; apt-key add /tmp/dkey && \
    add-apt-repository \
      "deb [arch=amd64] https://download.docker.com/linux/$(. /etc/os-release; echo "$ID") \
      $(lsb_release -cs) \
      stable" && \
    apt-get update && \
    apt-get -y install docker-ce

# install jenkins plugins
RUN mkdir -p /usr/share/jenkins/plugins/

COPY plugins.txt /usr/share/jenkins/ref/plugins.txt
COPY casc.yaml /var/jenkins_home/casc.yaml
COPY requirements.txt /.
COPY executors.groovy /usr/share/jenkins/ref/init.groovy.d/executors.groovy

RUN pip3 install -r requirements.txt

# Use tini as subreaper in Docker container to adopt zombie processes
ADD https://github.com/krallin/tini/releases/download/${TINI_VERSION}/tini /bin/tini
RUN chmod +x /bin/tini

RUN chown -R ${user} "$JENKINS_HOME" /usr/share/jenkins/ref

RUN /usr/local/bin/install-plugins.sh < /usr/share/jenkins/ref/plugins.txt

#id_rsa.pub file will be saved at /root/.ssh/
RUN ssh-keygen -f /root/.ssh/id_rsa -t rsa -N ''

# Switch to the jenkins user
USER ${user}

# Tini as the entry point to manage zombie processes
ENTRYPOINT ["/bin/tini", "--", "/usr/local/bin/jenkins.sh"]