# Copyright 2023 Ant Group Co., Ltd.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#   http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

FROM secretflow/trustflow-dev-occlum-ubuntu22.04:latest as builder

ARG PLATFORM

WORKDIR /home/admin/dev

ENV PROTOC /root/.local/bin/protoc

COPY Cargo.toml ./
COPY capsule-manager ./capsule-manager
COPY bin ./bin
COPY script ./script

RUN ./script/build.sh -p $PLATFORM

FROM secretflow/trustflow-release-occlum-ubuntu22.04:latest

# for occlum build, we need to install following pkgs
RUN apt update && DEBIAN_FRONTEND=noninteractive TZ=Etc/UTC apt install -y \
	build-essential \
	rsync \
	libfuse2 \
	&& apt clean

COPY --from=builder /home/admin/dev/script/occlum_instance /home/admin/occlum_instance

WORKDIR /home/admin/occlum_instance
