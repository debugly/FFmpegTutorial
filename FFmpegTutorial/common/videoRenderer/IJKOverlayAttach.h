//
//  IJKOverlayAttach.h
//  FFmpegTutorial
//
//  Created by Reach Matt on 2023/12/19.
//

#import <Foundation/Foundation.h>
#import <CoreVideo/CVPixelBuffer.h>

@interface IJKOverlayAttach : NSObject

//video frame normal size not alignmetn,maybe not equal to currentVideoPic's size.
@property(nonatomic) int w;
@property(nonatomic) int h;
//cvpixebuffer pixel memory size;
@property(nonatomic) int pixelW;
@property(nonatomic) int pixelH;

@property(nonatomic) int planes;
@property(nonatomic) UInt16 *pitches;
@property(nonatomic) UInt8 **pixels;
@property(nonatomic) int sarNum;
@property(nonatomic) int sarDen;
//degrees
@property(nonatomic) int autoZRotate;
@property(nonatomic) CVPixelBufferRef videoPicture;
@property(nonatomic) NSArray *videoTextures;

@end
