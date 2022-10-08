//
//  FFTVersionHelper.m
//  FFmpegTutorial
//
//  Created by qianlongxu on 2020/4/18.
//

#import "FFTVersionHelper.h"
#import <libavutil/version.h>
#import <libavcodec/version.h>
#import <libavformat/version.h>
#import <libavdevice/version.h>
#import <libavfilter/version.h>
#import <libswscale/version.h>
#import <libswresample/version.h>

#import <libavcodec/avcodec.h>
#import <libavformat/avformat.h>

#define STRINGME_(x)    #x
#define STRINGME(x)     STRINGME_(x)
#define STRINGME2OC(x)  @STRINGME(x)

@implementation FFTVersionHelper

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
    return STRINGME2OC(LIBAVDEVICE_VERSION);
}

+ (NSString *)libavfilterVersion
{
    return STRINGME2OC(LIBAVFILTER_VERSION);
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
    return [NSString stringWithFormat:@"%-20s%@\n%-20s%@\n%-20s%@\n%-20s%@\n%-20s%@\n%-20s%@\n%-20s%@",
            "libavutil",
            [self libavutilVersion],
            "libavcodec",
            [self libavcodecVersion],
            "libavformat",
            [self libavformatVersion],
            "libavdevice",
            [self libavdeviceVersion],
            "libavfilter",
            [self libavfilterVersion],
            "libswscale",
            [self libswscaleVersion],
            "libswresample",
            [self libswresampleVersion]
            ];
}

+ (NSString *)configuration
{
    return [NSString stringWithCString:avcodec_configuration() encoding:NSUTF8StringEncoding];
}

+ (NSString *)formatedConfiguration
{
    NSString *cfgStr = [self configuration];
    cfgStr = [cfgStr stringByReplacingOccurrencesOfString:@" --" withString:@"\n--"];
    return cfgStr;
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

+ (NSDictionary *)supportedCodecs
{
    void *iterate_data = NULL;
    const AVCodec *codec = NULL;
    NSMutableDictionary *codesByType = [NSMutableDictionary dictionary];
    
    while (NULL != (codec = av_codec_iterate(&iterate_data))) {
        NSMutableDictionary *dic = [NSMutableDictionary dictionary];
        if (NULL != codec->name) {
            NSString *name = [[NSString alloc]initWithUTF8String:codec->name];
            [dic setObject:name forKey:@"name"];
        }
        if (NULL != codec->long_name) {
            NSString *longName = [[NSString alloc]initWithUTF8String:codec->long_name];
            [dic setObject:longName forKey:@"longName"];
        }
        [dic setObject:[NSString stringWithFormat:@"%d",codec->id] forKey:@"id"];
        
        if (av_codec_is_encoder(codec)) {
            if (av_codec_is_decoder(codec)) {
                [dic setObject:@"Encoder,Decoder" forKey:@"type"];
            } else {
                [dic setObject:@"Encoder" forKey:@"type"];
            }
        } else if (av_codec_is_decoder(codec)) {
            [dic setObject:@"Decoder" forKey:@"type"];
        }
        
        NSString *typeKey = nil;
        
        if (codec->type == AVMEDIA_TYPE_VIDEO) {
            typeKey = @"Video";
        } else if (codec->type == AVMEDIA_TYPE_AUDIO) {
            typeKey = @"Audio";
        } else {
            typeKey = @"Other";
        }
        
        NSMutableArray *codecArr = [codesByType objectForKey:typeKey];
        
        if (!codecArr) {
            codecArr = [NSMutableArray array];
            [codesByType setObject:codecArr forKey:typeKey];
        }
        [codecArr addObject:dic];
    }
    return [codesByType copy];
}

+ (NSString *)ffmpegAllInfo
{
    NSMutableString *txt = [NSMutableString string];
    
    {
        //编译配置信息
        [txt appendFormat:@"\n【FFmpeg Build Info】\n%@",[self formatedConfiguration]];
    }
    
    [txt appendString:@"\n"];
    
    {
        //各个lib库的版本信息
        [txt appendFormat:@"\n\n【FFmpeg Libs Version】\n%@",[self formatedLibsVersion]];
    }
    
    [txt appendString:@"\n"];
    
    {
        //支持的输入流协议
        NSString *inputProtocol = [[self supportedInputProtocols] componentsJoinedByString:@","];
        [txt appendFormat:@"\n\n【Input protocols】 \n%@",inputProtocol];
    }
    
    [txt appendString:@"\n"];
    
    {
        //支持的输出流协议
        NSString *outputProtocol = [[self supportedOutputProtocols] componentsJoinedByString:@","];
        
        [txt appendFormat:@"\n\n【Output protocols】 \n%@",outputProtocol];
    }
    
    [txt appendString:@"\n"];
    
    {
        //支持的输出流协议
        NSDictionary *codecDic = [self supportedCodecs];
        NSData *data = [NSJSONSerialization dataWithJSONObject:codecDic options:NSJSONWritingPrettyPrinted error:nil];
        NSString *codecStr = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];;
        [txt appendFormat:@"\n\n【Codecs】 \n%@",codecStr];
    }
    
    [txt appendString:@"\n"];
    
    return [txt copy];
}

@end
