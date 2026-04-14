#!/bin/bash
if [ -z "$PROJECT_DIR" ] || [ ! -d "$PROJECT_DIR" ]; then
  echo "ERROR: PROJECT_DIR is not set or is not a directory ('$PROJECT_DIR')." >&2
  echo "       Set PROJECT_DIR to the project path (see README)." >&2
  exit 1
fi

HOST_UID=$(stat -c "%u" "$PROJECT_DIR")
HOST_GID=$(stat -c "%g" "$PROJECT_DIR")

groupadd -g $HOST_GID hostgroup 2>/dev/null || true
useradd -u $HOST_UID -g $HOST_GID -m hostuser 2>/dev/null || true
chown $HOST_UID:$HOST_GID /home/hostuser

[ -n "$GIT_USER_NAME" ]  && export GIT_USER_NAME
[ -n "$GIT_USER_EMAIL" ] && export GIT_USER_EMAIL

exec gosu hostuser /run-as-hostuser.sh "$@"