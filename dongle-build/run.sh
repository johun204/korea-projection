#!/bin/bash
# run a kbuild/*.sh step inside the build container: run.sh <script> [VAR=value ...]
s=$1; shift
e=(); for a in "$@"; do e+=(-e "$a"); done
exec docker run --rm --platform linux/amd64 -e KDIR=/k/linux2 "${e[@]}" -v kbuild:/k -v /Library/Claude/K8-Korea-Projection:/w kbuild bash /w/kbuild/$s
