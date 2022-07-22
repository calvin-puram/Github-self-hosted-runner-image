FROM ubuntu:20.04

ARG TARGETPLATFORM
ARG RUNNER_VERSION=2.294.0
ARG RUNNER_CONTAINER_HOOKS_VERSION=0.1.2
ARG DOCKER_CHANNEL=stable
ARG DOCKER_VERSION=20.10.12
ARG DUMB_INIT_VERSION=1.2.5

RUN test -n "$TARGETPLATFORM" || (echo "TARGETPLATFORM must be set" && false)

ENV DEBIAN_FRONTEND=noninteractive
RUN apt update -y \
    && apt-get install -y software-properties-common \
    && add-apt-repository -y ppa:git-core/ppa \
    && apt-get update -y \
    && apt-get install -y --no-install-recommends \
    build-essential \
    curl \
    ca-certificates \
    dnsutils \
    ftp \
    acl \
    ansible \
    packer \
    cmake \
    pkg-config \
    libssl-dev \
    clang \
    libclang-dev \
    git \
    iproute2 \
    iputils-ping \
    jq \
    libunwind8 \
    locales \
    netcat \
    openssh-client \
    parallel \
    python3-pip \
    rsync \
    shellcheck \
    sudo \
    telnet \
    time \
    tzdata \
    unzip \
    upx \
    wget \
    zip \
    zstd \
    && ln -sf /usr/bin/python3 /usr/bin/python \
    && ln -sf /usr/bin/pip3 /usr/bin/pip \
    && rm -rf /var/lib/apt/lists/*

# arch command on OS X reports "i386" for Intel CPUs regardless of bitness
RUN export ARCH=$(echo ${TARGETPLATFORM} | cut -d / -f2) \
    && if [ "$ARCH" = "arm64" ]; then export ARCH=aarch64 ; fi \
    && if [ "$ARCH" = "amd64" ] || [ "$ARCH" = "i386" ]; then export ARCH=x86_64 ; fi \
    && curl -f -L -o /usr/local/bin/dumb-init https://github.com/Yelp/dumb-init/releases/download/v${DUMB_INIT_VERSION}/dumb-init_${DUMB_INIT_VERSION}_${ARCH} \
    && chmod +x /usr/local/bin/dumb-init

# Docker download supports arm64 as aarch64 & amd64 / i386 as x86_64
RUN set -vx; \
    export ARCH=$(echo ${TARGETPLATFORM} | cut -d / -f2) \
    && if [ "$ARCH" = "arm64" ]; then export ARCH=aarch64 ; fi \
    && if [ "$ARCH" = "amd64" ] || [ "$ARCH" = "i386" ]; then export ARCH=x86_64 ; fi \
    && curl -f -L -o docker.tgz https://download.docker.com/linux/static/${DOCKER_CHANNEL}/${ARCH}/docker-${DOCKER_VERSION}.tgz \
    && tar zxvf docker.tgz \
    && install -o root -g root -m 755 docker/docker /usr/local/bin/docker \
    && rm -rf docker docker.tgz \
    && adduser --disabled-password --gecos "" --uid 1000 runner \
    && groupadd docker \
    && usermod -aG sudo runner \
    && usermod -aG docker runner \
    && echo "%sudo   ALL=(ALL:ALL) NOPASSWD:ALL" > /etc/sudoers


ENV RUNNER_ASSETS_DIR=/runnertmp
RUN export ARCH=$(echo ${TARGETPLATFORM} | cut -d / -f2) \
    && if [ "$ARCH" = "amd64" ] || [ "$ARCH" = "x86_64" ] || [ "$ARCH" = "i386" ]; then export ARCH=x64 ; fi \
    && mkdir -p "$RUNNER_ASSETS_DIR" \
    && cd "$RUNNER_ASSETS_DIR" \
    # Comment-out the below curl invocation when you use your own build of actions/runner
    && curl -f -L -o runner.tar.gz https://github.com/actions/runner/releases/download/v${RUNNER_VERSION}/actions-runner-linux-${ARCH}-${RUNNER_VERSION}.tar.gz \
    && tar xzf ./runner.tar.gz \
    && rm runner.tar.gz \
    && ./bin/installdependencies.sh \
    && mv ./externals ./externalstmp \
    && apt-get install -y libyaml-dev \
    && rm -rf /var/lib/apt/lists/*

RUN cd "$RUNNER_ASSETS_DIR" \
    && curl -f -L -o runner-container-hooks.zip https://github.com/actions/runner-container-hooks/releases/download/v${RUNNER_CONTAINER_HOOKS_VERSION}/actions-runner-hooks-k8s-${RUNNER_CONTAINER_HOOKS_VERSION}.zip \
    && unzip ./runner-container-hooks.zip -d ./k8s \
    && rm runner-container-hooks.zip

ENV RUNNER_TOOL_CACHE=/opt/hostedtoolcache
RUN mkdir /opt/hostedtoolcache \
    && chgrp docker /opt/hostedtoolcache \
    && chmod g+rwx /opt/hostedtoolcache


COPY entrypoint.sh logger.bash update-status /usr/bin/

# Configure hooks folder structure.
COPY hooks /etc/arc/hooks/

ENV HOME=/home/runner



# Add the Python "User Script Directory" to the PATH
ENV PATH="${PATH}:${HOME}/.local/bin"
ENV ImageOS=ubuntu20

RUN echo "PATH=${PATH}" > /etc/environment \
    && echo "ImageOS=${ImageOS}" >> /etc/environment

USER runner


ENTRYPOINT ["/usr/local/bin/dumb-init", "--"]
CMD ["entrypoint.sh"]
