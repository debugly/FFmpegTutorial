//
//  FFTDispatch.m
//  FFmpegTutorial
//
//  Created by qianlongxu on 2022/7/9.
//

#import "FFTDispatch.h"

void mr_sync_main_queue(dispatch_block_t block){
    assert(block);
    if (strcmp(dispatch_queue_get_label(DISPATCH_CURRENT_QUEUE_LABEL), dispatch_queue_get_label(dispatch_get_main_queue())) == 0) {
        // already in main thread.
        block();
    } else {
        // sync to main queue.
        dispatch_sync(dispatch_get_main_queue(), block);
    }
}

void mr_async_main_queue(dispatch_block_t block){
    assert(block);
    // async to main queue.
    dispatch_async(dispatch_get_main_queue(), block);
}
