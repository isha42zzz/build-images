ARG BASE_IMAGE=ubuntu:24.04
FROM ${BASE_IMAGE}


# change dash to bash as default shell
RUN ln -sf /usr/bin/bash /bin/sh


RUN apt update && DEBIAN_FRONTEND=noninteractive TZ=Etc/UTC apt install -y \
    tzdata \ 
    build-essential \
    ocaml \
    automake \
    autoconf \
    libtool \
    wget \
    python-is-python3 \
    python3-pip \
    libssl-dev \
    npm \
    git \
    debhelper \
    zip \ 
    libcurl4-openssl-dev \
    pkgconf \ 
    libboost-dev \ 
    libboost-system-dev \ 
    libboost-thread-dev \
    protobuf-c-compiler \
    libprotobuf-c-dev \
    vim \
    golang \
    cmake \
    ninja-build  \
    curl \
    ssh \
    llvm-dev libclang-dev clang \
    rsync \
    libfuse2 \
    && rm -f /etc/ssh/ssh_host_* \
    && apt clean 


# instal protoc v3.19.4
RUN curl -LO https://github.com/protocolbuffers/protobuf/releases/download/v3.19.4/protoc-3.19.4-linux-x86_64.zip \
   && unzip protoc-3.19.4-linux-x86_64.zip -d /root/.local && echo 'export PATH="/root/.local/bin:$PATH"' >> /root/.bashrc \
   && rm -f protoc-3.19.4-linux-x86_64.zip


# install conda
RUN wget http://repo.anaconda.com/miniconda/Miniconda3-py310_24.4.0-0-Linux-x86_64.sh \
  && bash Miniconda3-py310_24.4.0-0-Linux-x86_64.sh -b && rm -f Miniconda3-py310_24.4.0-0-Linux-x86_64.sh \
  && ln -sf /root/miniconda3/bin/conda /usr/bin/conda \
  && conda init


# install bazelisk 
RUN npm install -g @bazel/bazelisk


# install emsdk
RUN git clone https://github.com/emscripten-core/emsdk.git /opt/emsdk && cd /opt/emsdk \
    && ./emsdk install latest && ./emsdk activate latest && echo "source /opt/emsdk/emsdk_env.sh" >> /root/.bashrc


# install rust
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | bash -s -- -y
RUN curl -LsSf https://get.nexte.st/latest/linux | tar zxf - -C ${CARGO_HOME:-~/.cargo}/bin


# install dcap lib in ubuntu 24.04
RUN echo 'deb [signed-by=/etc/apt/keyrings/intel-sgx-keyring.asc arch=amd64] https://download.01.org/intel-sgx/sgx_repo/ubuntu noble main' | tee /etc/apt/sources.list.d/intel-sgx.list \
  && wget https://download.01.org/intel-sgx/sgx_repo/ubuntu/intel-sgx-deb.key \
  && cat intel-sgx-deb.key | tee /etc/apt/keyrings/intel-sgx-keyring.asc > /dev/null \
  && rm -f intel-sgx-deb.key \
  && apt-get update && apt-get install -y libsgx-epid libsgx-quote-ex libsgx-dcap-ql libsgx-dcap-quote-verify-dev\
  && apt-get install -y libsgx-dcap-default-qpl \
  && apt clean \
  && pushd /usr/lib/x86_64-linux-gnu/ && ln -s libdcap_quoteprov.so.1 libdcap_quoteprov.so && popd


# install sgx sdk in ubuntu 24.04
RUN wget https://download.01.org/intel-sgx/latest/linux-latest/distro/ubuntu24.04-server/sgx_linux_x64_sdk_2.26.100.0.bin \
  && chmod +x sgx_linux_x64_sdk_2.26.100.0.bin \ 
  && ./sgx_linux_x64_sdk_2.26.100.0.bin --prefix=/opt/intel/ \
  && source /opt/intel/sgxsdk/environment \
  && rm -f sgx_linux_x64_sdk_2.26.100.0.bin


# install tdx in ubuntu 24.04
# (1) Add kobuk PPA for attestation and create apt pinning / unattended-upgrades config
ENV TDX_PPA_ATTESTATION=tdx-attestation-release
RUN set -eux; \
                apt-get update; \
                apt-get install -y software-properties-common; \
                ppa_id="${TDX_PPA_ATTESTATION}"; \
                team="kobuk-team"; \
                if echo "$ppa_id" | grep -q '^ppa:'; then \
                        fullname="${ppa_id#ppa:}"; \
                        team="${fullname%%/*}"; \
                        ppa_id="${fullname##*/}"; \
                fi; \
                add-apt-repository -y "ppa:${team}/${ppa_id}"; \
                distro_id="LP-PPA-${team}-${ppa_id}"; \
                UBUNTU_CODENAME=$(lsb_release -cs); \
                mkdir -p /etc/apt/preferences.d; \
                printf '%s\n' "Package: *" "Pin: release o=${distro_id}" "Pin-Priority: 4000" > /etc/apt/preferences.d/kobuk-tdx-${team}-${ppa_id}-pin-4000; \
                printf '%s\n' "Unattended-Upgrade::Allowed-Origins {" "\"${distro_id}:${UBUNTU_CODENAME}\";" "};" "Unattended-Upgrade::Allow-downgrade \"true\";" > /etc/apt/apt.conf.d/99unattended-upgrades-kobuk-${ppa_id}

# (2) Update and install attestation packages (allow downgrades as pinned)
RUN apt-get update \
        && apt-get install -y --allow-downgrades libtdx-attest-dev trustauthority-cli || true \
        && rm -rf /var/lib/apt/lists/*
