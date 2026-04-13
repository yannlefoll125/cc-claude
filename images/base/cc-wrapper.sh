#!/bin/bash
HOST_UID=$(stat -c "%u" /workspace)
HOST_GID=$(stat -c "%g" /workspace)

groupadd -g $HOST_GID hostgroup 2>/dev/null || true
useradd -u $HOST_UID -g $HOST_GID -m hostuser 2>/dev/null || true

[ -n "$GIT_USER_NAME" ]  && git config --global user.name  "$GIT_USER_NAME"
[ -n "$GIT_USER_EMAIL" ] && git config --global user.email "$GIT_USER_EMAIL"
git config --global --add safe.directory /workspace
clear
exec gosu hostuser claude "$@"
clear