//
//  FFTAbstractLogger.m
//  FFmpegTutorial
//
//  Created by Matt Reach on 2021/7/5.
//

#import "FFTAbstractLogger.h"

@interface FFTAbstractLogger ()

@property (nonatomic, copy) void (^logRecipient)(MRALLevel, NSString * _Nonnull);
@property (nonatomic, strong) NSDateFormatter *formatter;

@end

@implementation FFTAbstractLogger

+ (instancetype)sharedLogger
{
    static id instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[self alloc] init];
    });
    return nil;
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
        [formatter setDateFormat:@"MM-dd HH:mm:ss"];
        self.formatter = formatter;
    }
    return self;
}

- (void)registerLogRecipient:(void (^)(MRALLevel, NSString * _Nonnull))block
{
    self.logRecipient = block;
}

- (void)write:(MRALLevel)level fmt:(NSString *)fmt,...
{
    if (self.logRecipient) {
        
        va_list ap;
        va_start(ap, fmt);
        NSString *log = [[NSString alloc] initWithFormat:fmt arguments:ap];
        va_end(ap);
        
        NSDate *date = [NSDate date];
        NSString *dateString = [self.formatter stringFromDate:date];
        
        self.logRecipient(level, [NSString stringWithFormat:@"[%@] %@",dateString,log]);
    }
}

@end
