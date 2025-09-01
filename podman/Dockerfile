FROM ubuntu:jammy

# Avoid interactive prompts during package installation
ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && \
   apt-get upgrade -y && \
   apt-get install -y --no-install-recommends podman fuse-overlayfs slirp4netns uidmap ca-certificates

# Install dependencies
RUN apt-get update && apt-get install -y \
    curl \
    git \
    jq \
    sudo \
    tar \
    unzip \
    zip \
    gnupg \
    lsb-release \
    software-properties-common \
    buildah \
    skopeo \
    && rm -rf /var/lib/apt/lists/*;

RUN useradd runner -s /bin/bash && \
   echo "runner:1001:64535" > /etc/subuid && \
   echo "runner:1001:64535" > /etc/subgid && \
   echo "runner ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/runner && chmod 0440 /etc/sudoers.d/runner

ARG _REPO_URL="https://raw.githubusercontent.com/containers/image_build/refs/heads/main/podman"
ADD $_REPO_URL/containers.conf /etc/containers/containers.conf
ADD $_REPO_URL/podman-containers.conf /home/podman/.config/containers/containers.conf

RUN mkdir -p /home/runner/.local/share/containers && \
   chown runner:runner -R /home/runner && \
   chmod 0644 /etc/containers/containers.conf

COPY storage.conf /home/runner/.config/containers/storage.conf
RUN chown -R runner:runner /home/runner/.config

VOLUME /home/runner/.local/share/containers

# Replace setuid bits by proper file capabilities for uidmap binaries.
# See <https://github.com/containers/podman/discussions/19931>.
RUN apt-get install -y libcap2-bin && \
    chmod 0755 /usr/bin/newuidmap /usr/bin/newgidmap && \
    setcap cap_setuid=ep /usr/bin/newuidmap && \
    setcap cap_setgid=ep /usr/bin/newgidmap && \
    apt-get autoremove --purge -y libcap2-bin

ENV _CONTAINERS_USERNS_CONFIGURED=""

USER runner
WORKDIR /home/runner

# Create Docker alias for compatibility
RUN echo 'alias docker=podman' >> ~/.bashrc \
    && echo 'export DOCKER_HOST=""' >> ~/.bashrc
RUN sudo ln -s /usr/bin/podman /usr/local/bin/docker

# Download and install GitHub Actions runner
ARG RUNNER_VERSION="2.325.0"
COPY install_actions.sh /tmp/install_actions.sh
RUN /tmp/install_actions.sh $RUNNER_VERSION

# Install runner dependencies
RUN sudo ./bin/installdependencies.sh

# Copy entrypoint script
COPY entrypoint.sh /home/runner/entrypoint.sh
RUN sudo chmod +x /home/runner/entrypoint.sh

# Set environment variables for GitHub runner
ENV RUNNER_ALLOW_RUNASROOT=1
ENV DOTNET_SYSTEM_GLOBALIZATION_INVARIANT=1

ENTRYPOINT ["/home/runner/entrypoint.sh"]
