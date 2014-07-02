#include <stdint.h>
#include "buddy.h"
#include "Atm128Adc.h"

/* PF2 */

module VolumeAdcC {
        provides interface Read<uint16_t> as Read1;
	uses interface Read<uint16_t> as Read2;
	provides interface Atm128AdcConfig; /* used by AdcReadClientC */
	provides interface ResourceConfigure; /* used by AdcReadClientC */
}
implementation {	
	async command uint8_t Atm128AdcConfig.getChannel() {
		return ATM128_ADC_SNGL_ADC2;
	}
	async command uint8_t Atm128AdcConfig.getRefVoltage() {
		return ATM128_ADC_VREF_AVCC;
	}
	async command uint8_t Atm128AdcConfig.getPrescaler() {
		return ATM128_ADC_PRESCALE_128;
	}
	async command void ResourceConfigure.configure() {
	}
	async command void ResourceConfigure.unconfigure() {
	}
	event void Read2.readDone(error_t result, uint16_t val) {
		signal Read1.readDone(result, val);
	}
	command error_t Read1.read() {
		return call Read2.read();
	}
}
