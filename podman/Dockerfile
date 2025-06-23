FROM ubuntu:22.04

# Avoid interactive prompts during package installation
ENV DEBIAN_FRONTEND=noninteractive

# Install dependencies
RUN apt-get update && apt-get install -y \
    curl \
    git \
    jq \
    sudo \
    tar \
    unzip \
    zip \
    ca-certificates \
    gnupg \
    lsb-release \
    software-properties-common \
    podman \
    slirp4netns \
    fuse-overlayfs \
    buildah \
    skopeo \
    && rm -rf /var/lib/apt/lists/*

# Create runner user with sudo privileges
RUN useradd -m -s /bin/bash runner \
    && echo "runner ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

# Configure subuid/subgid for rootless Podman
RUN echo 'runner:100000:65536' >> /etc/subuid \
    && echo 'runner:100000:65536' >> /etc/subgid

# Set up Podman configuration for runner user
USER runner
WORKDIR /home/runner

# Create Podman config directories
RUN mkdir -p ~/.config/containers

# Configure Podman for rootless operation
RUN echo '[containers]' > ~/.config/containers/containers.conf \
    && echo 'netns="slirp4netns"' >> ~/.config/containers/containers.conf \
    && echo 'userns="auto"' >> ~/.config/containers/containers.conf \
    && echo 'utsns="auto"' >> ~/.config/containers/containers.conf \
    && echo 'ipcns="auto"' >> ~/.config/containers/containers.conf \
    && echo 'volumes_from="false"' >> ~/.config/containers/containers.conf \
    && echo 'default_capabilities = [' >> ~/.config/containers/containers.conf \
    && echo '  "CHOWN",' >> ~/.config/containers/containers.conf \
    && echo '  "DAC_OVERRIDE",' >> ~/.config/containers/containers.conf \
    && echo '  "FOWNER",' >> ~/.config/containers/containers.conf \
    && echo '  "FSETID",' >> ~/.config/containers/containers.conf \
    && echo '  "KILL",' >> ~/.config/containers/containers.conf \
    && echo '  "NET_BIND_SERVICE",' >> ~/.config/containers/containers.conf \
    && echo '  "SETFCAP",' >> ~/.config/containers/containers.conf \
    && echo '  "SETGID",' >> ~/.config/containers/containers.conf \
    && echo '  "SETPCAP",' >> ~/.config/containers/containers.conf \
    && echo '  "SETUID",' >> ~/.config/containers/containers.conf \
    && echo '  "SYS_CHROOT"' >> ~/.config/containers/containers.conf \
    && echo ']' >> ~/.config/containers/containers.conf

# Create Docker alias for compatibility
RUN echo 'alias docker=podman' >> ~/.bashrc \
    && echo 'export DOCKER_HOST=""' >> ~/.bashrc

# Download and install GitHub Actions runner
ARG RUNNER_VERSION="2.311.0"
RUN curl -o actions-runner-linux-x64-${RUNNER_VERSION}.tar.gz -L \
    https://github.com/actions/runner/releases/download/v$\{RUNNER_VERSION\}/actions-runner-linux-x64-$\{RUNNER_VERSION\}.tar.gz \
    && tar xzf actions-runner-linux-x64-${RUNNER_VERSION}.tar.gz \
    && rm actions-runner-linux-x64-${RUNNER_VERSION}.tar.gz

# Install runner dependencies
RUN sudo ./bin/installdependencies.sh

# Copy entrypoint script
COPY entrypoint.sh /home/runner/entrypoint.sh
RUN sudo chmod +x /home/runner/entrypoint.sh

# Set environment variables for GitHub runner
ENV RUNNER_ALLOW_RUNASROOT=1
ENV DOTNET_SYSTEM_GLOBALIZATION_INVARIANT=1

ENTRYPOINT ["/home/runner/entrypoint.sh"]
