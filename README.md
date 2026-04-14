# Claude Code Docker Environment

Run Anthropic's [Claude Code](https://github.com/anthropics/claude-code) CLI in an isolated Docker container.

## Prerequisites

- [Docker](https://docs.docker.com/get-docker/)
- [Docker Compose](https://docs.docker.com/compose/install/)

## Project Structure

```
.
├── .env.example             # Template for optional git identity config
├── docker-compose.yml       # Compose service definitions
└── images/
    ├── base/
    │   ├── cc-wrapper.sh        # Entrypoint (root phase): matches host UID/GID, re-execs via gosu
    │   ├── run-as-hostuser.sh   # User phase: applies git config, clears terminal, runs claude
    │   └── Dockerfile           # Debian Bookworm slim + Claude Code CLI (cc-base)
    └── vue3/
        └── Dockerfile           # cc-base + Yarn (cc-vue3)
```

## Usage

**1. Build the images:**

```bash
docker-compose build
```

**2. Run Claude Code:**

```bash
docker-compose run cc
```

This mounts the current directory into `/workspace` inside the container, your `~/.claude` config directory into `/home/hostuser/.claude`, and `~/.claude.json` into `/home/hostuser/.claude.json`, so your Claude settings and credentials persist across runs.

The startup runs in two phases. `cc-wrapper.sh` (root) creates a `hostuser` account matching your host UID/GID and re-execs via `gosu`. `run-as-hostuser.sh` (hostuser) then applies optional git identity env vars, marks `/workspace` as a git safe directory, clears the terminal, and runs `claude`.

## Images

| Image | Description |
|-------|-------------|
| `cc-base` | Debian Bookworm slim + Claude Code CLI (installed via official install script). General-purpose starting point. |
| `cc-vue3` | Extends `cc-base` with Yarn (via corepack). Use for Vue 3 projects. |

To use the Vue 3 image, update `docker-compose.yml` to reference `cc-vue3`, or run the container directly:

```bash
docker run -it --rm \
  -v "$PWD":/workspace \
  -v ~/.claude:/home/hostuser/.claude \
  -v ~/.claude.json:/home/hostuser/.claude.json \
  cc-vue3
```

## Using cc-base in Another Project

The `docker-compose.yml` in this repo shows the recommended pattern for integrating `cc-base` into any project. Copy it into your project root and adjust as needed:

```yaml
services:
  cc:
    image: cc-base  # or cc-vue3 for Vue 3 projects
    stdin_open: true
    tty: true
    environment:
      GIT_USER_NAME: ${GIT_USER_NAME:-}
      GIT_USER_EMAIL: ${GIT_USER_EMAIL:-}
    volumes:
      - .:/workspace
      - ~/.claude:/home/hostuser/.claude
      - ~/.claude.json:/home/hostuser/.claude.json
```

Then from your project root:

```bash
# Build cc-base first (only needed once)
docker-compose -f /path/to/this/repo/docker-compose.yml build

# Start Claude Code in your project
docker-compose run cc
```

The volume mounts are the key pieces:

| Mount | Purpose |
|-------|---------|
| `.:/workspace` | Makes your project files available inside the container |
| `~/.claude:/home/hostuser/.claude` | Persists your Claude credentials and settings across runs |
| `~/.claude.json:/home/hostuser/.claude.json` | Persists Claude's top-level auth/config state across runs |

## Configuration

Claude Code permissions are configured in `.claude/settings.local.json`. Edit this file to adjust which tools and operations Claude is allowed to perform inside the container.

### Git identity (optional)

By default, the container has no git user identity. To set one, copy `.env.example` to `.env` and fill in your details:

```bash
cp .env.example .env
```

```ini
GIT_USER_NAME=Your Name
GIT_USER_EMAIL=you@example.com
```

`.env` is gitignored, so each developer maintains their own without affecting the shared config. The values are picked up by `docker-compose.yml` and applied via `git config --global` at container startup.
