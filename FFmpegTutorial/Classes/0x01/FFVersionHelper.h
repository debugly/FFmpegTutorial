//
//  FFVersionHelper.h
//  Pods
//
//  Created by qianlongxu on 2020/4/18.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface FFVersionHelper : NSObject

+ (NSString *)libavutilVersion;

+ (NSString *)libavcodecVersion;

+ (NSString *)libavformatVersion;

+ (NSString *)libavdeviceVersion;

+ (NSString *)libavfilterVersion;

+ (NSString *)libswscaleVersion;

+ (NSString *)libswresampleVersion;

//all libs version
+ (NSString *)formatedLibsVersion;
//build-time configuration
+ (NSString *)configuration;
//[configuration] + [formatedLibsVersion]
+ (NSString *)allVersionInfo;

+ (NSArray<NSString *> *)supportedInputProtocols;
+ (NSArray<NSString *> *)supportedOutputProtocols;

@end

NS_ASSUME_NONNULL_END
