//
//  MR0x33VideoRendererProtocol.h
//  Pods
//
//  Created by qianlongxu on 2022/7/20.
//

#ifndef MR0x33VideoRendererProtocol_h
#define MR0x33VideoRendererProtocol_h

typedef enum : NSUInteger {
    MR0x33ContentModeScaleToFill,
    MR0x33ContentModeScaleAspectFill,
    MR0x33ContentModeScaleAspectFit
} MR0x33ContentMode;

@protocol MR0x33VideoRendererProtocol <NSObject>

- (void)setContentMode:(MR0x33ContentMode)contentMode;
- (MR0x33ContentMode)contentMode;

@end

#endif /* MR0x33VideoRendererProtocol_h */
