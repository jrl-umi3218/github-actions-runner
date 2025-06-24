# GitHub Actions Runner with Podman-in-Podman

A self-hosted GitHub Actions runner based on Ubuntu 22.04 with complete Podman-in-Podman isolation. Perfect for organizations that need secure, isolated container builds without affecting the host Docker daemon.

## 🚀 Quick Start

### For Organization Runners (Recommended)

1. **Get a runner token** from your GitHub organization:
   - Go to Organization Settings → Actions → Runners
   - Click "New runner" → "New self-hosted runner"
   - Copy the token

2. **Build and run**:
   ```bash
   git clone <this-repo>
   cd github-runner-podman
   
   # Build the image
   podman build -t github-runner-podman .
   
   # Run organization runner
   podman run -d \
     --name github-runner-org \
     -e ORG_URL="https://github.com/your-organization" \
     -e RUNNER_TOKEN="your_token_here" \
     -e RUNNER_NAME="org-podman-runner-01" \
     github-runner-podman
   ```

3. **Or use Podman Compose**:
   ```bash
   # Edit podman-compose.yml with your details
   podman-compose up -d github-runner-org
   ```

## 🔧 Management

Use the interactive management script:

```bash
chmod +x manage-runners.sh
./manage-runners.sh
```

This provides a menu to:
- Build images
- Create/remove runners  
- Scale runner pools
- Monitor health
- View logs

## 🏗️ Example mc_rtc Workflow

```yaml
name: Build mc_rtc
on: [push, pull_request]

jobs:
  build:
    runs-on: [self-hosted, ubuntu-22.04, podman, organization]
    
    steps:
    - uses: actions/checkout@v4
    
    - name: Build mc_rtc
      run: |
        podman run --rm -v $PWD:/workspace \
          ubuntu:22.04 bash -c "
          cd /workspace && 
          apt-get update && 
          apt-get install -y build-essential cmake libboost-all-dev && 
          mkdir -p build && cd build && 
          cmake .. && make -j\$(nproc)
          "
    
    - name: Safe cleanup
      run: |
        podman system prune -af --volumes
        # Only affects isolated Podman environment!
```

## ✅ Key Features

- **Complete isolation** - Podman runs rootless, can't affect host
- **Docker compatibility** - `docker` commands work transparently  
- **Organization support** - Centralized runner management
- **Safe cleanup** - `podman system prune -af` is completely safe
- **No privileged containers** - Enhanced security
- **Easy scaling** - Add runners with simple commands

## 📁 Repository Structure

```
github-runner-podman/
├── Dockerfile              # Main runner image
├── entrypoint.sh           # Runner startup script
├── podman-compose.yml      # Multi-runner deployment
├── manage-runners.sh       # Interactive management
└── README.md              # This file
```

## 🔒 Security Benefits

Unlike traditional Docker-in-Docker setups that require `--privileged` and host socket mounting, this approach:

- Runs containers as non-root user
- Uses user namespaces for isolation
- No host Docker daemon access
- Safe resource cleanup
- Isolated storage per runner

Perfect for CI/CD workloads that need container builds without compromising host security!
