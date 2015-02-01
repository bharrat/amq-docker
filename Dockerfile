FROM ubuntu:14.04
#Based on https://github.com/noelo/amq-docker
MAINTAINER "Bharat Patel" <bharrat@gmail.com>

RUN rm /etc/apt/sources.list
RUN echo deb http://archive.ubuntu.com/ubuntu trusty main universe multiverse > /etc/apt/sources.list

RUN echo oracle-java8-installer shared/accepted-oracle-license-v1-1 select true | sudo /usr/bin/debconf-set-selections
RUN echo "deb http://ppa.launchpad.net/webupd8team/java/ubuntu trusty main" | tee /etc/apt/sources.list.d/webupd8team-java.list
RUN echo "deb-src http://ppa.launchpad.net/webupd8team/java/ubuntu trusty main" | tee -a /etc/apt/sources.list.d/webupd8team-java.list
RUN apt-key adv --keyserver keyserver.ubuntu.com --recv-keys EEA14886
RUN apt-get update
RUN apt-get install oracle-java8-installer curl -y
RUN update-java-alternatives -s java-8-oracle
RUN apt-get install oracle-java8-set-default
RUN apt-get -y install openssh-server
RUN apt-get -y install sudo

# enabling sudo over ssh
RUN sed -i 's/.*requiretty$/#Defaults requiretty/' /etc/sudoers

ENV JAVA_HOME /usr/lib/jvm/java-8-oracle/jre

# add a user for the application, with sudo permissions
RUN useradd -m activemq ; echo activemq: | chpasswd ; usermod -a -G sudo activemq

# command line goodies
RUN echo "export JAVA_HOME=/usr/lib/jvm/java-8-oracle/jre" >> /etc/profile
RUN echo "alias ll='ls -l --color=auto'" >> /etc/profile
RUN echo "alias grep='grep --color=auto'" >> /etc/profile


WORKDIR /home/activemq

ENV ACTIVEMQ_VERSION 5.10.1
RUN curl http://apache.cs.utah.edu/activemq/5.10.1/apache-activemq-${ACTIVEMQ_VERSION}-bin.tar.gz | tar -xz
RUN mv apache-activemq-${ACTIVEMQ_VERSION} apache-activemq

RUN mv apache-activemq/conf/activemq.xml apache-activemq/conf/activemq.xml.orig
RUN awk '/.*stomp.*/{print "            <transportConnector name=\"stompssl\" uri=\"stomp+nio+ssl://0.0.0.0:61612?transport.enabledCipherSuites=SSL_RSA_WITH_RC4_128_SHA,SSL_DH_anon_WITH_3DES_EDE_CBC_SHA\" />"}1' apache-activemq/conf/activemq.xml.orig >> apache-activemq/conf/activemq.xml

RUN chown -R activemq:activemq apache-activemq

WORKDIR /home/activemq/apache-activemq/conf

WORKDIR /home/activemq/apache-activemq/bin
RUN chmod u+x ./activemq

WORKDIR /home/activemq/apache-activemq/

# ensure we have a log file to tail
RUN mkdir -p data/
RUN echo >> data/activemq.log
EXPOSE 22 1099 61616 8161 5672 61613 1883 61614

WORKDIR /home/activemq/apache-activemq/conf
RUN rm -f startup.sh
ADD activemq-cluster-config.sh /home/activemq/apache-activemq/startup.sh
#RUN curl   --output startup.sh  https://raw.githubusercontent.com/noelo/amq-docker/master/activemq-cluster-config.sh

RUN chmod u+x /home/activemq/apache-activemq/startup.sh
RUN chown -R activemq /home/activemq

RUN mkdir -p /var/run/sshd /var/log/supervisor
RUN apt-get install -y supervisor
RUN service supervisor stop
RUN mv /etc/supervisor/supervisord.conf /etc/supervisor/supervisord.conf.bak
COPY supervisord.conf /etc/supervisor/supervisord.conf

#CMD  /home/activemq/apache-activemq/startup.sh
CMD ["/usr/bin/supervisord"]