#! /usr/bin/env bash
#
# Copyright (C) 2021 Matt Reach<qianlongxu@gmail.com>

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
#

set -e

# 当前脚本所在目录
THIS_DIR=$(DIRNAME=$(dirname "$0"); cd "$DIRNAME"; pwd)
cd "$THIS_DIR"

function env_assert()
{
    name="$1"
    value=$(eval echo "\$$name")
    if [[ "x$value" == "x" ]]; then
        echo "$name is nil,eg: export $name=xx" >&2
        exit 1
    else
        echo "$name : [${value}]" >&2
    fi
}

export -f env_assert

function parse_lib_config() {
    
    local t=$(echo "PRE_COMPILE_TAG_$MR_PLAT" | tr '[:lower:]' '[:upper:]')
    local vt=$(eval echo "\$$t")

    if test -z $vt ;then
        TAG="$PRE_COMPILE_TAG"
    else
        TAG="$vt"
    fi
    
    if test -z $TAG ;then
        echo "tag can't be nil"
        exit
    fi
    
    # opus-1.3.1-231124151836
    # yuv-stable-eb6e7bb-250225223408
    LIB_NAME=$(echo $TAG | awk -F - '{print $1}')
    local prefix="${LIB_NAME}-"
    local suffix=$(echo $TAG | awk -F - '{printf "-%s", $NF}')
    # 去掉前缀
    local temp=${TAG#$prefix}
    # 去掉后缀
    VER=${temp%$suffix}
    
    echo "TAG:$TAG"
    echo "VER:$VER"

    export VER
    export TAG
    export LIB_NAME
}

export MR_PLAT=$1
export MR_WORKSPACE=$PWD/../build

echo "===[install $MR_PLAT fftutorial]===================="
source "./fftutorial.sh"
parse_lib_config
./install-pre-lib.sh
mv $MR_WORKSPACE/product/$MR_PLAT/universal/fftutorial $MR_WORKSPACE/product/$MR_PLAT/universal/ffmpeg
echo "===================================="