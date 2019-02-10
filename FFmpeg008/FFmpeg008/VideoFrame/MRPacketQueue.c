//
//  MRPacketQueue.c
//  FFmpeg008
//
//  Created by Matt Reach on 2019/1/24.
//  Copyright © 2019 Awesome FFmpeg Study Demo. All rights reserved.
//

#include "MRPacketQueue.h"
#include <assert.h>
#include <stdbool.h>

int mr_packet_queue_put(MRPacketQueue *q, AVPacket *pkt)
{
    MRAVPacketList *pkt1 = malloc(sizeof(MRAVPacketList));
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
        free(pkt1);
        return true;
    }
    return false;
}
