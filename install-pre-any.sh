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
# ./install-pre-any.sh ios
# ./install-pre-any.sh macos
# ./install-pre-any.sh all

set -e

plat=$1

THIS_DIR=$(DIRNAME=$(dirname "$0"); cd "$DIRNAME"; pwd)
cd "$THIS_DIR"

function usage() {
    echo "=== useage ===================="
    echo "Download pre-compiled libs from github:"
    echo " $0 [ios,macos,all]"
    exit
}

if [[ "$plat" == 'ios' || "$plat" == 'macos' || "$plat" == 'all' ]]; then
    if [[ "$plat" == 'ios' || "$plat" == 'macos' ]]; then
        ./tools/main.sh "$plat"
    else
        ./tools/main.sh 'ios'
        ./tools/main.sh 'macos'
    fi
else
    usage
fi
