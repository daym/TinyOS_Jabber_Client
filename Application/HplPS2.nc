interface HplPS2 {
	/**
	 * Fired when a a scan code part is received from the keyboard.
	 *
	 * @param chr scan code part received
	 */
	async event void receivedCode(uint8_t code);

}
