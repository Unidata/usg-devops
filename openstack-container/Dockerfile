FROM rockylinux:9

ARG HELM_VERSION=3.15.0
ARG KUBECTL_VERSION=1.30
ARG GOSU_VERSION=1.19

ENV GOSU_URL="https://github.com/tianon/gosu/releases/download/${GOSU_VERSION}/gosu-amd64" \
    HOME=/home/openstack \
    PATH=/home/openstack/bin:$PATH

RUN mkdir -p /home/openstack/bin /home/openstack/.config/nushell
COPY .bashrc /home/openstack/
COPY requirements.txt /tmp/requirements.txt

RUN printf "[kubernetes]\n\
name=Kubernetes\n\
baseurl=https://pkgs.k8s.io/core:/stable:/v${KUBECTL_VERSION}/rpm/\n\
enabled=1\n\
gpgcheck=1\n\
repo_gpgcheck=0\n\
gpgkey=https://pkgs.k8s.io/core:/stable:/v${KUBECTL_VERSION}/rpm/repodata/repomd.xml.key\n" \
    > /etc/yum.repos.d/kubernetes.repo && \
printf "[gemfury-nushell] \n\
name=Gemfury Nushell Repo \n\
baseurl=https://yum.fury.io/nushell/ \n\
enabled=1 \n\
gpgcheck=0 \n\
gpgkey=https://yum.fury.io/nushell/gpg.key" \
    | tee /etc/yum.repos.d/fury-nushell.repo &&  \
    dnf -y update && dnf install -y epel-release && \
    dnf install -y man-db man-pages vim nano git wget unzip ncurses procps-ng \
    htop python3 telnet openssh openssh-clients openssl findutils diffutils \
    vi less kubectl python3-pip rsync jq nushell && \
    dnf clean all && rm -rf /var/cache/dnf && \
    # gosu install start
    curl -fsSL $GOSU_URL -o /usr/local/bin/gosu && \
    curl -fsSL $GOSU_URL.asc -o /tmp/gosu.asc && \
    export GNUPGHOME="$(mktemp -d)" && \
    # @tianon's, maintainer of gosu, public key, in case you are wondering
    export KEY=B42F6819007F00F88E364FD4036A9C25BF357DD4 && \
    for server in $(shuf -e keyserver.ubuntu.com \
                            hkp://keyserver.ubuntu.com:80 ) ; do \
        gpg --batch --keyserver "$server" --recv-keys $KEY && break || : ; \
    done && \
    gpg --batch --verify /tmp/gosu.asc /usr/local/bin/gosu && \
    rm -rf "$GNUPGHOME" /tmp/gosu.asc && \
    chmod +x /usr/local/bin/gosu && \
    # gosu install end
    curl -sSL https://get.helm.sh/helm-v${HELM_VERSION}-linux-amd64.tar.gz | \
    tar -xz -C /usr/local/bin --strip-components=1 linux-amd64/helm && \
    git clone https://github.com/zonca/jupyterhub-deploy-kubernetes-jetstream \
        /home/openstack/jupyterhub-deploy-kubernetes-jetstream && \
    git clone https://github.com/Unidata/usg-devops \
        /home/openstack/usg-devops && \
    pip3 install --upgrade pip && \
    pip3 install --upgrade --ignore-installed -r /tmp/requirements.txt

WORKDIR /home/openstack

COPY nu /home/openstack/.config/nushell
COPY entrypoint.sh /
RUN chmod +x /entrypoint.sh

# Start container
ENTRYPOINT ["/entrypoint.sh"]
