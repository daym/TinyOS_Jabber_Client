#include <ctype.h>
module VS1011eC {
	uses interface HplVS1011e;
	provides interface MP3;
}
#define MAX_PACKET_SIZE 32 /* Byte */
implementation {
	const uint8_t* dataBeginning; /* in PROGMEM */
	uint16_t dataLen;
	uint8_t packet[MAX_PACKET_SIZE];
	command error_t MP3.sineTest(bool on) {
		call HplVS1011e.reset();
		if(on) {
			static uint8_t magic[8] = {0x53,0xef,0x6e,0xcc,0x00,0x00,0x00,0x00};
			call HplVS1011e.writeRegister(MODE, (1<<11)|(1<<5)|(1<<6));
			return call HplVS1011e.sendData(magic, sizeof(magic));
			/*return call MP3.sendData(magic, sizeof(magic));*/
		}
		//return call HplVS1011e.writeRegister(MODE, (1 << 11)|(1<<6)); /* native mode */
		return SUCCESS;
	}
	uint8_t linearLoudnessFromSlider2(uint8_t value) {
		/* return 255 (1 - (1 - x)^4) where x = value/255 */
#if 0
		double x = value/255.0;
		return 255.0*(1 - (1 - x)*(1 - x)*(1 - x)*(1 - x));
#endif
		uint16_t tmp, result;
		uint16_t numerator = (255 - value);
		numerator *= numerator;
		tmp = numerator / (64*64);
		result = 255 - tmp*tmp;
		if(value < 5)
			result = 0; /* clamp because of rounding error */
		return result;
	}
	uint8_t linearLoudnessFromSlider(uint8_t value) {
		return linearLoudnessFromSlider2(value >> 3);
	}
	command error_t MP3.setVolume(uint8_t volume) {
		uint8_t temp = linearLoudnessFromSlider(0xff - volume);
		return call HplVS1011e.writeRegister(VOL, temp | (temp << 8));
	}
	command error_t MP3.setStreamMode(void) {
		return call HplVS1011e.writeRegister(MODE, (1 << 11) | (1 << 6));
	}
	task void sendMore() {
		atomic {
			if(dataLen > 0) {
				uint16_t packetLen = dataLen < MAX_PACKET_SIZE ? dataLen : MAX_PACKET_SIZE;
				memcpy_P(packet, dataBeginning, packetLen);
				call HplVS1011e.sendData(packet, packetLen);
			}
		}
	}
	/* data is a PROGMEM address! */
	command error_t MP3.sendData(PGM_VOID_P data, uint16_t len) {
		atomic {
			dataBeginning = data;
			dataLen = len;
		}
		return post sendMore();
	}
	command bool MP3.isBusy(void) {
		return call HplVS1011e.isBusy();
	}
	async event void HplVS1011e.sendDone(error_t error) {
		if(error == SUCCESS) {
			dataBeginning += MAX_PACKET_SIZE;
			if(dataLen > MAX_PACKET_SIZE)
				dataLen -= MAX_PACKET_SIZE;
			else
				dataLen = 0;
		}
		post sendMore();
	}
}
