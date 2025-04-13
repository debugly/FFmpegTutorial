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

set -e

THIS_DIR=$(DIRNAME=$(dirname "$0"); cd "$DIRNAME"; pwd)
cd "$THIS_DIR"

echo "=== [$0] check env begin==="
env_assert "MR_WORKSPACE"
env_assert "MR_DOWNLOAD_URL"
env_assert "MR_DOWNLOAD_ONAME"
env_assert "MR_UNCOMPRESS_DIR"
echo "===check env end==="

function download() {
    local dst="$1"
    echo "---[download]-----------------"
    echo "$MR_DOWNLOAD_URL"
    
    mkdir -p $(dirname "$dst")
    local tname="${dst}.tmp"
    curl -fL --retry 3 --retry-delay 5 --retry-max-time 30 "$MR_DOWNLOAD_URL" -o "$tname"
    
    if [[ $? -eq 0 ]];then
        mv "$tname" "${dst}"
    else
        rm -f "$tname"
    fi
}

function extract(){
    local dst="$1"
    if [[ -f "$dst" ]];then
        mkdir -p "$MR_UNCOMPRESS_DIR"
        unzip -oq "$dst" -d "$MR_UNCOMPRESS_DIR"
        echo "extract zip file"
    else
        echo "you need download ${MR_DOWNLOAD_ONAME} firstly."
        exit 1
    fi
}

function install() {
    local dst="${MR_WORKSPACE}/pre/${MR_DOWNLOAD_ONAME}"
    if [[ -f "$dst" ]];then
        echo "$dst already exist,skip download."
    else
        download "$dst"
    fi
    extract "$dst"
}

install
