#!/bin/bash
HOST_UID=$(stat -c "%u" /workspace)
HOST_GID=$(stat -c "%g" /workspace)

groupadd -g $HOST_GID hostgroup 2>/dev/null || true
useradd -u $HOST_UID -g $HOST_GID -m hostuser 2>/dev/null || true
chown $HOST_UID:$HOST_GID /home/hostuser

[ -n "$GIT_USER_NAME" ]  && export GIT_USER_NAME
[ -n "$GIT_USER_EMAIL" ] && export GIT_USER_EMAIL

exec gosu hostuser /run-as-hostuser.sh "$@"