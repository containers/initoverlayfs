#!/bin/bash -e
# SPDX-License-Identifier: LGPL-2.1-or-later

# Current version of initoverlayfs
VERSION=0.991
# Specify if build is a official release or a snapshot build
IS_RELEASE=false
# Used for official releases. Increment if necessary
RELEASE="1"

function short(){
    echo ${VERSION}
}

function long(){
    echo "$(short)-$(release)"
}

function release(){
    # Package release

    if [ $IS_RELEASE = false ]; then
        # Used for nightly builds
        RELEASE="0.$(date +%04Y%02m%02d%02H%02M).git$(git rev-parse --short ${GITHUB_SHA:-HEAD})"
    fi
    echo $RELEASE
}

[ -z $1 ] && short || $1
