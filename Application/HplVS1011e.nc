#include "HplVS1011e.h"

interface HplVS1011e
{
	/**
	 * Resets the VS1011e
	 */
	command void reset(void);
	
	/**
	 * Set a VS1011e register to a given value
	 *
	 * @param mp3Register Register to be written
	 * @param mp3Cmd Command to be written
	 * @return SUCCESS if command was successfully sent over SPI
	 */
	command error_t writeRegister(mp3_reg_t mp3Register, uint16_t mp3Cmd);

	/**
	 * Read a VS1011e register (only if MISO is attached and Ethernet disconnected)
	 * 
	 * @param mp3Register Register to be read
	 * @param value A pointer to data buffer where register content will be stored
	 * @return SUCCESS if command was successfully sent over SPI
	 */
	command error_t readRegister(mp3_reg_t mp3Register, uint16_t *value);
	
	/**
	 * Send data to the VS1011e
	 *
	 * @param data A pointer to data buffer
	 * @param len Length of message#
	 * @return SUCCESS if request was granted and sending data started
	 */
	command error_t sendData(uint8_t *data, uint16_t len);
	
	/**
	 * Notification that sending data completed
	 *
	 * @param error SUCCESS if sending completed successfully
	 */
	async event void sendDone(error_t error);
	
	/**
	 * Test if VS1011e is ready to accept new data
	 *
	 * @return FALSE if ready to accept data
	 */
	command bool isBusy(void);
}
