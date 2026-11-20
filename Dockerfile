FROM ubuntu:22.04

# set the github runner version
ARG RUNNER_VERSION="2.338.2"
ARG DOCKER_GID="121"
ARG RUST_TOOLCHAIN="nightly-2026-01-30"
ARG LINDERA_GIT_REV="25d36a02558ff1a523d2439345d03a28eb9beb3a"
ENV LINDERA_CACHE=/opt/lindera-cache

# copy over the start.sh script
WORKDIR /home/docker/actions-runner

RUN export DEBIAN_FRONTEND=noninteractive && \
    sed -i \
        -e 's@://archive\.ubuntu\.com/@://mirrors.aliyun.com/@g' \
        -e 's@://security\.ubuntu\.com/@://mirrors.aliyun.com/@g' \
        -e 's@://ports\.ubuntu\.com/@://mirrors.aliyun.com/@g' \
        /etc/apt/sources.list && \
    apt-get update --error-on=any && \
    apt-get upgrade -y

RUN export DEBIAN_FRONTEND=noninteractive ARCH=`dpkg --print-architecture` && \
    groupadd -g ${DOCKER_GID} docker && useradd -m docker -g docker && \
    apt-get install -y --no-install-recommends ca-certificates curl jq gnupg software-properties-common \
    build-essential libssl-dev libffi-dev pkg-config python3 python3-venv python3-dev python3-pip unzip \
    git cmake protobuf-compiler lld sudo && \
    install -m 0755 -d /etc/apt/keyrings && \
    curl -fsSL https://mirrors.aliyun.com/docker-ce/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc && \
    chmod a+r /etc/apt/keyrings/docker.asc && \
    echo "deb [arch=${ARCH} signed-by=/etc/apt/keyrings/docker.asc] https://mirrors.aliyun.com/docker-ce/linux/ubuntu jammy stable" \
        > /etc/apt/sources.list.d/docker.list && \
    apt-get update && \
    apt-get install -y docker-ce docker-ce-cli containerd.io && \
    export ARCH=`dpkg --print-architecture | sed --expression='s/amd/x/g'` && \
    export FILENAME=actions-runner-linux-${ARCH}-${RUNNER_VERSION}.tar.gz && \
    curl -O -L https://github.com/actions/runner/releases/download/v${RUNNER_VERSION}/${FILENAME} && \
    tar xzf ./$FILENAME && chown -R docker /home/docker && ./bin/installdependencies.sh

RUN mkdir -p ${LINDERA_CACHE} && chown -R docker:docker ${LINDERA_CACHE}

#COPY warm-lindera-cache.sh /usr/local/bin/warm-lindera-cache
#RUN chmod +x /usr/local/bin/warm-lindera-cache

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
RUN cargo install -q cargo-sort@1.0.9 cargo-nextest@0.9.85 cargo-llvm-cov@0.6.15 --locked
#RUN LINDERA_GIT_REV=${LINDERA_GIT_REV} warm-lindera-cache

ARG MBX_VERSION="1.30.0"
RUN set -euo pipefail; \
    case "$(dpkg --print-architecture)" in \
        amd64) arch=x86_64 ;; \
        arm64) arch=aarch64 ;; \
        *) echo "Unsupported mbx architecture" >&2; exit 1 ;; \
    esac; \
    archive="mbx-${arch}-unknown-linux-musl.tar.gz"; \
    release="https://github.com/jdx/mr-boxington/releases/download/v${MBX_VERSION}"; \
    tmpdir="$(mktemp -d)"; \
    cd "$tmpdir"; \
    curl -fsSLO "$release/$archive"; \
    curl -fsSLO "$release/SHA256SUMS"; \
    grep -F "  $archive" SHA256SUMS | sha256sum --check --strict -; \
    tar -xzf "$archive"; \
    install -m 0755 mbx "$HOME/.cargo/bin/mbx"; \
    cd /; \
    rm -rf "$tmpdir"; \
    mbx setup --yes; \
    test -x "$HOME/.local/share/mbx/bin/cargo"

# set the entrypoint to the start.sh script
COPY start.sh /home/docker/actions-runner/start.sh
ENTRYPOINT ["./start.sh"]
