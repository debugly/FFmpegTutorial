# 从 2月 20 号起项目里不在包含包含FFmpeg库，需要执行改脚本下载！

iOSFFmpeg[0]="FFmpeg-2.6.6"
iOSFFmpeg[1]="FFmpeg-2.8.2"

#$cp=$PWD
#cd FFmpeg2
#fflib="FFmpeg-2.8.2"
#curl http://localhost/test.zip | tar xj
#cd $$cp

cp=$PWD
path="FFmpeg"

if [ ! -d $path ]
then
    mkdir $path
fi

cd $path

for fflib in ${iOSFFmpeg[@]};do
    if [ ! -d $fflib ]
    then
    echo $fflib' not found. Trying to download...'
    curl -L https://github.com/debugly/FFmpeg-iOS-build-script/raw/source/FFmpeg-iOS/$fflib.zip | tar xj \
    || exit 1
    fi
done
rm -rf "__MACOSX"
cd $cp

echo "Congratulations FFmpeg libs is right！"
