/**
 * @author:	Andreas Hagmann <ahagmann@ecs.tuwien.ac.at>
 * @date:	12.12.2011
 *
 * based on an implementation of Harald Glanzer, 0727156 TU Wien
 */

#include "udp.h"

module UdpTransceiverP {
	provides interface PacketSender<udp_queue_item_t>;
	provides interface UdpReceive[uint16_t port];
	uses interface IpSend;
	uses interface IpReceive;
	uses interface IcmpSend;
	uses interface IpPacket;
}

implementation {
	udp_packet_t packet;
	/* for unreachable */
	in_addr_t rsrcIp;
	uint16_t rsrcPort;
	uint8_t rdata[8 + sizeof(ip_header_t) + 4] = {0}; /* RFC 792 */
	bool sendingResponse = FALSE;
	
	command error_t PacketSender.send(udp_queue_item_t *item) {
		// create udp packet
		
		packet.header.srcPort = item->srcPort;
		packet.header.dstPort = item->dstPort;
		packet.header.len = item->dataLen + sizeof(udp_header_t);
		memcpy(&(packet.data), item->data, item->dataLen);
		
		return call IpSend.send(&(item->dstIp), (uint8_t*)&(packet), packet.header.len);
	}

	task void sendUnreachable() {
                call IcmpSend.send(&rsrcIp, 3, 3, rdata, sizeof(rdata));
	}
	default event void UdpReceive.received[uint16_t port](in_addr_t *srcIp, uint16_t srcPort, uint8_t *data, uint16_t len) { /* default event handler if we do not know what to do with this UDP packet */
		ip_packet_t* rpacket;
		if(!sendingResponse) {
			memcpy(&rsrcIp, srcIp, sizeof(*srcIp));
			rsrcPort = srcPort;
			rpacket = call IpPacket.getPacket();
			if(rpacket != NULL) {
				memcpy(rdata + 4, rpacket, sizeof(rdata) - 4);
				sendingResponse = TRUE;
				post sendUnreachable();
			}
		}
	}
	
	event void IcmpSend.sendDone(error_t error) {
		sendingResponse = FALSE;
	}
	
	event void IpReceive.received(in_addr_t *srcIp, uint8_t *data, uint16_t len) {
		udp_packet_t *p = (udp_packet_t*)data;
		
		signal UdpReceive.received[p->header.dstPort](srcIp, p->header.srcPort, (uint8_t*)&(p->data), p->header.len - sizeof(udp_header_t));
	}

	event void IpSend.sendDone(error_t error) {
		signal PacketSender.sendDone(error);
	}
}
