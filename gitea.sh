#!/bin/bash

set -e

d="$(cd "$(dirname "$0")" || exit 1; pwd)"

readonly key="${d}/tmp/admin.key"
readonly pubkey="${key}.pub"

__tea() {
  echo >&2 "GITEA tea: $*"
  kubectl -n gitea exec deploy/tea -- "$@"
}

__tea_run() {
  __tea tea "$@"
}

pod() {
  kubectl get pod -n gitea -l app=tea -o=jsonpath='{.items[0].metadata.name}'
}

__ssh() {
  ssh -o StrictHostKeyChecking=no -p 2222 -i "${key}" git@localhost "$@"
}

__git() {
  git -c core.sshCommand="ssh -o StrictHostKeyChecking=no -p 2222 -i ${key}" "$@"
}

case "$1" in
  pod) pod ;;
  run)
    shift
    __tea "$@"
    ;;
  tea)
    shift
    __tea_run "$@"
    ;;
  ssh)
    shift
    __ssh "$@"
    ;;
  git)
    shift
    __git "$@"
    ;;
esac
