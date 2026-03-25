FROM ubuntu:24.04

ARG GO_VERSION=1.26.1
ARG KUBECTL_VERSION=v1.35.3
ARG HELM_VERSION=v4.1.3
ARG KUSTOMIZE_VERSION=v5.8.1
ARG KUBEBUILDER_VERSION=v4.13.0
ARG OPERATOR_SDK_VERSION=v1.42.2
ARG NODE_VERSION=24
ARG BUN_VERSION=latest
ARG TARGETARCH

ENV DEBIAN_FRONTEND=noninteractive \
    LANG=en_US.UTF-8 \
    LC_ALL=en_US.UTF-8 \
    GOPATH=/home/claude/go \
    PATH="/usr/local/go/bin:/home/claude/go/bin:/home/claude/.npm-global/bin:/home/claude/.bun/bin:/home/claude/.local/bin:${PATH}"

# ── Base packages ────────────────────────────────────────────────────────────
RUN apt-get update && apt-get install -y --no-install-recommends \
    bash \
    build-essential \
    ca-certificates \
    curl \
    dnsutils \
    file \
    git \
    gnupg \
    iproute2 \
    jq \
    less \
    locales \
    make \
    netcat-openbsd \
    openssh-client \
    protobuf-compiler \
    python3 \
    python3-pip \
    python3-venv \
    sudo \
    tmux \
    tree \
    unzip \
    vim \
    wget \
    zip \
    && locale-gen en_US.UTF-8 \
    && rm -rf /var/lib/apt/lists/*

# ── Go ───────────────────────────────────────────────────────────────────────
RUN ARCH=$(dpkg --print-architecture) && \
    curl -fsSL "https://go.dev/dl/go${GO_VERSION}.linux-${ARCH}.tar.gz" \
    | tar -C /usr/local -xz

# ── Node.js (for Claude Code) ───────────────────────────────────────────────
RUN curl -fsSL https://deb.nodesource.com/setup_${NODE_VERSION}.x | bash - && \
    apt-get install -y --no-install-recommends nodejs && \
    rm -rf /var/lib/apt/lists/*

# ── uv (Python package manager, for Serena MCP) ─────────────────────────────
RUN curl -LsSf https://astral.sh/uv/install.sh | sh && \
    mv /root/.local/bin/uv /usr/local/bin/uv && \
    mv /root/.local/bin/uvx /usr/local/bin/uvx

# ── kubectl ──────────────────────────────────────────────────────────────────
RUN ARCH=$(dpkg --print-architecture) && \
    curl -fsSL "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/${ARCH}/kubectl" \
    -o /usr/local/bin/kubectl && \
    chmod +x /usr/local/bin/kubectl

# ── Helm ─────────────────────────────────────────────────────────────────────
RUN ARCH=$(dpkg --print-architecture) && \
    curl -fsSL "https://get.helm.sh/helm-${HELM_VERSION}-linux-${ARCH}.tar.gz" \
    | tar -xz --strip-components=1 -C /usr/local/bin "linux-${ARCH}/helm"

# ── Kustomize ────────────────────────────────────────────────────────────────
RUN ARCH=$(dpkg --print-architecture) && \
    curl -fsSL "https://github.com/kubernetes-sigs/kustomize/releases/download/kustomize%2F${KUSTOMIZE_VERSION}/kustomize_${KUSTOMIZE_VERSION}_linux_${ARCH}.tar.gz" \
    | tar -xz -C /usr/local/bin

# ── Kubebuilder ──────────────────────────────────────────────────────────────
RUN ARCH=$(dpkg --print-architecture) && \
    curl -fsSL "https://github.com/kubernetes-sigs/kubebuilder/releases/download/${KUBEBUILDER_VERSION}/kubebuilder_linux_${ARCH}" \
    -o /usr/local/bin/kubebuilder && \
    chmod +x /usr/local/bin/kubebuilder

# ── Operator SDK ─────────────────────────────────────────────────────────────
RUN ARCH=$(dpkg --print-architecture) && \
    curl -fsSL "https://github.com/operator-framework/operator-sdk/releases/download/${OPERATOR_SDK_VERSION}/operator-sdk_linux_${ARCH}" \
    -o /usr/local/bin/operator-sdk && \
    chmod +x /usr/local/bin/operator-sdk

# ── yq ───────────────────────────────────────────────────────────────────────
RUN ARCH=$(dpkg --print-architecture) && \
    curl -fsSL "https://github.com/mikefarah/yq/releases/latest/download/yq_linux_${ARCH}" \
    -o /usr/local/bin/yq && \
    chmod +x /usr/local/bin/yq

# ── kind (Kubernetes in Docker) ──────────────────────────────────────────────
RUN ARCH=$(dpkg --print-architecture) && \
    curl -fsSL "https://kind.sigs.k8s.io/dl/v0.31.0/kind-linux-${ARCH}" \
    -o /usr/local/bin/kind && \
    chmod +x /usr/local/bin/kind

# ── Create claude user ───────────────────────────────────────────────────────
RUN userdel -r ubuntu 2>/dev/null || true; \
    groupdel ubuntu 2>/dev/null || true; \
    groupadd -g 1000 claude && \
    useradd -m -u 1000 -g 1000 -s /bin/bash claude && \
    echo "claude ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/claude

USER claude
WORKDIR /home/claude

# ── Go tools (as claude user) ────────────────────────────────────────────────
RUN go install sigs.k8s.io/controller-tools/cmd/controller-gen@latest && \
    go install sigs.k8s.io/controller-runtime/tools/setup-envtest@latest && \
    go install golang.org/x/tools/gopls@latest && \
    go install github.com/go-delve/delve/cmd/dlv@latest && \
    go install honnef.co/go/tools/cmd/staticcheck@latest && \
    go install github.com/golangci/golangci-lint/cmd/golangci-lint@latest && \
    go install google.golang.org/protobuf/cmd/protoc-gen-go@latest && \
    go install google.golang.org/grpc/cmd/protoc-gen-go-grpc@latest

# ── Bun (for gstack) ────────────────────────────────────────────────────────
RUN curl -fsSL https://bun.sh/install | bash

# ── Claude Code ──────────────────────────────────────────────────────────────
RUN npm config set prefix /home/claude/.npm-global && \
    npm install -g @anthropic-ai/claude-code

# ── gstack (Claude Code skills) ─────────────────────────────────────────────
RUN mkdir -p /home/claude/.claude/skills && \
    git clone https://github.com/garrytan/gstack.git /home/claude/.claude/skills/gstack && \
    cd /home/claude/.claude/skills/gstack && \
    bun install && \
    bun run build

# ── Pre-cache Serena MCP server ──────────────────────────────────────────────
RUN uvx --from git+https://github.com/oraios/serena serena --help || true

# ── Claude Code MCP server config ───────────────────────────────────────────
RUN mkdir -p /home/claude/.claude && \
    cat > /home/claude/.claude.json <<'CEOF'
{
  "mcpServers": {
    "context7": {
      "type": "stdio",
      "command": "npx",
      "args": ["-y", "@upstash/context7-mcp"]
    },
    "serena": {
      "type": "stdio",
      "command": "uvx",
      "args": [
        "--from", "git+https://github.com/oraios/serena",
        "serena", "start-mcp-server",
        "--context", "claude-code",
        "--project-from-cwd"
      ]
    }
  }
}
CEOF

# ── Shell config ─────────────────────────────────────────────────────────────
RUN echo '\n\
# Go\n\
export GOPATH=/home/claude/go\n\
export PATH="/usr/local/go/bin:${GOPATH}/bin:${HOME}/.bun/bin:${HOME}/.local/bin:${PATH}"\n\
\n\
# Kubernetes\n\
alias k=kubectl\n\
source <(kubectl completion bash)\n\
complete -o default -F __start_kubectl k\n\
source <(helm completion bash)\n\
' >> /home/claude/.bashrc

# ── tmux config ──────────────────────────────────────────────────────────────
RUN echo '\
set -g default-terminal "screen-256color"\n\
set -g mouse on\n\
set -g history-limit 50000\n\
set -g status-style "bg=colour235,fg=colour136"\n\
set -g status-left "#[fg=colour46]#S "\n\
set -g status-right "#[fg=colour136]%H:%M"\n\
' > /home/claude/.tmux.conf

WORKDIR /workspace

# ── Entrypoint ───────────────────────────────────────────────────────────────
COPY --chown=claude:claude entrypoint.sh /home/claude/entrypoint.sh
RUN chmod +x /home/claude/entrypoint.sh

ENTRYPOINT ["/home/claude/entrypoint.sh"]
