//
//  FFPlayerHeader.h
//  FFmpegTutorial
//
//  Created by Matt Reach on 2020/4/27.
//

#ifndef FFPlayerHeader_h
#define FFPlayerHeader_h

typedef enum : NSUInteger {
    FFPlayerErrorCode_OpenFileFaild,///文件打开失败
    FFPlayerErrorCode_StreamNotFound///找不到音视频流
} FFPlayerErrorCode;

#endif /* FFPlayerHeader_h */
