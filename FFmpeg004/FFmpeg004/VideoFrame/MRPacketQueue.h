//
//  MRPacketQueue.h
//  FFmpeg004
//
//  Created by Matt Reach on 2019/1/24.
//  Copyright © 2019 Awesome FFmpeg Study Demo. All rights reserved.
//

/**
 * 构造一个链表用于存储 FFmpeg 读包数据！
 * 非线程安全的！
 */

#ifndef MRPacketQueue_h
#define MRPacketQueue_h

#include <stdio.h>
#include <libavcodec/avcodec.h>

typedef struct MRAVPacketList {
    AVPacket pkt;
    struct MRAVPacketList *next;
} MRAVPacketList;

typedef struct MRPacketQueue {
    MRAVPacketList *first_pkt, *last_pkt;
    int nb_packets;
    int size;
    int64_t duration;
} MRPacketQueue;

int mr_packet_queue_put(MRPacketQueue *q, AVPacket *pkt);
int mr_packet_queue_get(MRPacketQueue *q, AVPacket *pkt);
                            


#endif /* MRPacketQueue_h */
