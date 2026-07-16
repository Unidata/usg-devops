FROM ubuntu:24.04

ARG GOSU_VERSION=1.19

ENV GOSU_URL="https://github.com/tianon/gosu/releases/download/${GOSU_VERSION}/gosu-amd64" \
    HOME=/home/openstack \
    PATH=/home/openstack/bin:/home/openstack/.local/bin:/home/openstack/image-builder/images/capi/.local/bin:$PATH \
    IMAGE_BUILDER="https://github.com/kubernetes-sigs/image-builder"

RUN mkdir -p /home/openstack/bin

RUN apt update && apt upgrade -y && \
    apt install -y vim git curl unzip findutils diffutils less \
    python3 python-is-python3 python3-pip jq build-essential \
    ca-certificates gnupg \
    python3-openstackclient python3-magnumclient \
    python3-octaviaclient python3-designate && \
    apt clean && rm -rf /var/lib/apt/lists/* && \
    # gosu install start
    curl -fsSL $GOSU_URL -o /usr/local/bin/gosu && \
    curl -fsSL $GOSU_URL.asc -o /tmp/gosu.asc && \
    export GNUPGHOME="$(mktemp -d)" && \
    # @tianon's, maintainer of gosu, public key, in case you are wondering
    export KEY=B42F6819007F00F88E364FD4036A9C25BF357DD4 && \
    gpg --batch --keyserver hkps://keys.openpgp.org --recv-keys $KEY && \
    gpg --batch --verify /tmp/gosu.asc /usr/local/bin/gosu && \
    gpgconf --kill all && \
    rm -rf "$GNUPGHOME" /tmp/gosu.asc && \
    chmod +x /usr/local/bin/gosu
    # gosu install end

USER openstack

# Begin image-builder
WORKDIR /home/openstack
RUN git clone $IMAGE_BUILDER && \
    cd image-builder/images/capi/ && \
    make deps-openstack

# $HOME/.local/bin is the ansible install path
# $HOME/image-builder/images/capi/.local/bin is the packer install path
ENV PATH=$HOME/.local/bin:$HOME/image-builder/images/capi/.local/bin:$PATH
# End image-builder
    
COPY entrypoint.sh /
RUN chmod +x /entrypoint.sh

# Start container
ENTRYPOINT ["/entrypoint.sh"]
