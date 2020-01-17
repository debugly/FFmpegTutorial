//
//  MRMp3Encoder.cpp
//  Mp3Encoder
//
//  Created by qianlongxu on 2020/1/16.
//  Copyright © 2020 Awesome FFmpeg Study Demo. All rights reserved.
//

#include "MRMp3Encoder.hpp"
#include <stdio.h>
#include <memory.h>

MRMp3Encoder::MRMp3Encoder(){
    printf("%s constructor method.\n",__func__);
}

MRMp3Encoder::~MRMp3Encoder(){
    printf("%s destructor method.\n",__func__);
}

int MRMp3Encoder::init(const char *pcm, const char *outer, int sampleRate, int channels, int brate){
    
    int ret = 0;
    pcmFile = fopen(pcm, "rb");
    if (pcmFile) {
        mp3File = fopen(outer, "wb");
        if (mp3File) {
            lameClient = lame_init();
            if (lameClient) {
                lame_set_in_samplerate(lameClient, sampleRate);
                lame_set_out_samplerate(lameClient, sampleRate);
                lame_set_num_channels(lameClient, channels);
                lame_set_brate(lameClient, brate);
                ret = lame_init_params(lameClient);
            } else {
                ret = -3;
            }
        } else {
            ret = -2;
        }
    } else {
        ret = -1;
    }

    if (ret) {
        if (pcmFile) {
            fclose(pcmFile);
            pcmFile = nullptr;
        }
        if (mp3File) {
            fclose(mp3File);
            mp3File = nullptr;
        }
    }
    
    return ret;
}

//void MRMp3Encoder::encode(){
//
//    int bufferSize = 1024 * 256;
//
//    short* in_buffer = new short[bufferSize / 2];
//    unsigned char* out_buffer = new unsigned char[bufferSize];
//
//    short *leftBuffer = new short[bufferSize / 4];
//    short *rightBuffer = new short[bufferSize / 4];
//
//    size_t readBufferSize = 0;
//
//    int channels = lame_get_num_channels(lameClient);
//
//    //跳过 PCM header 否者会有一些噪音在MP3开始播放处
//    fseek(pcmFile, 4*1024,  SEEK_CUR);
//
//    while ( (readBufferSize = fread(in_buffer, 2, bufferSize / 2, pcmFile)) > 0 ) {
//
//        if (channels == 2) {
//            for (int i = 0; i < readBufferSize; i++) {
//                if (i % 2 == 0) {
//                    leftBuffer[i / 2] = in_buffer[i];
//                } else {
//                    rightBuffer[i / 2] = in_buffer[i];
//                }
//            }
//        } else {
//            memcpy(leftBuffer, in_buffer, readBufferSize);
//            memcpy(rightBuffer, in_buffer, readBufferSize);
//        }
//
//        size_t wroteSize = lame_encode_buffer(lameClient, leftBuffer, rightBuffer, (int)(readBufferSize/2), out_buffer, bufferSize);
//        fwrite(out_buffer, 1, wroteSize, mp3File);
//    }
//
//    delete [] in_buffer;
//    delete [] leftBuffer;
//    delete [] rightBuffer;
//    delete [] out_buffer;
//}

void MRMp3Encoder::encode(){
    
    int dep = sizeof(float);
    int num_samples = 1024 * 1000;
    
    float* in_buffer = new float[num_samples];
    int mp3buf_size = 1.25 * num_samples + 7200;
    unsigned char* out_buffer = new unsigned char[mp3buf_size];
    
    int channels = lame_get_num_channels(lameClient);
    int read_samples = 0;
    
    while ( (read_samples = (int)fread(in_buffer, dep, num_samples, pcmFile)) > 0 ) {
        
        if (channels == 2) {
            size_t wroteSize = lame_encode_buffer_interleaved_ieee_float(lameClient, in_buffer, read_samples/2, out_buffer, mp3buf_size);
            fwrite(out_buffer, 1, wroteSize, mp3File);
        } else {
            size_t wroteSize = lame_encode_buffer_ieee_float(lameClient, in_buffer, nullptr, read_samples, out_buffer, mp3buf_size);
            fwrite(out_buffer, 1, wroteSize, mp3File);
        }
        
    }
    
    delete [] in_buffer;
    delete [] out_buffer;
}

void MRMp3Encoder::destory(){
    if (pcmFile) {
        fclose(pcmFile);
        pcmFile = nullptr;
    }
    if (mp3File) {
        fclose(mp3File);
        mp3File = nullptr;
    }
    if (lameClient) {
        lame_close(lameClient);
        lameClient = nullptr;
    }
}
