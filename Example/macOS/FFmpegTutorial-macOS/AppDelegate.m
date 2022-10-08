//
//  AppDelegate.m
//  FFmpegTutorial-macOS
//
//  Created by Matt Reach on 2020/11/18.
//

#import "AppDelegate.h"
#import "NSNavigationController.h"
#import "RootViewController.h"
#import "renderer_pixfmt.h"

@interface AppDelegate ()

@property (nonatomic, strong) NSWindowController *rootWinController;

@end

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    // Insert code here to initialize your application
    NSWindow *window = [[NSWindow alloc] initWithContentRect:CGRectZero styleMask:NSWindowStyleMaskTitled | NSWindowStyleMaskClosable | NSWindowStyleMaskMiniaturizable | NSWindowStyleMaskResizable backing:NSBackingStoreBuffered defer:YES];

    window.titleVisibility = NSWindowTitleHidden;
    window.titlebarAppearsTransparent = YES;
    window.styleMask |= NSWindowStyleMaskFullSizeContentView;
    [window setMinSize:CGSizeMake(300, 300)];
    
    NSWindowController *rootWinController = [[NSWindowController alloc] initWithWindow:window];
    
    RootViewController *rootViewController = [[RootViewController alloc] init];
    
    NSNavigationController *navController = [[NSNavigationController alloc] initWithRootViewController:rootViewController];
    window.contentViewController = navController;
    window.movableByWindowBackground = YES;
    [window center];
    [window makeKeyWindow];
    [rootWinController showWindow:nil];
    
    self.rootWinController = rootWinController;
    
    printSupportedPixelFormats(false);
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)sender
{
    return YES;
}

- (void)applicationWillTerminate:(NSNotification *)aNotification
{
    // Insert code here to tear down your application
}

- (BOOL)applicationShouldHandleReopen:(NSApplication *)sender hasVisibleWindows:(BOOL)flag
{
    if (self.rootWinController) {
        if (self.rootWinController.window.isMiniaturized) {
            [self.rootWinController.window deminiaturize:nil];
        } else if (!self.rootWinController.window.isVisible) {
            [self.rootWinController showWindow:nil];
        }
    }
    return YES;
}

@end
