//
//  MRMp3Encoder.hpp
//  Mp3Encoder
//
//  Created by qianlongxu on 2020/1/16.
//  Copyright © 2020 Awesome FFmpeg Study Demo. All rights reserved.
//
// 读取 PCM 文件，编码成 Mp3 文件

#ifndef MRMp3Encoder_hpp
#define MRMp3Encoder_hpp

#include <lame/lame.h>

class MRMp3Encoder {

    private:
    FILE* pcmFile;
    FILE* mp3File;
    lame_t lameClient;
    
    public:
    
    MRMp3Encoder();
    ~MRMp3Encoder();
    
    int init(const char* pcm,const char* outer,int sampleRate,int channels,int bitRate);
    
    void encode();
    void destory();
};

#endif /* MRMp3Encoder_hpp */
