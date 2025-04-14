//
//  IJKMetalPipelineMeta.m
//  IJKMediaPlayerKit
//
//  Created by Reach Matt on 2023/6/26.
//

#import "IJKMetalPipelineMeta.h"
//#import "ijk_vout_common.h"
//#include "../ijksdl_log.h"

#define IJK_TransferFunction_ITU_R_2100_HLG CFSTR("ITU_R_2100_HLG")
#define IJK_TransferFunction_SMPTE_ST_2084_PQ CFSTR("SMPTE_ST_2084_PQ")
#define IJK_TransferFunction_SMPTE_ST_428_1 CFSTR("SMPTE_ST_428_1")
#define IJK_TransferFunction_Linear CFSTR("Linear")


@implementation IJKMetalPipelineMeta

+ (IJKMetalPipelineMeta *)createWithCVPixelbuffer:(CVPixelBufferRef)pixelBuffer
{
    NSString* shaderName;
    
    BOOL needConvertColor = YES;
    int plane = CVPixelBufferIsPlanar(pixelBuffer) ? (int)CVPixelBufferGetPlaneCount(pixelBuffer) : 1;
    if (plane == 3) {
        /*
         cv_format == kCVPixelFormatType_420YpCbCr8Planar ||
         cv_format == kCVPixelFormatType_420YpCbCr8PlanarFullRange
         */
        shaderName = @"yuv420pFragmentShader";
    } else if (plane == 2) {
        /*
         cv_format == kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange ||
         cv_format == kCVPixelFormatType_420YpCbCr8BiPlanarFullRange  ||
         cv_format == kCVPixelFormatType_420YpCbCr10BiPlanarVideoRange||
         cv_format == kCVPixelFormatType_420YpCbCr10BiPlanarFullRange ||
         cv_format == kCVPixelFormatType_422YpCbCr10BiPlanarVideoRange||
         cv_format == kCVPixelFormatType_422YpCbCr10BiPlanarFullRange ||
         cv_format == kCVPixelFormatType_444YpCbCr10BiPlanarVideoRange||
         cv_format == kCVPixelFormatType_444YpCbCr10BiPlanarFullRange ||
         cv_format == kCVPixelFormatType_422YpCbCr16BiPlanarVideoRange||
         cv_format == kCVPixelFormatType_444YpCbCr16BiPlanarVideoRange
         */
        shaderName = @"nv12FragmentShader";
    } else if (plane == 1) {
        OSType cv_format = CVPixelBufferGetPixelFormatType(pixelBuffer);
        if (cv_format == kCVPixelFormatType_32BGRA) {
            needConvertColor = NO;
            shaderName = @"bgraFragmentShader";
        } else if (cv_format == kCVPixelFormatType_32ARGB) {
            needConvertColor = NO;
            shaderName = @"argbFragmentShader";
        } else if (cv_format == kCVPixelFormatType_4444AYpCbCr16) {
            needConvertColor = YES;
            shaderName = @"ayuvFragmentShader";
        } else if (cv_format == kCVPixelFormatType_422YpCbCr8) {
            shaderName = @"uyvy422FragmentShader";
        } else if (cv_format == kCVPixelFormatType_422YpCbCr8_yuvs ||
                   cv_format == kCVPixelFormatType_422YpCbCr8FullRange) {
            shaderName = @"uyvy422FragmentShader";
        }
    } else {
        //wtf?
        OSType cv_format = CVPixelBufferGetPixelFormatType(pixelBuffer);
        NSLog(@"create render failed,unsupported plane count:%d,unknown format:%4s\n",plane,(char *)&cv_format);
        return nil;
    }

    IJKYUV2RGBColorMatrixType colorMatrixType = IJKYUV2RGBColorMatrixNone;
    if (needConvertColor) {
        CFStringRef colorMatrix = CVBufferGetAttachment(pixelBuffer, kCVImageBufferYCbCrMatrixKey, NULL);
        if (colorMatrix) {
            if (CFStringCompare(colorMatrix, kCVImageBufferYCbCrMatrix_ITU_R_709_2, 0) == kCFCompareEqualTo) {
                colorMatrixType = IJKYUV2RGBColorMatrixBT709;
            } else if (CFStringCompare(colorMatrix, kCVImageBufferYCbCrMatrix_ITU_R_601_4, 0) == kCFCompareEqualTo) {
                colorMatrixType = IJKYUV2RGBColorMatrixBT601;
            } else if (CFStringCompare(colorMatrix, kCVImageBufferYCbCrMatrix_ITU_R_2020, 0) == kCFCompareEqualTo) {
                colorMatrixType = IJKYUV2RGBColorMatrixBT2020;
            }
        }
        if (colorMatrixType == IJKYUV2RGBColorMatrixNone) {
            colorMatrixType = IJKYUV2RGBColorMatrixBT709;
        }
    }
    
    BOOL fullRange = NO;
    OSType cv_format = CVPixelBufferGetPixelFormatType(pixelBuffer);
    
    //full color range
    if (kCVPixelFormatType_420YpCbCr8BiPlanarFullRange == cv_format ||
        kCVPixelFormatType_420YpCbCr8PlanarFullRange == cv_format ||
        kCVPixelFormatType_422YpCbCr8FullRange == cv_format ||
        kCVPixelFormatType_420YpCbCr10BiPlanarFullRange == cv_format ||
        kCVPixelFormatType_422YpCbCr10BiPlanarFullRange == cv_format ||
        kCVPixelFormatType_444YpCbCr10BiPlanarFullRange == cv_format) {
        fullRange = YES;
    }
    
    IJKMetalPipelineMeta *meta = [IJKMetalPipelineMeta new];
    meta.fragmentName = shaderName;
    meta.fullRange = fullRange;
    meta.convertMatrixType = colorMatrixType;
    //HDR color space.
    if (colorMatrixType == IJKYUV2RGBColorMatrixBT2020) {
        meta.hdr = YES;
        
        IJKColorTransferFunc tf;
        CFStringRef transferFuntion = CVBufferGetAttachment(pixelBuffer, kCVImageBufferTransferFunctionKey, NULL);
        if (transferFuntion) {
            if (CFStringCompare(transferFuntion, IJK_TransferFunction_ITU_R_2100_HLG, 0) == kCFCompareEqualTo) {
                tf = IJKColorTransferFuncHLG;
            } else if (CFStringCompare(transferFuntion, IJK_TransferFunction_SMPTE_ST_2084_PQ, 0) == kCFCompareEqualTo || CFStringCompare(transferFuntion, IJK_TransferFunction_SMPTE_ST_428_1, 0) == kCFCompareEqualTo) {
                tf = IJKColorTransferFuncPQ;
            } else {
                tf = IJKColorTransferFuncLINEAR;
            }
        } else {
            tf = IJKColorTransferFuncLINEAR;
        }
        
        meta.transferFunc = tf;
    }
    return meta;
}

