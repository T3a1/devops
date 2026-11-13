FROM jenkins/jenkins:lts

ENV JAVA_OPTS="-Djenkins.install.runSetupWizard=false"

COPY plugins.txt /usr/share/jenkins/ref/plugins.txt
RUN jenkins-plugin-cli --plugin-file /usr/share/jenkins/ref/plugins.txt
USER root
RUN apt-get update
RUN apt-get install -y make gcc

COPY my_marvin.yml /var/jenkins_home/casc_configs/my_marvin.yml

COPY job_dsl.groovy /var/jenkins_home/casc_configs/job_dsl.groovy

ENV CASC_JENKINS_CONFIG=/var/jenkins_home/casc_configs

ENV USER_CHOCOLATEEN_PASSWORD=epi1
ENV USER_VAUGIE_G_PASSWORD=epi2
ENV USER_I_DONT_KNOW_PASSWORD=epi3
ENV USER_NASSO_PASSWORD=epi4
