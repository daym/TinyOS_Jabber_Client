#include <stdint.h>
#include "Keyboard.h"
interface Keyboard {
	/**
	 * Fired when a character has been entered on the keyboard
	 *
	 * @param chr ASCII value of the character entered 
	 */
	event void receivedChar(uint8_t chr);

	/** Mostly useful for cursor keys etc. Code is the scan code, shiftState the shift state flags. */
	event void keyPressed(enum Key code, uint8_t shiftState);

}
