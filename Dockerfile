FROM ubuntu:22.04

ENV BUILD_USER_ID=199
ENV BUILD_USER=akamas
ARG DOCKER_GROUP_ID=200

RUN apt-get update &&\
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    apt-transport-https \
    build-essential \
    ca-certificates \
    curl \
    gnupg2 \
    gnupg \
    lsb-release \
    software-properties-common \
    python3 \
    python3-pip \
    git \
    jq \
    libxml2-utils \
    openssh-client \
    openssh-server \
    sshpass \
    locales \
    vim \
    less \
    file \
    zip \
    unzip \
    sudo \
    iputils-ping \
    net-tools \
    dnsutils \
    telnet \
    netcat \
    postgresql-client \
    wget

RUN ln -s /usr/bin/python3 /usr/bin/python

#Setup docker repo
RUN  mkdir -p /etc/apt/keyrings &&\
     curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg && \
     echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

#Install docker
RUN apt-get update &&\
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends\
    docker-ce \
    docker-ce-cli \
    containerd.io \
    docker-compose-plugin && \
    apt-get autoremove -y && apt-get clean -y

RUN groupdel docker && groupadd -g ${DOCKER_GROUP_ID} docker
RUN useradd --user-group --create-home --shell /bin/bash -u ${BUILD_USER_ID} -G sudo,docker ${BUILD_USER} && newgrp docker

RUN locale-gen en_US.UTF-8
ENV LANG en_US.UTF-8
ENV LANGUAGE en_US:en
ENV LC_ALL en_US.UTF-8

RUN wget -q https://github.com/AdoptOpenJDK/openjdk11-binaries/releases/download/jdk-11.0.10%2B9/OpenJDK11U-jdk_x64_linux_hotspot_11.0.10_9.tar.gz -O /opt/OpenJDK11U-jdk_x64_linux_hotspot_11.0.10_9.tar.gz && \
    cd /opt && tar xzf OpenJDK11U-jdk_x64_linux_hotspot_11.0.10_9.tar.gz && rm /opt/OpenJDK11U-jdk_x64_linux_hotspot_11.0.10_9.tar.gz && mv /opt/jdk-11.0.10+9/ /opt/jdk-11.0.10_9/ && ln -s /opt/jdk-11.0.10_9/ /opt/java

RUN pip3 install --progress-bar off --upgrade pip && \
    pip3 install --progress-bar off setuptools wheel kubernetes

RUN wget -q https://github.com/mikefarah/yq/releases/download/v4.40.5/yq_linux_amd64 && \
    mv yq_linux_amd64 /usr/bin/yq &&\
    chmod +x /usr/bin/yq

RUN curl -sS https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

RUN curl -sS -LO "https://dl.k8s.io/release/v1.23.16/bin/linux/amd64/kubectl" && install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

RUN wget -q https://github.com/derailed/k9s/releases/download/v0.29.1/k9s_Linux_amd64.tar.gz && tar xfz k9s_Linux_amd64.tar.gz -C /usr/local/bin/ && \
    chmod 755 /usr/local/bin/k9s && rm -f k9s_Linux_amd64.tar.gz

RUN curl -sS "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip" && \
    unzip awscliv2.zip && sudo ./aws/install && rm -rf awscliv2.zip aws/

RUN echo "${BUILD_USER} ALL=(ALL:ALL) NOPASSWD: ALL" >> /etc/sudoers

RUN echo "export PATH=/opt/java/bin:$PATH\n" \
         "export KUBECONFIG=/work/.kube/config\n" \
         "alias k=kubectl" >> /home/${BUILD_USER}/.bashrc

RUN curl -sS -o akamas_cli https://s3.us-east-2.amazonaws.com/akamas/cli/2.9.0/linux_64/akamas && \
    mv akamas_cli /usr/local/bin/akamas && \
    chmod 755 /usr/local/bin/akamas

RUN curl -sS -O https://s3.us-east-2.amazonaws.com/akamas/cli/2.9.0/linux_64/akamas_autocomplete.sh && \
    mkdir -p /home/${BUILD_USER}/.akamas && \
    mv akamas_autocomplete.sh /home/${BUILD_USER}/.akamas && \
    chmod 755 /home/${BUILD_USER}/.akamas/akamas_autocomplete.sh && \
    chown ${BUILD_USER}:${BUILD_USER} /home/${BUILD_USER}/.akamas/akamas_autocomplete.sh && \
    echo ". /home/${BUILD_USER}/.akamas/akamas_autocomplete.sh\ncd /work" >> /home/${BUILD_USER}/.bashrc

ADD --chown=${BUILD_USER}:${BUILD_USER} files/akamasconf /home/${BUILD_USER}/.akamas/

RUN mkdir -p /var/run/sshd

RUN mkdir -p /home/${BUILD_USER}/.ssh /home/${BUILD_USER}/.sshd /work/.kube
# On boot we'll need to update the password with a randomly-generated one. Since
# in kube envs we may not be able to `sudo`, and passwd doesn't work well without
# a password, we need to setup a default one
RUN echo 'akamas' > /home/${BUILD_USER}/.factory_password && \
    echo "${BUILD_USER}:$(cat /home/${BUILD_USER}/.factory_password)" | chpasswd
RUN chown -R ${BUILD_USER}:${BUILD_USER} /home/${BUILD_USER} /work/
ADD files/entrypoint.sh /
RUN chmod +x /entrypoint.sh

USER ${BUILD_USER}

ENTRYPOINT bash /entrypoint.sh
SHELL ["/bin/bash", "-l", "-c"]