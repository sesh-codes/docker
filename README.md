<p align="center">
  <a href="https://sesh.codes"><img src="assets/sesh-icon.png" width="96" height="96" alt="Sesh"></a>
</p>

<h1 align="center">Sesh in Docker</h1>

<p align="center">
  Run coding agents in a container, and drive them from Sesh on your Mac, iPhone, iPad, Android phone or Linux computer.<br>
  <a href="https://sesh.codes">sesh.codes</a> · <a href="https://sesh.codes/docs/docker/">Full guide</a> · <a href="https://github.com/sesh-codes/docker/pkgs/container/sesh">Images</a>
</p>

---

[Sesh](https://sesh.codes) is remote control for every coding agent. Agents run on computers you own; Sesh lets you start them, answer them and ship what they made from any device. These images turn a container into one of those computers: on a home server, a NAS, a cloud server or your own machine. The agents can only change what's inside the container, and you can throw it away and start again.

## Quick start

```sh
docker run -d --name sesh --hostname my-sesh --restart unless-stopped \
  --security-opt seccomp=unconfined \
  -p 4777:4777/udp \
  -v sesh-home:/home/sesh \
  ghcr.io/sesh-codes/sesh:claude

docker exec -it sesh sesh pair
```

`sesh pair` prints the machine's ID and a pairing code. In Sesh on your Mac, open **Settings › Machines › Add Machine…** and enter them, or scan the QR code from your iPhone or iPad. Then sign in to the agent from the machine's **Details…**.

## Images

Every image has Sesh, git, the GitHub CLI, curl and ssh, for `linux/amd64` and `linux/arm64`.

| Image | Agent |
|---|---|
| `ghcr.io/sesh-codes/sesh:claude` | [Claude Code](https://www.anthropic.com/claude-code) |
| `ghcr.io/sesh-codes/sesh:codex` | [Codex](https://openai.com/codex/) |
| `ghcr.io/sesh-codes/sesh:gemini` | [Gemini CLI](https://github.com/google-gemini/gemini-cli) |
| `ghcr.io/sesh-codes/sesh:cursor` | [Cursor](https://cursor.com/cli) |
| `ghcr.io/sesh-codes/sesh:opencode` | [OpenCode](https://opencode.ai) (works without an account on its free models) |
| `ghcr.io/sesh-codes/sesh:all` | All five |
| `ghcr.io/sesh-codes/sesh:latest` | None yet: click **Get** next to an agent in Sesh |

Each also comes pinned to a Sesh release, such as `ghcr.io/sesh-codes/sesh:0.47.0-claude`.

## Docker Compose

```yaml
services:
  sesh:
    image: ghcr.io/sesh-codes/sesh:claude
    hostname: my-sesh
    restart: unless-stopped
    security_opt:
      - seccomp=unconfined
    ports:
      - "4777:4777/udp"
    volumes:
      - sesh-home:/home/sesh

volumes:
  sesh-home:
```

Then `docker compose up -d` and `docker compose exec sesh sesh pair`.

## Good to know

- **Keep the volume.** Projects (`~/code`), sessions, pairings and sign-ins are all in `/home/sesh`. Without a volume they're lost when the container is removed.
- **`--security-opt seccomp=unconfined`** lets Sesh sandbox Autonomous sessions inside the container. Leave it out and they run unsandboxed (and say so), with the container as the only boundary.
- **The UDP port is optional.** Sesh reaches the container from any network without it, end-to-end encrypted. Publishing it lets devices on the same network connect directly.
- **Updates.** Sesh updates itself in the container. Pull the image again for newer agents: `docker compose pull && docker compose up -d`.
- **Your tools.** The images run as `sesh` (uid 1000), not root. To add compilers or runtimes, build on top:

  ```dockerfile
  FROM ghcr.io/sesh-codes/sesh:claude
  USER root
  RUN apt-get update && apt-get install -y --no-install-recommends build-essential python3 \
   && rm -rf /var/lib/apt/lists/*
  USER sesh
  ```

The [full guide](https://sesh.codes/docs/docker/) covers signing in, API keys, GitHub, backups, running more than one container, and what to do if something's wrong.

## This repository

`Dockerfile` builds every image (one target per tag), and the Publish workflow builds and pushes them for each Sesh release. Sesh's source isn't published here. To build one yourself:

```sh
docker build --target claude -t sesh:claude .
```

Questions, ideas and bug reports go on the [Sesh feedback board](https://userinput.app/s/did:plc:hi34a5c6rackxgvemkdbdrjy/3mwytwlmv2p2t).
