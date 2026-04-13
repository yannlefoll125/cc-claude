# Claude Code Docker Environment

Run Anthropic's [Claude Code](https://github.com/anthropics/claude-code) CLI in an isolated Docker container.

## Prerequisites

- [Docker](https://docs.docker.com/get-docker/)
- [Docker Compose](https://docs.docker.com/compose/install/)

## Project Structure

```
.
├── docker-compose.yml       # Compose service definitions
└── images/
    ├── base/
    │   └── Dockerfile       # Debian Bookworm slim + Claude Code CLI (cc-base)
    └── vue3/
        └── Dockerfile       # cc-base + Yarn (cc-vue3)
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

This mounts the current directory into `/workspace` inside the container and your `~/.claude` config directory into `/root/.claude`, so your Claude settings and credentials persist across runs.

## Images

| Image | Description |
|-------|-------------|
| `cc-base` | Debian Bookworm slim + Claude Code CLI (installed via official install script). General-purpose starting point. |
| `cc-vue3` | Extends `cc-base` with Yarn (via corepack). Use for Vue 3 projects. |

To use the Vue 3 image, update `docker-compose.yml` to reference `cc-vue3`, or run the container directly:

```bash
docker run -it --rm -v "$PWD":/workspace -v ~/.claude:/root/.claude cc-vue3
```

## Using cc-base in Another Project

The `docker-compose.yml` in this repo shows the recommended pattern for integrating `cc-base` into any project. Copy it into your project root and adjust as needed:

```yaml
services:
  cc:
    image: cc-base  # or cc-vue3 for Vue 3 projects
    stdin_open: true
    tty: true
    volumes:
      - .:/workspace
      - ~/.claude:/root/.claude
```

Then from your project root:

```bash
# Build cc-base first (only needed once)
docker-compose -f /path/to/this/repo/docker-compose.yml build

# Start Claude Code in your project
docker-compose run cc
```

The two volume mounts are the key pieces:

| Mount | Purpose |
|-------|---------|
| `.:/workspace` | Makes your project files available inside the container |
| `~/.claude:/root/.claude` | Persists your Claude credentials and settings across runs |

## Configuration

Claude Code permissions are configured in `.claude/settings.local.json`. Edit this file to adjust which tools and operations Claude is allowed to perform inside the container.
