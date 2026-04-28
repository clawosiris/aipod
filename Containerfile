FROM debian:stable

ARG USERNAME
ARG USER_UID
ARG USER_GID
ARG CHEZMOI_DOTFILES_REPO
ARG DISTROBOX_VERSION=1.8.2.5
ARG USE_RUST=true
ARG USE_NPM=true
ARG USE_UV=true
ARG USE_CLAUDE_CODE=true
ARG USE_CODEX=true
ARG USE_MISE=false
ARG USE_OVERMIND=false
ARG USE_JUST=false

ENV DEBIAN_FRONTEND=noninteractive
ENV LANG=C.UTF-8
ENV LC_ALL=C.UTF-8

RUN apt-get update && apt-get install -y --no-install-recommends \
    # Base system
    base-files \
    base-passwd \
    coreutils \
    util-linux \
    debianutils \
    bash \
    bash-completion \
    dash \
    zsh \
    login \
    passwd \
    sudo \
    locales \
    locales-all \
    tzdata \
    ca-certificates \
    # Package management
    apt \
    apt-utils \
    apt-file \
    dpkg \
    debian-archive-keyring \
    gnupg \
    gpgv \
    # Build toolchain
    build-essential \
    clang \
    lld \
    llvm \
    libclang-rt-dev \
    gcc \
    g++ \
    make \
    cmake \
    ninja-build \
    pkg-config \
    bison \
    flex \
    ccache \
    sccache \
    fakeroot \
    dh-autoreconf \
    autotools-dev \
    # Version control
    git \
    git-lfs \
    gh \
    # Editors and text processing
    vim \
    sed \
    grep \
    diffutils \
    mawk \
    less \
    man-db \
    manpages \
    # Compression
    gzip \
    bzip2 \
    xz-utils \
    lz4 \
    zstd \
    unzip \
    tar \
    pigz \
    pbzip2 \
    # Networking
    curl \
    wget \
    openssh-client \
    mosh \
    iproute2 \
    iputils-ping \
    net-tools \
    netbase \
    netcat-traditional \
    socat \
    # Development libraries
    libbz2-dev \
    libffi-dev \
    libgdbm-dev \
    libicu-dev \
    liblzma-dev \
    libncurses-dev \
    libnghttp2-dev \
    libpq-dev \
    libreadline-dev \
    libsqlite3-dev \
    libssl-dev \
    tk-dev \
    uuid-dev \
    libudev-dev \
    libyaml-dev \
    libelf-dev \
    zlib1g-dev \
    libusb-dev \
    # Languages and tools
    perl \
    protobuf-compiler \
    jq \
    sqlite3 \
    # Debugging and profiling
    gdb \
    strace \
    valgrind \
    htop \
    procps \
    pv \
    # Terminal multiplexers
    tmux \
    screen \
    # Misc utilities
    file \
    findutils \
    tree \
    rsync \
    time \
    bc \
    hostname \
    lsof \
    fastfetch \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

RUN curl -fsSL "https://raw.githubusercontent.com/89luca89/distrobox/${DISTROBOX_VERSION}/distrobox-host-exec" \
        -o /usr/local/bin/distrobox-host-exec \
    && chmod +x /usr/local/bin/distrobox-host-exec

# Create user with sudo access
RUN set -eux; \
    user_group="${USERNAME}"; \
    if [ -n "${USER_GID}" ]; then \
        if getent group "${USER_GID}" >/dev/null; then \
            user_group="$(getent group "${USER_GID}" | cut -d: -f1)"; \
        else \
            groupadd -g "${USER_GID}" "${USERNAME}"; \
        fi; \
    elif ! getent group "${USERNAME}" >/dev/null; then \
        groupadd "${USERNAME}"; \
    fi; \
    set -- useradd -m -s /bin/zsh; \
    if [ -n "${USER_UID}" ]; then \
        set -- "$@" --uid "${USER_UID}"; \
    fi; \
    if [ -n "${USER_GID}" ]; then \
        set -- "$@" --gid "${USER_GID}"; \
    else \
        set -- "$@" --gid "${user_group}"; \
    fi; \
    "$@" "${USERNAME}"; \
    echo "${USERNAME} ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

# Update apt-file cache
RUN apt-file update || true

# Switch to user
USER ${USERNAME}
WORKDIR /home/${USERNAME}

# Install uv
RUN if [ "${USE_UV}" = "true" ]; then \
        curl -LsSf https://astral.sh/uv/install.sh | sh; \
    fi

# Install Rust and Cargo
RUN if [ "${USE_RUST}" = "true" ]; then \
        curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y \
        && $HOME/.cargo/bin/cargo install ripgrep; \
    fi

# Install nvm and Node.js
RUN if [ "${USE_NPM}" = "true" ]; then \
        export HOME=/home/${USERNAME} NVM_DIR="$HOME/.nvm" \
        && curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh | bash \
        && [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh" \
        && nvm install 25; \
    fi

# Install Claude Code
RUN if [ "${USE_CLAUDE_CODE}" = "true" ]; then \
        curl -fsSL https://claude.ai/install.sh | bash; \
    fi

# Install OpenAI Codex (requires npm)
RUN if [ "${USE_CODEX}" = "true" ] && [ "${USE_NPM}" = "true" ]; then \
        export HOME=/home/${USERNAME} NVM_DIR="$HOME/.nvm" \
        && [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh" \
        && npm i -g @openai/codex; \
    fi

# Install mise
RUN if [ "${USE_MISE}" = "true" ]; then \
        curl https://mise.run | sh; \
    fi

# Install overmind
RUN if [ "${USE_OVERMIND}" = "true" ]; then \
        curl -fsSL https://github.com/DarthSim/overmind/releases/download/v2.5.1/overmind-v2.5.1-linux-arm64.gz | gunzip > ~/.local/bin/overmind \
        && chmod +x ~/.local/bin/overmind; \
    fi

# Install just
RUN if [ "${USE_JUST}" = "true" ]; then \
        curl --proto '=https' --tlsv1.2 -sSf https://just.systems/install.sh | bash -s -- --to ~/.local/bin; \
    fi

# Install chezmoi and apply dotfiles (if CHEZMOI_DOTFILES_REPO is set)
RUN if [ -n "${CHEZMOI_DOTFILES_REPO}" ]; then \
        sh -c "$(curl -fsLS get.chezmoi.io/lb)" \
        && .local/bin/chezmoi init ${CHEZMOI_DOTFILES_REPO} \
        && .local/bin/chezmoi apply; \
    fi

# Set default shell to zsh
ENV SHELL=/bin/zsh

CMD ["/bin/zsh"]
