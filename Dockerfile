FROM ubuntu:22.04

# set the github runner version
ARG RUNNER_VERSION="2.323.0"
ARG DOCKER_GID="121"
ARG RUST_TOOLCHAIN="nightly-2023-12-10"

# copy over the start.sh script
WORKDIR /home/docker/actions-runner

RUN export DEBIAN_FRONTEND=noninteractive && \
    sed -i s@/archive.ubuntu.com/@/apt.ksyun.cn/@g /etc/apt/sources.list && \
    sed -i s@/security.ubuntu.com/@/apt.ksyun.cn/@g /etc/apt/sources.list && \
    apt-get update -y && \
    apt-get upgrade -y

RUN export DEBIAN_FRONTEND=noninteractive ARCH=`dpkg --print-architecture` && \
    groupadd -g ${DOCKER_GID} docker && useradd -m docker -g docker && \
    apt-get install -y --no-install-recommends curl jq gnupg software-properties-common \ 
    build-essential libssl-dev libffi-dev python3 python3-venv python3-dev python3-pip unzip \
    git cmake protobuf-compiler sudo && \
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add - && \
    add-apt-repository "deb [arch=${ARCH}] https://download.docker.com/linux/ubuntu jammy stable" && \
    apt install docker-ce docker-ce-cli containerd.io -y && \
    export ARCH=`dpkg --print-architecture | sed --expression='s/amd/x/g'` && \
    export FILENAME=actions-runner-linux-${ARCH}-${RUNNER_VERSION}.tar.gz && \
    curl -O -L https://github.com/actions/runner/releases/download/v${RUNNER_VERSION}/${FILENAME} && \
    tar xzf ./$FILENAME && chown -R docker /home/docker && ./bin/installdependencies.sh

COPY start.sh /home/docker/actions-runner/start.sh

# since the config and run script for actions are not allowed to be run by root,
# set the user to "docker" so all subsequent commands are run as the docker user
USER docker

RUN curl https://sh.rustup.rs -sSf | sh -s -- --no-modify-path --default-toolchain none -y
SHELL ["/bin/bash", "-c"]
RUN echo $'[source.crates-io]\n\
replace-with = "aliyun"\n\
[source.aliyun]\n\
registry = "sparse+https://mirrors.aliyun.com/crates.io-index/"\n\
' > /home/docker/.cargo/config.toml
ENV CARGO_UNSTABLE_SPARSE_REGISTRY true
ENV PATH /home/docker/.cargo/bin/:$PATH
RUN rustup toolchain install ${RUST_TOOLCHAIN} --profile minimal --no-self-update && \
    rustup component add rustfmt clippy rust-src rust-analyzer
RUN cargo install -q cargo-sort cargo-nextest@0.9.85 --locked

# set the entrypoint to the start.sh script
ENTRYPOINT ["./start.sh"]
