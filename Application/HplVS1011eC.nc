module HplVS1011eC {
	uses interface SpiByte as DataPort;
	uses interface SpiControl as DataControl;
	uses interface SpiPacket as DataPacket;
	uses interface GeneralIO as RSTPort;
	uses interface GeneralIO as CSPort;
	uses interface GeneralIO as DREQPort; /* high: MP3 module can receive 32 Byte data */
	uses interface GeneralIO as BSYNCPort;
	uses interface HplAtm128Interrupt as DREQInterrupt;
	uses interface Resource;
	uses interface BusyWait<TMicro,uint16_t> as ResetWaiter;
	provides interface HplVS1011e;
	provides interface Init;
}
implementation {
	uint8_t* packetData;
	uint16_t packetLen;
	command bool HplVS1011e.isBusy() {
		return !call DREQPort.get();
	}
	event void Resource.granted() {
		//static uint8_t dummy[32] = {0};
		//call DataControl.setClock(SPI_SPEED_128);
		/* TODO when board is busy, release ? */
		call BSYNCPort.clr();
		call DataPacket.send(packetData, NULL/*dummy*/, packetLen);
		/* next see DataPacket.sendDone() */
	}
	async event void DataPacket.sendDone(uint8_t* txBuf, uint8_t* rxBuf, uint16_t len, error_t error) {
		call BSYNCPort.set();
		call Resource.release();
		signal HplVS1011e.sendDone(error);
	}
	async event void DREQInterrupt.fired() {
		if(call DREQPort.get()) { /* not busy */ /* this is clear from the configuration of the interrupt */
			call Resource.request();
			call DREQInterrupt.disable();
		}
	}
	command error_t HplVS1011e.sendData(uint8_t *data, uint16_t len) {
		packetData = data;
		packetLen = len;
		if(!call DREQPort.get()) { /* busy */
			call DREQInterrupt.enable();
			return SUCCESS;
		} else  {
			return call Resource.request();
		}
	}
	command error_t HplVS1011e.writeRegister(mp3_reg_t addr, uint16_t data) {
		while(call HplVS1011e.isBusy())
			;
		if(call Resource.immediateRequest() == SUCCESS) {
			//call DataControl.setClock(SPI_SPEED_128);
			call CSPort.clr();
			call DataPort.write(OP_WRITE);
			call DataPort.write(addr);
			call DataPort.write((uint8_t)((data>>8) & 0xff));
			call DataPort.write((uint8_t)((data>>0) & 0xff));
			call CSPort.set();
			call Resource.release();
			return SUCCESS;
		} else
			return FAIL;
	}
	command error_t HplVS1011e.readRegister(mp3_reg_t addr, uint16_t *value) {
		while(call HplVS1011e.isBusy())
			;
		if(call Resource.immediateRequest() == SUCCESS) {
			//call DataControl.setClock(SPI_SPEED_128);
			call CSPort.clr();
			call DataPort.write(OP_READ);
			call DataPort.write(addr);
			*value = call DataPort.write(0xFF) << 8;
			*value |= call DataPort.write(0xFF);
			call CSPort.set();
			return SUCCESS;
		} else
			return FAIL;
	}
	command error_t Init.init(void) {
		call CSPort.makeOutput();
		call CSPort.set();
		call RSTPort.makeOutput();
		call BSYNCPort.makeOutput();
		call BSYNCPort.set();
		call DREQPort.makeInput();
		call HplVS1011e.reset();
		return SUCCESS;
	}
	command void HplVS1011e.reset(void) {
		/* Hardware reset */
		call RSTPort.clr();
		/* wait 1 ms then set again */
		call ResetWaiter.wait(1000);
		call RSTPort.set();
		call DREQInterrupt.clear();
		call DREQInterrupt.edge(TRUE); /* rising edge */
		call HplVS1011e.writeRegister(CLOCKF, 12500);
		call HplVS1011e.writeRegister(MODE, (1 << 11)); /* native mode */
		call HplVS1011e.writeRegister(VOL, 0x6000); /* takes long? */
	}
}