- (NSString *)description
{
    NSString *matrix = [@[@"None",@"BT601",@"BT709",@"BT2020"] objectAtIndex:self.convertMatrixType];
    if (self.hdr) {
        NSString *tf = [@[@"LINEAR",@"PQ",@"HLG"] objectAtIndex:self.transferFunc];
        return [NSString stringWithFormat:@"%@,hdr:%d,fullRange:%d,matrix:%@,transfer:%@",self.fragmentName,self.hdr,self.fullRange,matrix,tf];
    } else {
        return [NSString stringWithFormat:@"%@,fullRange:%d,matrix:%@",self.fragmentName,self.fullRange,matrix];
    }
}

- (BOOL)metaMatchedCVPixelbuffer:(CVPixelBufferRef)pixelBuffer
{
    return [self isEqualTo:[IJKMetalPipelineMeta createWithCVPixelbuffer:pixelBuffer]];
}

- (BOOL)isEqualTo:(id)object
{
    IJKMetalPipelineMeta *meta = object;
    if (![object isKindOfClass:[IJKMetalPipelineMeta class]]) {
        return NO;
    }
    if (self.transferFunc != meta.transferFunc) {
        return NO;
    }
    if (self.fragmentName != meta.fragmentName) {
        return NO;
    }
    if (self.fullRange != meta.fullRange) {
        return NO;
    }
    if (self.hdr != meta.hdr) {
        return NO;
    }
    if (self.convertMatrixType != meta.convertMatrixType) {
        return NO;
    }
    return YES;
}

@end
