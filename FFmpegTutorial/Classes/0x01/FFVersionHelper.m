//
//  FFVersionHelper.m
//  Pods
//
//  Created by qianlongxu on 2020/4/18.
//

#import "FFVersionHelper.h"
#include <libavutil/version.h>
#include <libavcodec/version.h>
#include <libavformat/version.h>
//#include <libavdevice/version.h>
//#include <libavfilter/version.h>
#include <libswscale/version.h>
#include <libswresample/version.h>

#include <libavcodec/avcodec.h>
#import <libavformat/avformat.h>

#define STRINGME_(x)    #x
#define STRINGME(x)     STRINGME_(x)
#define STRINGME2OC(x)  @STRINGME(x)

@implementation FFVersionHelper

+ (NSString *)libavutilVersion
{
    return STRINGME2OC(LIBAVUTIL_VERSION);
}

+ (NSString *)libavcodecVersion
{
    return STRINGME2OC(LIBAVCODEC_VERSION);
}

+ (NSString *)libavformatVersion
{
    return STRINGME2OC(LIBAVFORMAT_VERSION);
}

+ (NSString *)libavdeviceVersion
{
//    return STRINGME2OC(LIBAVDEVICE_VERSION);
    return @"unsupported";
}

+ (NSString *)libavfilterVersion
{
//    return STRINGME2OC(LIBAVFILTER_VERSION);
    return @"unsupported";
}

+ (NSString *)libswscaleVersion
{
    return STRINGME2OC(LIBSWSCALE_VERSION);
}

+ (NSString *)libswresampleVersion
{
    return STRINGME2OC(LIBSWRESAMPLE_VERSION);
}

+ (NSString *)formatedLibsVersion
{
    return [NSString stringWithFormat:@"libavutil\t%@\nlibavcodec\t%@\nlibavformat\t%@\nlibavdevice\t%@\nlibavfilter\t%@\nlibswscale\t%@\nlibswresample\t%@",
            [self libavutilVersion],
            [self libavcodecVersion],
            [self libavformatVersion],
            [self libavdeviceVersion],
            [self libavfilterVersion],
            [self libswscaleVersion],
            [self libswresampleVersion]
            ];
}

+ (NSString *)configuration
{
    return [NSString stringWithCString:avcodec_configuration() encoding:NSUTF8StringEncoding];
}

+ (NSString *)allVersionInfo
{
    return [NSString stringWithFormat:@"%@\n%@",
            [self configuration],
            [self formatedLibsVersion]
            ];
}

+ (NSArray<NSString *> *)_supportedProtocols:(BOOL)inputOrOutput
{
    NSMutableArray *result = [NSMutableArray array];
    char *pup = NULL;
    void **a_pup = (void **)&pup;
    
    int flag = inputOrOutput ? 0 : 1;
    
    while (1) {
        const char *p = avio_enum_protocols(a_pup, flag);
        if (p != NULL) {
            [result addObject:[NSString stringWithFormat:@"%s",p]];
        }else{
            break;
        }
    }
    pup = NULL;
    
    return [result copy];
}

+ (NSArray<NSString *> *)supportedInputProtocols
{
    return [self _supportedProtocols:YES];
}

+ (NSArray<NSString *> *)supportedOutputProtocols
{
    return [self _supportedProtocols:NO];
}

@end
