#!/bin/sh
set -eu
if [ "${1:-}" = --help ] && [ "$#" -eq 1 ]; then
    printf '%s\n' 'Usage: sh install.sh' 'Download and install the current Crown binary release.'
    exit 0
fi
if [ "$#" -ne 0 ]; then
    printf '%s\n' 'error: unexpected argument; use bootstrap/install --source in a checkout for source builds' >&2
    exit 1
fi
stage=$(mktemp -d "${TMPDIR:-/tmp}/crown-install-XXXXXX")
trap 'rm -rf "$stage"' EXIT HUP INT TERM
curl --fail --location --retry 3 --connect-timeout 20 --max-time 300 --proto '=https' --proto-redir '=https' --output "$stage/installer.tar.gz" https://github.com/MashDevel/crown-lang/archive/refs/heads/main.tar.gz
tar -xzf "$stage/installer.tar.gz" -C "$stage"
sh "$stage/crown-lang-main/bootstrap/install"
