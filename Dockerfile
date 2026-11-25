# syntax=docker/dockerfile:1
# Sesh's images, ghcr.io/sesh-codes/sesh: a Sesh host in a container, from the release's
# static Linux binaries. One target per tag: `base` (latest; agents come from Get in the
# app), one per agent, and `all`. Guide: https://sesh.codes/docs/docker/
#
#   docker build --target claude -t sesh:claude .
#
# The binaries come from the `dist` stage: a release (SESH_RELEASES_URL, default the
# latest), downloaded and checked by that release's own install.sh. To try other
# binaries, pass a `dist` build context instead (`--build-context dist=<folder>`, with
# amd64/ and arm64/ each holding seshd and sesh).

ARG SESH_RELEASES_URL=https://sesh.codes/releases/latest
ARG NODE_MAJOR=22

FROM ubuntu:24.04 AS dist
ARG TARGETARCH
ARG SESH_RELEASES_URL
RUN apt-get update && apt-get install -y --no-install-recommends ca-certificates curl \
 && rm -rf /var/lib/apt/lists/*
RUN curl -fsSL "$SESH_RELEASES_URL/install.sh" \
  | SESH_RELEASES_URL="$SESH_RELEASES_URL" SESH_INSTALL_DIR="/$TARGETARCH" SESH_NO_SERVICE=1 sh

# seshd, git and the GitHub CLI, running as `sesh` (uid 1000, the usual first user, so a
# bind-mounted folder from the host is writable). Everything installed lives in /opt/sesh,
# owned by `sesh`, so Update in the app (and Claude Code's own updates) can write there;
# /home/sesh is left for what's worth keeping: projects, sessions, pairings and logins.
FROM ubuntu:24.04 AS base
ARG TARGETARCH
RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      bubblewrap ca-certificates curl git gnupg less openssh-client tini unzip xz-utils \
 && curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg -o /usr/share/keyrings/githubcli-archive-keyring.gpg \
 && echo "deb [signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" > /etc/apt/sources.list.d/github-cli.list \
 && apt-get update && apt-get install -y --no-install-recommends gh \
 && rm -rf /var/lib/apt/lists/* \
 && userdel --remove ubuntu \
 && useradd --create-home --uid 1000 --shell /bin/bash sesh \
 && mkdir -p /opt/sesh/bin && chown -R sesh:sesh /opt/sesh
COPY --from=dist --chown=sesh:sesh /${TARGETARCH}/seshd /${TARGETARCH}/sesh /opt/sesh/bin/
USER sesh
WORKDIR /home/sesh
# SESH_SERVICE: the container is seshd's service, so it updates itself (Update
# Automatically) and restarts in place. NPM_CONFIG_PREFIX: `npm install -g` goes to
# /opt/sesh/npm, which `sesh` can write.
ENV PATH=/opt/sesh/bin:/opt/sesh/npm/bin:$PATH \
    NPM_CONFIG_PREFIX=/opt/sesh/npm \
    SHELL=/bin/bash \
    SESH_PORT=4777 \
    SESH_SERVICE=1
RUN git config --global init.defaultBranch main \
 && gh auth setup-git 2>/dev/null || true
# No VOLUME: each `docker run` would leave an anonymous one. Mount one on /home/sesh.
EXPOSE 4777/udp
# tini reaps what agents leave behind and passes Docker's stop signal to seshd.
ENTRYPOINT ["/usr/bin/tini", "--"]
CMD ["seshd"]

# Node, for the agents that run on it.
FROM base AS node
ARG NODE_MAJOR
USER root
RUN curl -fsSL https://deb.nodesource.com/setup_${NODE_MAJOR}.x | bash - \
 && apt-get install -y --no-install-recommends nodejs \
 && rm -rf /var/lib/apt/lists/*
USER sesh

# The ACP adapters Sesh launches through npx are fetched by the first session (seconds).
FROM node AS claude
RUN npm install -g @anthropic-ai/claude-code && npm cache clean --force

FROM node AS codex
RUN npm install -g @openai/codex && npm cache clean --force

FROM node AS gemini
RUN npm install -g @google/gemini-cli && npm cache clean --force

# Cursor's and OpenCode's installers write into $HOME; given a home of their own under
# /opt/sesh, they stay out of the volume.
FROM base AS cursor
RUN HOME=/opt/sesh/cursor bash -c "curl -fsSL https://cursor.com/install | bash" \
 && ln -s "$(readlink /opt/sesh/cursor/.local/bin/cursor-agent)" /opt/sesh/bin/cursor-agent \
 && cursor-agent --version

FROM base AS opencode
RUN HOME=/opt/sesh/opencode bash -c "curl -fsSL https://opencode.ai/install | bash -s -- --no-modify-path" \
 && ln -s /opt/sesh/opencode/.opencode/bin/opencode /opt/sesh/bin/opencode \
 && opencode --version

FROM node AS all
COPY --from=claude --chown=sesh:sesh /opt/sesh/npm /opt/sesh/npm
COPY --from=codex --chown=sesh:sesh /opt/sesh/npm /opt/sesh/npm
COPY --from=gemini --chown=sesh:sesh /opt/sesh/npm /opt/sesh/npm
COPY --from=cursor --chown=sesh:sesh /opt/sesh/cursor /opt/sesh/cursor
COPY --from=opencode --chown=sesh:sesh /opt/sesh/opencode /opt/sesh/opencode
RUN ln -s "$(readlink /opt/sesh/cursor/.local/bin/cursor-agent)" /opt/sesh/bin/cursor-agent \
 && ln -s /opt/sesh/opencode/.opencode/bin/opencode /opt/sesh/bin/opencode \
 && claude --version && codex --version && gemini --version && cursor-agent --version && opencode --version

# The default target: `sesh/sesh:latest`.
FROM base
