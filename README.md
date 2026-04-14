# Claude Code Docker Environment

Run Anthropic's [Claude Code](https://github.com/anthropics/claude-code) CLI in an isolated Docker container, one container per project.

## What this is (and isn't) for

The goal is **project isolation**, not network isolation from Anthropic.

Claude Code is a capable agent with broad filesystem and shell access. Run directly on a developer laptop, it can in principle read anything the logged-in user can read: other repositories, SSH keys, browser profiles, shell history, `~/.aws`, other projects' `.env` files, and so on. Even with good intentions, a single misinterpreted prompt — or a prompt-injection payload hidden in a dependency, issue, or web page — can cause the agent to pull context from one project into another.

Running Claude inside a per-project container fixes that. The container only sees:

- `/workspace` — the current project directory
- `/home/hostuser/.claude` and `/home/hostuser/.claude.json` — your Claude auth/settings

It does **not** see other repos on your machine, your home directory, SSH keys, or any sibling project. A prompt injection inside project A cannot exfiltrate code from project B, because project B isn't mounted.

What this does **not** do:

- It does not prevent code from being sent to Anthropic's API. That is inherent to using Claude Code — your prompts and file contents are sent to Anthropic as part of normal operation. If you don't want code leaving your machine at all, don't run Claude Code on it.
- It does not sandbox network access. The container can reach the internet like any other process.

Think of it as a seatbelt against *cross-project* leakage and agent-mediated accidents on your own filesystem, not as a confidentiality boundary against Anthropic.

## Prerequisites

- [Docker](https://docs.docker.com/get-docker/)
- [Docker Compose](https://docs.docker.com/compose/install/)

## Scripts

### `build.sh`

Builds the `cc-*` Docker images in dependency order.

```bash
./build.sh              # build every discovered image
./build.sh vue3         # build cc-vue3 and its transitive dependencies only
```

Images are auto-discovered from `images/*/Dockerfile`. Dependencies are inferred by scanning each Dockerfile for `FROM cc-<name>` and `COPY --from=cc-<name>` directives, then a topological sort ensures each image is built after anything it depends on. Dependency cycles are detected and reported as errors.

Adding a new image is just: create `images/<name>/Dockerfile` — no edits to `build.sh` required.

### Shell completion

Add one line to your `~/.bashrc` (use the actual path where you cloned this repo):

```bash
source /path/to/cc-docker/completions/build.bash
```

This gives `./build.sh <TAB>` completion against the live list of images. The image list is read at completion time, so adding or removing an image directory is reflected immediately — no re-sourcing needed.

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

This mounts your project files, Claude credentials, and auth state into the container. See [The cc-base environment](#the-cc-base-environment) for how ownership and credentials work.

## Images

| Image | Description |
|-------|-------------|
| `cc-base` | Debian Bookworm slim + Claude Code CLI (installed via official install script). General-purpose starting point. |
| `cc-vue3` | Extends `cc-base` with Yarn (via corepack). Use for Vue 3 projects. |

## The cc-base environment

`cc-base` is a Debian Bookworm slim image with the Claude Code CLI pre-installed. It is designed to be a general-purpose starting point that other images (like `cc-vue3`) extend by adding project-specific tooling.

### The `hostuser` model

The defining feature of `cc-base` is that it runs Claude Code as a user whose UID and GID match yours on the host. At startup, the entrypoint reads the UID/GID of the `/workspace` mount point:

```bash
HOST_UID=$(stat -c "%u" /workspace)
HOST_GID=$(stat -c "%g" /workspace)
```

It then creates a `hostgroup`/`hostuser` pair with those IDs and drops privileges to that user via [gosu](https://packages.debian.org/bookworm/gosu) before running `claude`. The result: any file Claude creates inside `/workspace` is owned by you on the host — no `root`-owned artifacts, no `chown` cleanup after the container exits.

The same ownership logic applies to the config mounts. `~/.claude` and `~/.claude.json` are mounted into `/home/hostuser/.claude` and `/home/hostuser/.claude.json`, so credentials and settings are read and written with your UID — they stay in sync with your host login without any permission tricks.

### The two-phase entrypoint

Startup is split across two scripts because privilege drop requires root:

| Phase | Script | Runs as | What it does |
|-------|--------|---------|--------------|
| 1 | `cc-wrapper.sh` | root | Reads host UID/GID from `/workspace`, creates `hostgroup`/`hostuser`, `chown`s the home dir, re-execs via `gosu hostuser` |
| 2 | `run-as-hostuser.sh` | hostuser | Applies `GIT_USER_NAME`/`GIT_USER_EMAIL` if set, marks `/workspace` as a git safe directory, clears the terminal, runs `claude` |

### Extending cc-base

When building a child image, only add tooling — do not create a fixed user or set a `USER` directive. The UID match happens at runtime from the `/workspace` mount, so baking in a user would break the ownership alignment. `cc-vue3` is the canonical example: it just adds Yarn via corepack on top of `cc-base` and leaves the entrypoint untouched.

---

To use the Vue 3 image, update `docker-compose.yml` to reference `cc-vue3`, or run the container directly:

```bash
docker run -it --rm \
  -v "$PWD":/workspace \
  -v ~/.claude:/home/hostuser/.claude \
  -v ~/.claude.json:/home/hostuser/.claude.json \
  cc-vue3
```

## Using cc-claude in another project

The `docker-compose.yml` in this repo shows the recommended pattern for integrating `cc-base` into any project. Copy it into your project root and adjust as needed:

```yaml
services:
  cc:
    image: cc-base  # or cc-vue3 for Vue 3 projects, or any other extension of cc-base
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
| `.:/workspace` | Makes your project files available inside the container; also the source of the host UID/GID used to create `hostuser` |
| `~/.claude:/home/hostuser/.claude` | Persists Claude credentials and settings; mounted at the `hostuser` home path so ownership matches your host login |
| `~/.claude.json:/home/hostuser/.claude.json` | Persists Claude's top-level auth/config state; same ownership rationale |

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
