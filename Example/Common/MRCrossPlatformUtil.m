//
//  MRPlatform.c
//  FFmpegTutorial-iOS
//
//  Created by qianlongxu on 2022/12/3.
//  Copyright © 2022 Matt Reach's Awesome FFmpeg Tutotial. All rights reserved.
//

#import "MRCrossPlatformUtil.h"

#if TARGET_OS_IPHONE

@implementation UIActivityIndicatorView (_appkit_)

- (void)startAnimation:(id)a
{
    [self startAnimating];
}

- (void)stopAnimation:(id)a
{
    [self stopAnimating];
}

@end

@implementation UITextView (_appkit_)

- (void)setString:(NSString *)t
{
    self.text = t;
}

@end

@implementation UITextField (_appkit_)

- (void)setStringValue:(NSString *)t
{
    self.text = t;
}

- (NSString *)stringValue
{
    return self.text;
}

- (void)setPlaceholderString:(NSString *)t
{
    self.placeholder = t;
}

- (NSString *)placeholderString
{
    return self.placeholder;
}

@end
#endif


@implementation MRBaseViewController

- (instancetype)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
#if TARGET_OS_IPHONE
    nibNameOrNil = [nibNameOrNil stringByAppendingString:@"-iOS"];
#endif
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        
    }
    return self;
}

#if TARGET_OS_IPHONE
- (void)viewWillDisappear
{
    [self viewWillDisappear:YES];
}
#endif

@end
