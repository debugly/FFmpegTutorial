//
//  MRPlatform.c
//  FFmpegTutorial-iOS
//
//  Created by qianlongxu on 2022/12/3.
//  Copyright © 2022 Matt Reach's Awesome FFmpeg Tutotial. All rights reserved.
//

#import "MRCrossPlatformUtil.h"

#if TARGET_OS_IPHONE

@implementation UIImage (_appkit)

- (instancetype)initWithCGImage:(CGImageRef)cgImage size:(CGSize)size
{
    return [self initWithCGImage:cgImage];
}

@end

@implementation UIView (_appkit_)

- (void)setWantsLayer:(BOOL)w
{
    //do nothing;
}

- (void)setNeedsDisplay:(BOOL)n
{
    [self setNeedsDisplay];
}

@end

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

@interface MRSegmentedControl ()

@property (nonatomic) NSMutableArray *tags;

@end

@implementation MRSegmentedControl : UISegmentedControl

- (void)insertSegmentWithTitle:(NSString *)title atIndex:(NSUInteger)segment animated:(BOOL)animated tag:(NSInteger)tag
{
    if (!_tags) {
        _tags = [NSMutableArray array];
    }
    [self insertSegmentWithTitle:title atIndex:segment animated:animated];
    [_tags insertObject:@(tag) atIndex:segment];
}

- (void)removeAllSegments
{
    [super removeAllSegments];
    [_tags removeAllObjects];
}

- (NSInteger)tagForCurrentSelected
{
    if ([_tags count] > 0 ) {
        if ([_tags count] > self.selectedSegmentIndex) {
            return [[_tags objectAtIndex:self.selectedSegmentIndex] intValue];
        } else {
            return NSNotFound;
        }
    } else {
        return self.selectedSegmentIndex;
    }
}

@end

#else
CGContextRef __nullable UIGraphicsGetCurrentContext(void)
{
    return [[NSGraphicsContext currentContext] graphicsPort];
}
#endif


@implementation MRBaseViewController

#if TARGET_OS_IPHONE
- (void)loadView
{
    NSString *nibName = [NSStringFromClass([self class]) stringByAppendingString:@"-iOS"];
    UINib *nib = [UINib nibWithNibName:nibName bundle:nil];
    NSArray *views = [nib instantiateWithOwner:self options:nil];
    self.view = [views firstObject];
}

- (instancetype)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    nibNameOrNil = nil;
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        
    }
    return self;
}

#endif
#if TARGET_OS_IPHONE
- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:YES];
    [self viewWillAppear];
}

- (void)viewWillAppear
{
    
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:YES];
    [self viewWillDisappear];
}

- (void)viewWillDisappear
{
    
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:YES];
    [self viewDidAppear];
}

- (void)viewDidAppear
{
    
}
#endif

- (int)alert:(NSString *)title msg:(NSString *)msg
{
#if TARGET_OS_IPHONE
    return 1;
#else
    NSAlert *alert = [[NSAlert alloc] init];
    [alert addButtonWithTitle:title];
    //[alert setMessageText:@""];
    [alert setInformativeText:msg];
    [alert setAlertStyle:NSAlertStyleInformational];
    NSModalResponse returnCode = [alert runModal];
    
    if (returnCode == NSAlertFirstButtonReturn)
    {
        //nothing todo
    }
    else if (returnCode == NSAlertSecondButtonReturn)
    {
        
    }
    return 1;
#endif
}
@end
