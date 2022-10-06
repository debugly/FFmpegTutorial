//
//  MRVideoRendererProtocol.h
//  Pods
//
//  Created by qianlongxu on 2022/7/20.
//

#ifndef MRVideoRendererProtocol_h
#define MRVideoRendererProtocol_h

typedef enum : NSUInteger {
    MR0x32ContentModeScaleToFill,
    MR0x32ContentModeScaleAspectFill,
    MR0x32ContentModeScaleAspectFit
} MR0x32ContentMode;

@protocol MRVideoRendererProtocol <NSObject>

- (void)setContentMode:(MR0x32ContentMode)contentMode;
- (MR0x32ContentMode)contentMode;

@end

#endif /* MRVideoRendererProtocol_h */
