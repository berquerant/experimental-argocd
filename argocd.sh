#!/bin/bash

set -e

readonly server="argocd-server:443"

get_initial_password() {
  kubectl -n argocd get secret/argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
}

cli() {
  echo >&2 "ARGOCD cli: $*"
  kubectl -n argocd exec deploy/argocd-server -- argocd "$@"
}

login() {
  cli login "$server" --insecure --username admin --password "$(get_initial_password)"
}

run() {
  login
  cli "$@"
}

case "$1" in
  init) get_initial_password ;;
  *) run "$@" ;;
esac
