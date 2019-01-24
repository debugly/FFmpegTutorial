//
//  MRAVPacketList.h
//  MRVideoPlayerFoundation
//
//  Created by Matt Reach on 2019/1/24.
//  Copyright © 2019 Awesome FFmpeg Study Demo. All rights reserved.
//

/**
 * 构造一个链表用于存储 FFmpeg 读包数据！
 * 非线程安全的！
 */

#ifndef MRAVPacketList_h
#define MRAVPacketList_h

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
                            
///**
// 创建一个链表节点，通过二重指针复制
//
// @param dest 目标变量地址
// */
//void MRPacketListNew(MRPacketList **dest);
//
///**
// 创建一个链表节点，通过二重指针复制
// 
// @param dest 目标变量地址
// @param packet 头结点的packet
// */
//void MRPacketListNewV2(MRPacketList **dest,AVPacket *packet);
//
///**
// 释放链表，链表里的节点也会被释放
// 释放完毕，指针自动置空
// @param src 目标变量地址
// */
//void MRPacketListFree(MRPacketList **src);
//
///**
// 返回该链表节点数
//
// @param header 链表头指针
// @return 长度
// */
//int MRPacketListNodeCount(MRPacketList *header);
//
//
///**
// 增加链表节点，将 packet 作为新节点的 packet
//
// @param header 链表头指针
// @param packet FFmpeg读包数据
// */
//void MRPacketListPush(MRPacketList *header,AVPacket *packet);
//
//
///**
// 将链表第一个节点出列;如果链表长度原本是 1 ，那么 Pop 之后链表header将会置空
//
// @param header 链表头指针
// @return 节点里的 packet
// */
//AVPacket * MRPacketListPopFirst(MRPacketList **header);

#endif /* MRAVPacketList_h */
