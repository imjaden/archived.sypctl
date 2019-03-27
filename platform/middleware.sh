#!/usr/bin/env bash

command -v sypctl > /dev/null 2>&1 || export PATH="/usr/local/bin:$PATH"

test -f .env-files || touch .env-files
while read filepath; do
    source "${filepath}" > /dev/null 2>&1
    cd ${SYPCTL_HOME}
done < .env-files

cd ${SYPCTL_HOME}
source "platform/$(uname -s)/common.sh"