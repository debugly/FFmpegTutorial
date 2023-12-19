//
//  IJKMetalPipelineMeta.h
//  IJKMediaPlayerKit
//
//  Created by Reach Matt on 2023/6/26.
//

#import <Foundation/Foundation.h>
#import "IJKMetalShaderTypes.h"

NS_ASSUME_NONNULL_BEGIN
NS_CLASS_AVAILABLE(10_13, 11_0)
@interface IJKMetalPipelineMeta : NSObject

@property (nonatomic) BOOL hdr;
@property (nonatomic) BOOL fullRange;
@property (nonatomic) NSString* fragmentName;
@property (nonatomic) IJKColorTransferFunc transferFunc;
@property (nonatomic) IJKYUV2RGBColorMatrixType convertMatrixType;

+ (IJKMetalPipelineMeta *)createWithCVPixelbuffer:(CVPixelBufferRef)pixelBuffer;
- (BOOL)metaMatchedCVPixelbuffer:(CVPixelBufferRef)pixelBuffer;

@end

NS_ASSUME_NONNULL_END
