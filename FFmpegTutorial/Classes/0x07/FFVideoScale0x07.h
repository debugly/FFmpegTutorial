//
//  FFVideoScale0x07.h
//  FFmpegTutorial
//
//  Created by Matt Reach on 2020/6/3.
//

#import <Foundation/Foundation.h>
#import "FFPlayerHeader.h"

NS_ASSUME_NONNULL_BEGIN

typedef struct AVFrame AVFrame;

@interface FFVideoScale0x07 : NSObject

- (instancetype)initWithSrcPixFmt:(int)srcPixFmt
                        dstPixFmt:(int)dstPixFmt
                         picWidth:(int)picWidth
                        picHeight:(int)picHeight;

- (BOOL) rescaleFrame:(AVFrame *)inF out:(AVFrame *_Nonnull*_Nonnull)outP;

@end

NS_ASSUME_NONNULL_END
