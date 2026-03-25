# gstack-sandbox

Containerized development environment for running [Claude Code](https://github.com/anthropics/claude-code) with [gstack](https://github.com/garrytan/gstack) skills on any repository. Pre-configured with a full Go and Kubernetes operator development toolchain.

## What's Inside

### AI Tools
- **Claude Code** - Anthropic's AI coding assistant (CLI)
- **gstack** - 28 specialized Claude Code skills for the full sprint cycle (Think, Plan, Build, Review, Test, Ship, Reflect)
- **Serena MCP** - Semantic code retrieval and symbol-level editing
- **Context7 MCP** - Up-to-date library documentation lookup

### Go Development
- Go 1.26.1
- gopls, delve, staticcheck, golangci-lint
- protoc + protoc-gen-go / protoc-gen-go-grpc

### Kubernetes & Operator Development
- kubectl v1.35.3
- Helm v4.1.3
- Kustomize v5.8.1
- Kubebuilder v4.13.0
- Operator SDK v1.42.2
- controller-gen, setup-envtest
- kind v0.31.0 (local clusters)

### General
- Ubuntu 24.04 base
- Node.js 24 LTS, Bun
- tmux, vim, git, make, jq, yq, curl, and more
- Runs as non-root `claude` user (UID 1000) with sudo access

## Quick Start

```bash
# 1. Clone this repo
git clone https://github.com/b42labs/gstack-sandbox.git
cd gstack-sandbox

# 2. Configure environment
cp .env.example .env
# Edit .env and set your ANTHROPIC_API_KEY

# 3. Build and start
docker compose up -d --build

# 4. Attach to the running container (enters a tmux session)
docker compose attach claude-sandbox

# 5. Inside the container, start Claude Code
claude
```

## Configuration

### Environment Variables

| Variable | Required | Description |
|---|---|---|
| `ANTHROPIC_API_KEY` | Yes | Your Anthropic API key for Claude Code |
| `CONTEXT7_API_KEY` | No | Context7 API key for higher rate limits ([get one here](https://context7.com/dashboard)) |
| `REPO_PATH` | No | Host path to the repository to mount as `/workspace` (default: `.`) |

### Mounting a Different Repository

Set `REPO_PATH` in your `.env` file to point at any local repository:

```bash
REPO_PATH=/path/to/your/project
```

The repository will be available at `/workspace` inside the container.

### Kubernetes Cluster Access

To connect to a Kubernetes cluster from inside the container, uncomment the kubeconfig volume mount in `docker-compose.yml`:

```yaml
volumes:
  # ...
  - ${HOME}/.kube:/home/claude/.kube:ro
```

## Architecture

```
Container (claude-sandbox)
├── /workspace              ← Your repo (bind mount)
├── /home/claude
│   ├── .claude/
│   │   └── skills/gstack   ← Pre-built gstack installation
│   ├── .claude.json         ← MCP server config (Serena + Context7)
│   ├── go/                  ← GOPATH + installed Go tools
│   └── .bun/                ← Bun runtime
└── /usr/local/bin/          ← kubectl, helm, kubebuilder, operator-sdk, ...
```

### Persistent Volumes

| Volume | Purpose |
|---|---|
| `go-mod-cache` | Go module download cache |
| `claude-config` | Claude Code configuration and conversation history |
| `gstack-skills` | gstack installation (survives rebuilds) |
| `uv-cache` | Python/uv cache for Serena MCP |

## Usage

### Claude Code with gstack Skills

Once inside the tmux session, Claude Code has access to all 28 gstack skills:

```bash
claude                    # Start Claude Code
claude /office-hours      # Use a specific gstack skill
claude /review            # Code review skill
claude /qa                # QA skill
```

### MCP Servers

Both MCP servers are pre-configured in `~/.claude.json` and start automatically when Claude Code runs:

- **Serena** - Use `/mcp` inside Claude Code to verify it's connected. Provides semantic code navigation and symbol-level editing.
- **Context7** - Resolves library documentation on demand. Ask Claude to look up docs for any library.

## Rebuilding

```bash
# Rebuild without cache (e.g., after version bumps)
docker compose build --no-cache

# Rebuild and restart
docker compose up -d --build
```

## License

Apache License 2.0
