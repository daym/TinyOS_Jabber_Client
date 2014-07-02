#include <ctype.h>
module KeyboardC {
	uses interface HplPS2;
	provides interface Keyboard;
	provides interface Init;
	uses interface AsyncQueue<uint16_t> as Buffer;
}
implementation {
	enum {
		/* states */
		S_INITIAL,
		S_E0,
		S_F0,
		S_E0_F0,
	};
#define SHIFTED_MAP { \
		[0x1C] = 'A',\
		[0x32] = 'B',\
		[0x21] = 'C',\
		[0x23] = 'D',\
		[0x24] = 'E',\
		[0x2B] = 'F',\
		[0x34] = 'G',\
		[0x33] = 'H',\
		[0x43] = 'I',\
		[0x3B] = 'J',\
		[0x42] = 'K',\
		[0x4B] = 'L',\
		[0x3A] = 'M',\
		[0x31] = 'N',\
		[0x44] = 'O',\
		[0x4D] = 'P',\
		[0x15] = 'Q',\
		[0x2D] = 'R',\
		[0x1B] = 'S',\
		[0x2C] = 'T',\
		[0x3C] = 'U',\
		[0x2A] = 'V',\
		[0x1D] = 'W',\
		[0x22] = 'X',\
		[0x35] = 'Y',\
		[0x1A] = 'Z',\
		[0x45] = ')',\
		[0x16] = '!',\
		[0x1E] = '@',\
		[0x26] = '#',\
		[0x25] = '$',\
		[0x2E] = '%',\
		[0x36] = '^',\
		[0x3D] = '&',\
		[0x3E] = '*',\
		[0x46] = '(',\
		[0x0E] = '~',\
		[0x4E] = '_',\
		[0x5D] = '|',\
		[0x29] = ' ',\
		[0x54] = '{',\
		[0x55] = '+',\
		[0x5B] = '}',\
		[0x4C] = ':',\
		[0x52] = '"',\
		[0x41] = '<',\
		[0x49] = '>',\
		[0x4A] = '?',\
		[0x61] = '>', /* German keyboard */}
	static uint8_t PROGMEM asciiFromScan[4][256] = {
		[0] = {
			[0x1C] = 'a',
			[0x32] = 'b',
			[0x21] = 'c',
			[0x23] = 'd',
			[0x24] = 'e',
			[0x2B] = 'f',
			[0x34] = 'g',
			[0x33] = 'h',
			[0x43] = 'i',
			[0x3B] = 'j',
			[0x42] = 'k',
			[0x4B] = 'l',
			[0x3A] = 'm',
			[0x31] = 'n',
			[0x44] = 'o',
			[0x4D] = 'p',
			[0x15] = 'q',
			[0x2D] = 'r',
			[0x1B] = 's',
			[0x2C] = 't',
			[0x3C] = 'u',
			[0x2A] = 'v',
			[0x1D] = 'w',
			[0x22] = 'x',
			[0x35] = 'y',
			[0x1A] = 'z',
			[0x45] = '0',
			[0x16] = '1',
			[0x1E] = '2',
			[0x26] = '3',
			[0x25] = '4',
			[0x2E] = '5',
			[0x36] = '6',
			[0x3D] = '7',
			[0x3E] = '8',
			[0x46] = '9',
			[0x0E] = '`',
			[0x4E] = '-',
			[0x5D] = '\\',
			[0x29] = ' ',
			[0x54] = '[',
			[0x55] = '=',
			[0x5B] = ']',
			[0x4C] = ';',
			[0x52] = '\'',
			[0x41] = ',',
			[0x49] = '.',
			[0x4A] = '/',
			[0x61] = '<', /* German keyboard */
		},
		[SS_LSHIFT] = SHIFTED_MAP,
		[SS_RSHIFT] = SHIFTED_MAP,
		[SS_LSHIFT|SS_RSHIFT] = SHIFTED_MAP};
	volatile uint8_t state; /* for decoding */
	volatile uint8_t shiftState;
	command error_t Init.init() {
		atomic {
			state = S_INITIAL;
		}
		return SUCCESS;
	}
	uint8_t updateShiftState(uint16_t code) {
		switch(code) {
		case 0x11:
			shiftState |= SS_LALT;
			break;
		case 0x12:
			shiftState |= SS_LSHIFT;
			break;
		case 0x59:
			shiftState |= SS_RSHIFT;
			break;
		case 0x14:
			shiftState |= SS_LCTRL;
			break;
		case 0xE011:
			shiftState |= SS_RALT;
			break;
		case 0xE014:
			shiftState |= SS_RCTRL;
			break;
		case 0x0F11:
			shiftState &=~ SS_LALT;
			break;
		case 0x0F12:
			shiftState &=~ SS_LSHIFT;
			break;
		case 0x0F59:
			shiftState &=~ SS_RSHIFT;
			break;
		case 0x0F14:
			shiftState &=~ SS_LCTRL;
			break;
		case 0xF011:
			shiftState &=~ SS_RALT;
			break;
		case 0xF014:
			shiftState &=~ SS_RCTRL;
			break;
		}
		return shiftState;
	}
	bool breakCodeP(uint16_t code) {
		return (code & 0xF000) == 0xF000 || (code & 0xFF00) == 0x0F00;
	}
	task void enqueued() {
		uint16_t receivedData;
		uint8_t xshiftState;
		atomic {
			if(!call Buffer.empty()) {
				receivedData = call Buffer.dequeue();
				xshiftState = updateShiftState(receivedData);
			} else
				return;
		}
		{
			/* TODO if there are more maps for different shift states, just remove &3 and increase asciiFromScan size to 64 */
			uint8_t asciiCode = (receivedData < 256) ? pgm_read_byte(&asciiFromScan[xshiftState&3][receivedData]) : 
			                    (receivedData >= 0xE000 && receivedData < 0xE100) ? 0/*asciiFromScan[xshiftState&3][0x100 | (receivedData & 0xFF)]*/ : 
			                    0;
			if(!breakCodeP(receivedData)) {
				signal Keyboard.keyPressed(receivedData, xshiftState);
				if(asciiCode != 0)
					signal Keyboard.receivedChar(asciiCode);
			}
		}
	}
	async event void HplPS2.receivedCode(uint8_t code) {
		atomic {
			switch(state) {
			case S_INITIAL:
				if(code == 0xE0)
					state = S_E0;
				else if(code == 0xF0)
					state = S_F0;
				else {
					call Buffer.enqueue(code);
					post enqueued();
					state = S_INITIAL;
				}
				break;
			case S_E0:
				if(code == 0xF0) { /* break */
					state = S_E0_F0;
				} else { /* extended key make code */
					call Buffer.enqueue(0xE000 | code);
					post enqueued();
					state = S_INITIAL;
				}
				break;
			case S_F0:
				call Buffer.enqueue(0x0F00 | code);
				post enqueued();
				state = S_INITIAL;
				break;
			case S_E0_F0:
				/* extended break code */
				call Buffer.enqueue(0xF000 | code);
				post enqueued();
				state = S_INITIAL;
				break;				
			}
		}
	}
}
