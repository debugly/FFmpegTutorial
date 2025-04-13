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
# brew install nasm
# If you really want to compile without asm, configure with --disable-asm.

export LIB_NAME='fftutorial'
export LIPO_LIBS="libavcodec libavformat libavutil libswscale libswresample"
export LIB_DEPENDS_BIN="nasm pkg-config"
export GIT_LOCAL_REPO=extra/ffmpeg
export REPO_DIR=ffmpeg

# you can export GIT_FFMPEG_UPSTREAM=git@xx:yy/FFmpeg.git use your mirror
if [[ "$GIT_FFMPEG_UPSTREAM" != "" ]] ;then
    export GIT_UPSTREAM="$GIT_FFMPEG_UPSTREAM"
else
    export GIT_UPSTREAM=https://github.com/FFmpeg/FFmpeg.git
fi

if [[ "$GIT_FFMPEG_COMMIT" != "" ]] ;then
    export GIT_COMMIT="$GIT_FFMPEG_COMMIT"
    export GIT_REPO_VERSION="$GIT_FFMPEG_COMMIT"
else
    export GIT_COMMIT=n6.1.1 #origin/release/5.1
    export GIT_REPO_VERSION=6.1.1
fi

# pre compiled
export PRE_COMPILE_TAG=
export PRE_COMPILE_TAG_TVOS=fftutorial-6.1.1-250413171857
export PRE_COMPILE_TAG_MACOS=fftutorial-6.1.1-250413171857
export PRE_COMPILE_TAG_IOS=fftutorial-6.1.1-250413171857
export PRE_COMPILE_TAG_ANDROID=

