#
# Github-Actions runner image.
#

FROM rodnymolina588/ubuntu-jammy-docker
LABEL maintainer="rodny.molina@docker.com"

ENV AGENT_TOOLSDIRECTORY=/opt/hostedtoolcache
RUN mkdir -p /opt/hostedtoolcache

ARG GH_RUNNER_VERSION="2.328.0"

ARG TARGETPLATFORM

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

RUN export DEBIAN_FRONTEND=noninteractive
ENV TZ=Europe/Paris
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone
ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends dumb-init jq sudo \
  && groupadd -g 121 runner \
  && useradd -mr -d /home/runner -u 1001 -g 121 runner \
  && usermod -aG sudo runner \
  && usermod -aG docker runner \
  && echo '%sudo ALL=(ALL) NOPASSWD: ALL' >> /etc/sudoers

# setup pbuilder env
RUN apt-get update -qq && apt-get install -qq cmake cmake-data cython3 dh-python javascript-common libarchive13 libblas3 libeigen3-dev libexpat1-dev libjs-jquery libjs-jquery-isonscreen libjs-jquery-metadata libjs-jquery-tablesorter libjsoncpp-dev liblapack3 liblzo2-2 libpython3-dev librhash0 libuv1 pkg-config python3-all python3-coverage python3-dev python3-pip python3-nose python3-numpy python3-pytest python3-setuptools devscripts build-essential equivs gfortran apt-transport-https curl npm nodejs wget
# end setup pbuilder env

WORKDIR /actions-runner
COPY scr/install_actions.sh /actions-runner

RUN chmod +x /actions-runner/install_actions.sh \
  && /actions-runner/install_actions.sh ${GH_RUNNER_VERSION} ${TARGETPLATFORM} \
  && rm /actions-runner/install_actions.sh \
  && chown runner /_work /actions-runner /opt/hostedtoolcache

COPY scr/token.sh scr/entrypoint.sh scr/app_token.sh /
RUN chmod +x /token.sh /entrypoint.sh /app_token.sh

ENTRYPOINT ["/entrypoint.sh"]
CMD ["./bin/Runner.Listener", "run", "--startuptype", "service"]
