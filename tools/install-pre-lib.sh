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

function install_plat() {
    local join=""
    
    if [[ "$1" ]];then
        join="-$1"
    fi
    
    # you can export MR_DOWNLOAD_WEBSERVER use your mirror
    if [[ "$MR_DOWNLOAD_BASEURL" != "" ]] ;then
        base_url="$MR_DOWNLOAD_BASEURL"
    else
        base_url=https://github.com/debugly/MRFFToolChainBuildShell/releases/download/
    fi
    export MR_DOWNLOAD_ONAME="$TAG/$LIB_NAME-$MR_PLAT-universal${join}-$VER.zip"
    export MR_DOWNLOAD_URL="${base_url}${MR_DOWNLOAD_ONAME}"
    export MR_UNCOMPRESS_DIR="$MR_WORKSPACE/product/$MR_PLAT/universal${join}"
    
    ./download-uncompress.sh
}

if [[ "$MR_PLAT" == 'ios' || "$MR_PLAT" == 'tvos' ]];then
    install_plat
    install_plat "simulator"
else
    install_plat
fi