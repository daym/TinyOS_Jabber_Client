#include <avr/pgmspace.h>
interface MP3
{
	/**
	 * Start and stop sine test
	 * @param on TRUE to start - FALSE to stop
	 * @return SUCCESS if command was successfully sent over SPI
	 */
	command error_t sineTest(bool on);
	
	/**
	 * Set volume
	 * @param volume Volume to be set
	 * @return SUCCESS if command was successfully sent over SPI
	 */
	command error_t setVolume(uint8_t volume);
	
	/**
	 * Set Stream Mode
	 * @return SUCCESS if command was successfully sent over SPI
	 */
	command error_t setStreamMode(void);
	
	/**
	 * Send data
	 * @param data A pointer to a data buffer where the data is stored (IN PROGMEM)
	 * @param len Length of the message to be sent
	 * @return SUCCESS if request was granted and sending the data started
	 */
	command error_t sendData(PGM_VOID_P data, uint16_t len);

	/**
	 * Check if VS1011e is ready to accept new data
	 * @return FALSE if VS1011e is busy or sending of data is in progress
	 	- otherwise TRUE
	 */
	command bool isBusy(void);
}
