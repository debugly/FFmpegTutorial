//
//  MRDragView.h
//  FFmpegTutorial-macOS
//
//  Created by Matt Reach on 2020/12/2.
//

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@protocol MRDragViewDelegate <NSObject>

- (NSDragOperation)acceptDragOperation:(NSArray <NSURL *> *)list;
- (void)handleDragFileList:(NSArray <NSURL *> *)fileUrls;

@end

@interface MRDragView : NSView

@property (weak, nonatomic) IBOutlet id<MRDragViewDelegate> delegate;

@end

NS_ASSUME_NONNULL_END
