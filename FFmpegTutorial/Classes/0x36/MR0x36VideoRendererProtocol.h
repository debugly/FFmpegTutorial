//
//  MR0x36VideoRendererProtocol.h
//  Pods
//
//  Created by qianlongxu on 2022/7/25.
//

#ifndef MR0x36VideoRendererProtocol_h
#define MR0x36VideoRendererProtocol_h

typedef enum : NSUInteger {
    MR0x36ContentModeScaleToFill,
    MR0x36ContentModeScaleAspectFill,
    MR0x36ContentModeScaleAspectFit
} MR0x36ContentMode;

@protocol MR0x36VideoRendererProtocol <NSObject>

- (void)setContentMode:(MR0x36ContentMode)contentMode;
- (MR0x36ContentMode)contentMode;

@end

#endif /* MR0x36VideoRendererProtocol_h */
