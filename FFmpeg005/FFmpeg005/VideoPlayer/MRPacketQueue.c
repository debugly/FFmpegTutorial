//
//  MRPacketQueue.c
//  FFmpeg005
//
//  Created by Matt Reach on 2019/1/24.
//  Copyright © 2019 Awesome FFmpeg Study Demo. All rights reserved.
//

#include "MRPacketQueue.h"
#include <assert.h>
#include <stdbool.h>

int mr_packet_queue_put(MRPacketQueue *q, AVPacket *pkt)
{
    MRAVPacketList *pkt1 = av_malloc(sizeof(MRAVPacketList));
    if (!pkt1)
        return -1;
    pkt1->pkt = *pkt;
    av_packet_ref(&pkt1->pkt, pkt);
    pkt1->next = NULL;
    
    if (!q->last_pkt)
        q->first_pkt = pkt1;
    else
        q->last_pkt->next = pkt1;
    q->last_pkt = pkt1;
    q->nb_packets++;
    q->size += pkt1->pkt.size + sizeof(*pkt1);
    q->duration += pkt1->pkt.duration;
    return 0;
}

/* return < 0 if aborted, 0 if no packet and > 0 if packet.  */
int mr_packet_queue_get(MRPacketQueue *q, AVPacket *pkt)
{
    MRAVPacketList *pkt1 = q->first_pkt;
    if (pkt1) {
        q->first_pkt = pkt1->next;
        if (!q->first_pkt)
            q->last_pkt = NULL;
        q->nb_packets--;
        q->size -= pkt1->pkt.size + sizeof(*pkt1);
        q->duration -= pkt1->pkt.duration;
        *pkt = pkt1->pkt;
        av_free(pkt1);
        return true;
    }
    return false;
}

//void MRPacketListNew(MRPacketList **dest)
//{
//    MRPacketListNewV2(dest, NULL);
//}
//
//void MRPacketListNewV2(MRPacketList **dest,AVPacket *packet)
//{
//    assert(dest);
//    size_t size = sizeof(MRPacketList);
//    MRPacketList* header = av_malloc(size);
//    memset(header, 0, size);
//    header->packet = packet;
//    *dest = header;
//}
//
//void MRPacketListFree(MRPacketList **src)
//{
//    if (src) {
//        MRPacketList *header = *src;
//        while (NULL != header) {
//            MRPacketList *tmp = header->next;
//            ///释放内存
//            //?? av_packet_unref(header->packet);
//            av_free_packet(header->packet);
//            free(header);
//            header = tmp;
//        }
//        src = NULL;
//    }
//}
//
//int MRPacketListNodeCount(MRPacketList *header)
//{
//    if (NULL == header) {
//        return 0;
//    } else {
//        int sum = 0;
//
//        do {
//            sum ++;
//        } while (NULL != (header = header->next));
//
//        return sum;
//    }
//}
//
//void MRPacketListPush(MRPacketList *header,AVPacket *packet)
//{
//    if (header && packet) {
//        MRPacketList *node = NULL;
//        MRPacketListNew(&node);
//        av_packet_ref(node->packet, packet);
//
//        MRPacketList *last = header;
//        while (last->next) {
//            last = last->next;
//        }
//        last->next = node;
//    }
//}
//
//AVPacket * MRPacketListPopFirst(MRPacketList **header)
//{
//    if (header) {
//        MRPacketList *list = *header;
//        if(list){
//            AVPacket *packet = list->packet;
//            *header = list->next;
//            //free(list);
//            return packet;
//        }
//    }
//    return NULL;
//}
