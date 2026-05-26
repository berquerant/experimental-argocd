#!/bin/sh

log() {
  echo >&2 "$*"
}

create_admin() {
  log "Create admin user"
  if su-exec git /usr/local/bin/gitea admin user list | grep -q "$GITEA_ADMIN_USERNAME" ; then
    log "Admin user already exist"
    return
  fi
  su-exec git /usr/local/bin/gitea admin user create \
          --username "$GITEA_ADMIN_USERNAME" \
          --password "$GITEA_ADMIN_PASSWORD" \
          --email "$GITEA_ADMIN_EMAIL" \
          --admin \
          --must-change-password=false
  log "Admin user created"
}

set -e
sleep 10
create_admin
