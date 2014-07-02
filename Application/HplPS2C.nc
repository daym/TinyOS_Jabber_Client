module HplPS2C {
	uses interface GeneralIO as DataPort;
	uses interface GeneralIO as ClockPort;

	uses interface HplAtm128Interrupt as ClockInterrupt;
	provides interface HplPS2;
	provides interface Init;
}
implementation {
	/* PS/2 data arrives LSB first */
	enum {
		B_START = 0,
		B_PARITY = 9,
		B_STOP = 10,
	};
	volatile uint16_t receivedData;
	volatile uint8_t bitIndex;
	command error_t Init.init() {
		atomic {
			bitIndex = 0;
			receivedData = 0;
		}
		call DataPort.set();
		call DataPort.makeInput();
		call ClockPort.set();
		call ClockPort.makeInput();
		call ClockInterrupt.clear();
		call ClockInterrupt.edge(FALSE); /* falling edge */
		call ClockInterrupt.enable();
		return SUCCESS;
	}
	async event void ClockInterrupt.fired() {
		/*call ClockInterrupt.disable();*/
		atomic {
			uint8_t value = call DataPort.get();
			if(bitIndex == 0) {
				if (value != 0) /* skip junk until the start bit */
					return;
				receivedData = 0;
			}
			receivedData |= value << bitIndex;
			++bitIndex;
			if(bitIndex == 11) {
				uint8_t parity = 1, i;
				for(i = 1; i <= 8; ++i)
					if((receivedData & (1 << i)) != 0)
						parity ^= 1;
				bitIndex = 0;
				// receivedData&1 start bit
				// 1<<1 .. 1<<8 data bits
				// 1<<9 parity bit (odd)
				// 1<<10 stop bit. always 1
				if((receivedData & (1 << B_STOP)) != 0 && ((receivedData & (1 << B_PARITY)) >> B_PARITY) == parity) /* stop bit is set */ {
					receivedData = (receivedData >> 1) & 0xFF; /* just the payload */
					signal HplPS2.receivedCode(receivedData);
				}
			}
		}
	}
}
/*
 Steps the host must follow to send data to a PS/2 device:

    1)   Bring the Clock line low for at least 100 microseconds.
    2)   Bring the Data line low.
    3)   Release the Clock line.
    4)   Wait for the device to bring the Clock line low.
    5)   Set/reset the Data line to send the first data bit
    6)   Wait for the device to bring Clock high.
    7)   Wait for the device to bring Clock low.
    8)   Repeat steps 5-7 for the other seven data bits and the parity bit
    9)   Release the Data line.
    10) Wait for the device to bring Data low.
    11) Wait for the device to bring Clock  low.
    12) Wait for the device to release Data and Clock

 All data is transmitted one byte at a time and each byte is sent in a frame consisting of 11-12 bits.  These bits are:

    1 start bit.  This is always 0.
    8 data bits, least significant bit first.
    1 parity bit (odd parity).
    1 stop bit.  This is always 1.
    1 acknowledge bit (host-to-device communication only)

*/
