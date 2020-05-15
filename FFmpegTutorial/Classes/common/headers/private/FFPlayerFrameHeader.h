//
//  FFPlayerFrameHeader.h
//  FFmpegTutorial
//
//  Created by Matt Reach on 2020/5/14.
//

#ifndef FFPlayerFrameHeader_h
#define FFPlayerFrameHeader_h

#import <libavutil/frame.h>

#define VIDEO_PICTURE_QUEUE_SIZE 3
#define SAMPLE_QUEUE_SIZE 9
#define FRAME_QUEUE_SIZE FFMAX(SAMPLE_QUEUE_SIZE, VIDEO_PICTURE_QUEUE_SIZE)

typedef struct Frame {
    AVFrame *frame;
    double pts;           /* presentation timestamp for the frame */
} Frame;

typedef struct FrameQueue {
    Frame queue[FRAME_QUEUE_SIZE];
    int rindex;
    int windex;
    int size;
    int max_size;
    //锁
    dispatch_semaphore_t mutex;
    char *name;
    //标记为停止
    int abort_request;
} FrameQueue;

/*
[0,0,0,0,0,0,0,0]
 |
 windex
 |
 rindex
*/
///frame 队列初始化
static __inline__ int frame_queue_init(FrameQueue *f, int max_size, const char *name)
{
    int i;
    memset((void*)f, 0, sizeof(FrameQueue));
    f->name = av_strdup(name);
    f->mutex = dispatch_semaphore_create(1);
    f->max_size = FFMIN(max_size, FRAME_QUEUE_SIZE);
    
    for (i = 0; i < f->max_size; i++)
        if (!(f->queue[i].frame = av_frame_alloc()))
            return AVERROR(ENOMEM);
    return 0;
}

/*
 size=3
 [1,1,1,0,0,0,0,0]
        |
        windex
 |
 rindex
 */
//获取一个可写的节点
static __inline__ Frame *frame_queue_peek_writable(FrameQueue *f)
{
    /* wait until we have space to put a new frame */
    int ret = 0;
    dispatch_semaphore_wait(f->mutex, DISPATCH_TIME_FOREVER);
    int is_loged = 0;//避免重复打日志
    while (f->size >= f->max_size) {
        
        if (f->abort_request) {
            ret = -1;
            break;
        }
        
        if (!is_loged) {
            is_loged = 1;
            av_log(NULL, AV_LOG_VERBOSE, "%s frame queue is full(%d)\n",f->name,f->size);
        }
        
        dispatch_semaphore_signal(f->mutex);
        usleep(10000);
        dispatch_semaphore_wait(f->mutex, DISPATCH_TIME_FOREVER);
    }
    dispatch_semaphore_signal(f->mutex);
    if (ret < 0) {
        return NULL;
    }
    
    Frame *af = &f->queue[f->windex];
    return af;
}

/*
size=4
[1,1,1,1,0,0,0,0]
         |
         windex
|
rindex
*/
//移动写指针位置，增加队列里已存储数量
static __inline__ void frame_queue_push(FrameQueue *f)
{
    dispatch_semaphore_wait(f->mutex, DISPATCH_TIME_FOREVER);
    
    //写指针超过了总长度时，将写指针归零，指向头部
    if (++f->windex == f->max_size) {
        f->windex = 0;
    }
    //队列已存储数量加1
    f->size ++;
    av_log(NULL, AV_LOG_VERBOSE, "frame_queue_push %s (%d/%d)\n", f->name, f->windex, f->size);
    dispatch_semaphore_signal(f->mutex);
}

// 获取队列里缓存帧的数量
static __inline__ int frame_queue_nb_remaining(FrameQueue *f)
{
    return f->size;
}

// 获取当前读指针指向的节点
static __inline__ Frame *frame_queue_peek(FrameQueue *f)
{
    return &f->queue[(f->rindex) % f->max_size];
}

// 移动读指针位置，减少队列里已存储数量
static __inline__ void frame_queue_pop(FrameQueue *f)
{
    dispatch_semaphore_wait(f->mutex, DISPATCH_TIME_FOREVER);
    
    Frame *vp = &f->queue[f->rindex];
    av_frame_unref(vp->frame);
    if (++f->rindex == f->max_size){
        f->rindex = 0;
    }
    f->size--;
    av_log(NULL, AV_LOG_VERBOSE, "frame_queue_pop %s (%d/%d)\n", f->name, f->windex, f->size);
    
    dispatch_semaphore_signal(f->mutex);
}

// 释放队列内存
static __inline__ void frame_queue_destory(FrameQueue *f)
{
    for (int i = 0; i < f->max_size; i++) {
        Frame *vp = &f->queue[i];
        av_frame_unref(vp->frame);
        av_frame_free(&vp->frame);
    }
}

#endif /* FFPlayerFrameHeader_h */
