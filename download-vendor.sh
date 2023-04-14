#! /usr/bin/env bash
#
# Copyright (C) 2022 Matt Reach<qianlongxu@gmail.com>

# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

VERSION=20230304181936

set -e

EDITION=$1
PLAT=$2
VER=$3

if test -z $PLAT ;then
    PLAT='all'
fi

cd $(dirname "$0")
c_dir="$PWD"

function usage() {
    echo "=== useage ===================="
    echo "Download precompiled ijk or github edition libs from github,The usage is as follows:"
    echo "$0 ijk|github [ios|macos|all] [<release tag>]"
}

function download() {
    local plat=$1
    echo "===[download $plat $EDITION $VER]===================="
    mkdir -p vendor
    cd vendor
    local fname="$plat-universal-$VER-$EDITION.zip"
    local url="https://github.com/debugly/MRFFToolChainBuildShell/releases/download/$VER-$EDITION/$fname"
    echo "$url"
    curl -C - -L "$url" -o "$fname"

    local dir="product/$plat/universal"
    mkdir -p "$dir"
    unzip -oq $fname -d "$dir"
    tree -L 2 "$dir"
    echo "===================================="
    cd - >/dev/null
}

if [[ "$EDITION" != 'ijk' && "$EDITION" != 'github' ]]; then
    echo 'wrong edition,use ijk or github!'
    usage
    exit
fi

if [[ "$PLAT" != 'ios' && "$PLAT" != 'macos' && "$PLAT" != 'all' ]]; then
    echo 'wrong plat,use ios or macos or all!'
    usage
    exit
fi

if test -z $VER ;then
    #VER=$(git describe --abbrev=0 --tag | awk -F - '{printf "%s-%s",$1,$2}')
    VER="$VERSION"
    echo "use the default version:${VER}"
fi

if [[ "$PLAT" == 'ios' || "$PLAT" == 'macos' ]]; then
    download $PLAT
elif [[ "$PLAT" == 'all' ]]; then
    plats="ios macos"
    for plat in $plats; do
        download $plat
    done
else
    usage
fi