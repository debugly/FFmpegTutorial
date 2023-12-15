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
# ./install-pre-any.sh all
# ./install-pre-any.sh ios 'libyuv openssl opus bluray dav1d'
# ./install-pre-any.sh macos 'openssl'
# ./install-pre-any.sh macos 'openssl ffmpeg'


#----------------------------------------------------------
# 当发布新版本库时，修改对应的 TAG 值
#----------------------------------------------------------
LIBYUV_TAG='libyuv-main-231127113441'
OPUS_TAG='opus-1.4-231127183709'
MAC_BLURAY_TAG='bluray-1.3.4-231127183939'
DAV1D_TAG='dav1d-1.3.0-231127183948'
OPENSSL_TAG='openssl-1.1.1w-231127183927'
FFMPEG_TAG='ffmpeg-5.1.4-231128092946'
#----------------------------------------------------------

set -e

PLAT=$1
LIBS=$2

THIS_DIR=$(DIRNAME=$(dirname "$0"); cd "$DIRNAME"; pwd)
cd "$THIS_DIR"

function install_lib ()
{
    local plat=$1
    
    if [[ "$plat" == 'ios' || "$plat" == 'macos' ]]; then
        ./tools/install-pre-lib.sh "$plat" "$TAG"
    else
        ./tools/install-pre-lib.sh 'ios' "$TAG"
        ./tools/install-pre-lib.sh 'macos' "$TAG"
    fi
}

function usage() {
    echo "=== useage ===================="
    echo "Download pre-compiled libs from github:"
    echo " $0 [ios,macos,all] [all|ffmpeg|libyuv|openssl|opus|bluray|dav1d]"
    exit
}

if [[ -z "$LIBS" || "$LIBS" == "all" ]]; then
    if [[ "$PLAT" == 'macos' ]];then
        LIBS="bluray dav1d openssl opus ffmpeg"
    elif [[ "$PLAT" == 'ios' ]];then
        LIBS="dav1d openssl opus ffmpeg"
    else
        useage
    fi
fi

if [[ "$PLAT" == 'ios' || "$PLAT" == 'macos' || "$PLAT" == 'all' ]]; then
    for lib in $LIBS
    do
        plat=$PLAT
        TAG=
        if [[ $lib == 'bluray' ]];then
            if [[ $plat == 'macos' || $plat == 'all' ]];then
                plat='macos'
            else
                echo "===[bluray] not support iOS platform, just skip it.===================="
                continue
            fi
        fi
        
        echo "===[install pre-compile $lib]===================="
        
        case $lib in
            'ffmpeg')
                TAG=$FFMPEG_TAG
            ;;
            'libyuv')
                TAG=$LIBYUV_TAG
            ;;
            'openssl')
                TAG=$OPENSSL_TAG
            ;;
            'opus')
                TAG=$OPUS_TAG
            ;;
            'bluray')
                TAG=$MAC_BLURAY_TAG
            ;;
            'dav1d')
                TAG=$DAV1D_TAG
            ;;
            *)
                echo "wrong lib name:$lib"
                usage
            ;;
        esac
        
        if [[ -z "$TAG" ]]; then
            echo "== $lib tag is empty,just skip it."
        else
            echo "== $plat $lib -> $TAG"
            install_lib $plat
        fi
        echo "===================================="
    done

    echo "[$LIBS] successfully installed!"
else
    usage
fi