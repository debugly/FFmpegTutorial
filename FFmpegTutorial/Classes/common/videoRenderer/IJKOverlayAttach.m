//
//  IJKOverlayAttach.m
//  FFmpegTutorial
//
//  Created by Reach Matt on 2023/12/19.
//

#import "IJKOverlayAttach.h"

@implementation IJKOverlayAttach

- (void)dealloc
{
    if (self.videoPicture) {
        CVPixelBufferRelease(self.videoPicture);
        self.videoPicture = NULL;
    }
}

@end
