//
//  FFTVersionHelper.h
//  FFmpegTutorial
//
//  Created by qianlongxu on 2020/4/18.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface FFTVersionHelper : NSObject

///libavutil's version 57.78.100
+ (NSString *)libavutilVersion;

///libavcodec's version 57.107.100
+ (NSString *)libavcodecVersion;

///libavformat's version 57.83.100
+ (NSString *)libavformatVersion;

///libavformat's version 57.10.100
+ (NSString *)libavdeviceVersion;

///libavfilter's version 6.107.100
+ (NSString *)libavfilterVersion;

///libswscale's version 4.8.100
+ (NSString *)libswscaleVersion;

///libswresample's version 2.9.100
+ (NSString *)libswresampleVersion;

//all libs version
+ (NSString *)formatedLibsVersion;
//build-time configuration
+ (NSString *)configuration;
//build-time configuration;a opt use a line
+ (NSString *)formatedConfiguration;
//[configuration] + [formatedLibsVersion]
+ (NSString *)allVersionInfo;

+ (NSArray<NSString *> *)supportedInputProtocols;
+ (NSArray<NSString *> *)supportedOutputProtocols;
+ (NSDictionary *)supportedCodecs;

//above all info
+ (NSString *)ffmpegAllInfo;

@end

NS_ASSUME_NONNULL_END
