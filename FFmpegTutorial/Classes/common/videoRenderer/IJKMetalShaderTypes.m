//
//  IJKMetalPixelTypes.h
//  FFmpegTutorial-macOS
//
//  Created by qianlongxu on 2022/11/23.
//  Copyright © 2022 Matt Reach's Awesome FFmpeg Tutotial. All rights reserved.
//

#import "IJKMetalShaderTypes.h"

static mp_format mp_formats[] = {
    {
        .cvpixfmt = kCVPixelFormatType_32BGRA,
        .planes = 1,
        .formats = {MTLPixelFormatBGRA8Unorm}
    },
    {
        .cvpixfmt = kCVPixelFormatType_32ARGB,
        .planes = 1,
        .formats = {MTLPixelFormatBGRA8Unorm}
    },
    {
        .cvpixfmt = kCVPixelFormatType_4444AYpCbCr16,
        .planes = 1,
        .formats = {MTLPixelFormatRGBA16Unorm}
    },
#if TARGET_OS_OSX
    {
        .cvpixfmt = kCVPixelFormatType_422YpCbCr8,
        .planes = 1,
        .formats = {MTLPixelFormatBGRG422}
    },
    {
        .cvpixfmt = kCVPixelFormatType_422YpCbCr8_yuvs,
        .planes = 1,
        .formats = {MTLPixelFormatGBGR422}
    },
    {
        .cvpixfmt = kCVPixelFormatType_422YpCbCr8FullRange,
        .planes = 1,
        .formats = {MTLPixelFormatGBGR422}
    },
#endif
    {
        .cvpixfmt = kCVPixelFormatType_444YpCbCr8BiPlanarVideoRange,
        .planes = 2,
        .formats = {MTLPixelFormatR8Unorm,MTLPixelFormatRG8Unorm}
    },
    {
        .cvpixfmt = kCVPixelFormatType_444YpCbCr8BiPlanarFullRange,
        .planes = 2,
        .formats = {MTLPixelFormatR8Unorm,MTLPixelFormatRG8Unorm}
    },
    {
        .cvpixfmt = kCVPixelFormatType_422YpCbCr8BiPlanarVideoRange,
        .planes = 2,
        .formats = {MTLPixelFormatR8Unorm,MTLPixelFormatRG8Unorm}
    },
    {
        .cvpixfmt = kCVPixelFormatType_422YpCbCr8BiPlanarFullRange,
        .planes = 2,
        .formats = {MTLPixelFormatR8Unorm,MTLPixelFormatRG8Unorm}
    },
    {
        .cvpixfmt = kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange,
        .planes = 2,
        .formats = {MTLPixelFormatR8Unorm,MTLPixelFormatRG8Unorm}
    },
    {
        .cvpixfmt = kCVPixelFormatType_420YpCbCr8BiPlanarFullRange,
        .planes = 2,
        .formats = {MTLPixelFormatR8Unorm,MTLPixelFormatRG8Unorm}
    },
    {
        .cvpixfmt = kCVPixelFormatType_444YpCbCr10BiPlanarVideoRange,
        .planes = 2,
        .formats = {MTLPixelFormatR16Unorm,MTLPixelFormatRG16Unorm}
    },
    {
        .cvpixfmt = kCVPixelFormatType_444YpCbCr10BiPlanarFullRange,
        .planes = 2,
        .formats = {MTLPixelFormatR16Unorm,MTLPixelFormatRG16Unorm}
    },
    {
        .cvpixfmt = kCVPixelFormatType_422YpCbCr10BiPlanarVideoRange,
        .planes = 2,
        .formats = {MTLPixelFormatR16Unorm,MTLPixelFormatRG16Unorm}
    },
    {
        .cvpixfmt = kCVPixelFormatType_422YpCbCr10BiPlanarFullRange,
        .planes = 2,
        .formats = {MTLPixelFormatR16Unorm,MTLPixelFormatRG16Unorm}
    },
    {
        .cvpixfmt = kCVPixelFormatType_420YpCbCr10BiPlanarVideoRange,
        .planes = 2,
        .formats = {MTLPixelFormatR16Unorm,MTLPixelFormatRG16Unorm}
    },
    {
        .cvpixfmt = kCVPixelFormatType_420YpCbCr10BiPlanarFullRange,
        .planes = 2,
        .formats = {MTLPixelFormatR16Unorm,MTLPixelFormatRG16Unorm}
    },
    {
        .cvpixfmt = kCVPixelFormatType_444YpCbCr16BiPlanarVideoRange,
        .planes = 2,
        .formats = {MTLPixelFormatR16Unorm,MTLPixelFormatRG16Unorm}
    },
    {
        .cvpixfmt = kCVPixelFormatType_422YpCbCr16BiPlanarVideoRange,
        .planes = 2,
        .formats = {MTLPixelFormatR16Unorm,MTLPixelFormatRG16Unorm}
    },
    {
        .cvpixfmt = kCVPixelFormatType_420YpCbCr8Planar,
        .planes = 3,
        .formats = {MTLPixelFormatR8Unorm,MTLPixelFormatR8Unorm,MTLPixelFormatR8Unorm}
    },
    {
        .cvpixfmt = kCVPixelFormatType_420YpCbCr8PlanarFullRange,
        .planes = 3,
        .formats = {MTLPixelFormatR8Unorm,MTLPixelFormatR8Unorm,MTLPixelFormatR8Unorm}
    }
};

#define MP_ARRAY_SIZE(s) (sizeof(s) / sizeof((s)[0]))

mp_format * mp_get_metal_format(uint32_t cvpixfmt)
{
    for (int i = 0; i < MP_ARRAY_SIZE(mp_formats); i++) {
        if (mp_formats[i].cvpixfmt == cvpixfmt)
            return &mp_formats[i];
    }
    return NULL;
}

IJKConvertMatrix ijk_metal_create_color_matrix(IJKYUV2RGBColorMatrixType matrixType, int fullRange)
{
    IJKConvertMatrix matrix = {0.0};
    switch (matrixType) {
        case IJKYUV2RGBColorMatrixBT601:
        {
            matrix.colorMatrix = (matrix_float3x3){
                (simd_float3){1.164,  1.164, 1.164},
                (simd_float3){0.0,   -0.391, 2.018},
                (simd_float3){1.596, -0.813, 0.0},
            };
        }
            break;
        case IJKYUV2RGBColorMatrixBT709:
        {
            matrix.colorMatrix = (matrix_float3x3){
                (simd_float3){1.164,  1.164, 1.164},
                (simd_float3){0.0,   -0.213, 2.112},
                (simd_float3){1.793, -0.533, 0.0},
            };
        }
            break;
        case IJKYUV2RGBColorMatrixBT2020:
        {
            matrix.colorMatrix = (matrix_float3x3){
                (simd_float3){1.164384, 1.164384 , 1.164384},
                (simd_float3){0.0     , -0.187326, 2.14177},
                (simd_float3){1.67867 , -0.65042 , 0.0},
            };
        }
            break;
        case IJKYUV2RGBColorMatrixNone:
        {
            break;
        }
    }

    vector_float3 offset;
    if (fullRange) {
        offset = (vector_float3){ 0.0, -0.5, -0.5};
    } else {
        offset = (vector_float3){ -(16.0/255.0), -0.5, -0.5};
    }
    matrix.offset = offset;
    return matrix;
}
