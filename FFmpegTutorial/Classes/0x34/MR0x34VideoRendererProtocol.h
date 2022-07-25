//
//  MR0x34VideoRendererProtocol.h
//  Pods
//
//  Created by qianlongxu on 2022/7/25.
//

#ifndef MR0x34VideoRendererProtocol_h
#define MR0x34VideoRendererProtocol_h

typedef enum : NSUInteger {
    MR0x34ContentModeScaleToFill,
    MR0x34ContentModeScaleAspectFill,
    MR0x34ContentModeScaleAspectFit
} MR0x34ContentMode;

@protocol MR0x34VideoRendererProtocol <NSObject>

- (void)setContentMode:(MR0x34ContentMode)contentMode;
- (MR0x34ContentMode)contentMode;

@end

#endif /* MR0x34VideoRendererProtocol_h */
