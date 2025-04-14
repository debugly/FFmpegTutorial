//
//  FFTDispatch.h
//  FFmpegTutorial
//
//  Created by qianlongxu on 2022/7/9.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

void mr_sync_main_queue(dispatch_block_t block);

void mr_async_main_queue(dispatch_block_t block);

NS_ASSUME_NONNULL_END
