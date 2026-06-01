#!/bin/bash

set -e

readonly server="argocd-server:443"

# Change the initial admin password to admin.
# https://argo-cd.readthedocs.io/en/release-2.2/faq/#i-forgot-the-admin-password-how-do-i-reset-it
change_initial_password() {
  kubectl -n argocd patch secret argocd-secret -p '{"stringData": {"admin.password": "$2a$10$stx01PhgP9tFbwEzQG1UpOrN81AOvSd3ENSF4zUMm7bOmI/yY4De6", "admin.passwordMtime": "'$(date +%FT%T%Z)'"}}'
}

cli() {
  echo >&2 "ARGOCD cli: $*"
  kubectl -n argocd exec deploy/argocd-server -- argocd "$@"
}

login() {
  cli login "$server" --insecure --username admin --password admin
}

run() {
  login
  cli "$@"
}

case "$1" in
  init) change_initial_password ;;
  *) run "$@" ;;
esac
