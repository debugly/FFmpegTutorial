//
//  MR0x35VideoRendererProtocol.h
//  Pods
//
//  Created by qianlongxu on 2022/7/25.
//

#ifndef MR0x35VideoRendererProtocol_h
#define MR0x35VideoRendererProtocol_h

typedef enum : NSUInteger {
    MR0x35ContentModeScaleToFill,
    MR0x35ContentModeScaleAspectFill,
    MR0x35ContentModeScaleAspectFit
} MR0x35ContentMode;

@protocol MR0x35VideoRendererProtocol <NSObject>

- (void)setContentMode:(MR0x35ContentMode)contentMode;
- (MR0x35ContentMode)contentMode;

@end

#endif /* MR0x35VideoRendererProtocol_h */
