/**
 * @author:	Andreas Hagmann <ahagmann@ecs.tuwien.ac.at>
 * @date:	12.12.2011
 *
 * based on an implementation of Harald Glanzer, 0727156 TU Wien
 */

module PingP {
	uses interface IcmpReceive;
	uses interface IcmpSend;
}

implementation {
	uint8_t srcData[522];
	uint16_t srcDataLen;
	in_addr_t srcIp;
	bool sendingPong = FALSE;
	task void sendPong() {
		call IcmpSend.send(&srcIp, 0, 0, srcData, srcDataLen); // packet->header.len - sizeof(icmp_header_t));
	}
	event void IcmpReceive.received(in_addr_t *xsrcIp, uint8_t code, uint8_t *data, uint16_t len) { /* received an ICMP echo request */
		if(!sendingPong) {
			/* send an ICMP echo reply */
			sendingPong = TRUE;
			memcpy(srcData, data, len);
			srcDataLen = len;
			memcpy(&srcIp, xsrcIp, sizeof(*xsrcIp));
			post sendPong();
		}
	}
	event void IcmpSend.sendDone(error_t error) {
		sendingPong = FALSE;
	}
}