#include <avr/pgmspace.h>
#include <printf.h>
#include "Timer.h"
#include "Keyboard.h"
#include "buddy.h"
#include "sounds.h"
#include "debug.h"

#define MAX_2LINE_DISPLAY_WIDTH 16
#define MAX_ENTRY_SIZE 32
#define ICON_WIDTH 8

module JabberClientC @safe() {
	uses interface Timer<TMilli> as TouchTimer;
	uses interface Timer<TMilli> as CaretBlinkTimer;
	uses interface Leds;
	uses interface Boot;
	uses interface BufferedLcd as LCD2;
	uses interface Glcd as GLCD;
	uses interface Keyboard as Keyboard;
	uses interface TouchScreen;
	uses interface MessageManager;
	uses interface Read<uint16_t> as VolumeReading;
	uses interface MP3;
}
implementation {
	uint8_t entryLine, entryCol, entryPos;
	char entry[MAX_ENTRY_SIZE];
	bool entryCaretVisible = TRUE; /* at this instant */

	uint8_t buddyID; /* selected */

	ts_coordinates_t glcdCoo;

	event void TouchTimer.fired() {
		/*debug("JabberClientC", "Timer 0 fired @ %s.\n", sim_time_string());*/
		call TouchScreen.getCoordinates(&glcdCoo);
		call VolumeReading.read();
	}
	void undrawCaret() {
		if(entryCaretVisible) {
			char cc[2] = {(entry[entryPos] != 0 ? entry[entryPos] : ' '),0};
			call LCD2.goTo(entryLine, entryCol);
			call LCD2.write(cc);
			entryCaretVisible = FALSE;
		}
	}
	/* both args in PROGMEM */
	void playSound(PGM_VOID_P src, PGM_VOID_P xlen /* 16 bit target */) {
		call MP3.sendData(src, pgm_read_word(xlen));
	}
	void drawCaret() {
		if(!entryCaretVisible) {
			char cc[2] = {'|',0};
			call LCD2.goTo(entryLine, entryCol);
			call LCD2.write(cc);
			entryCaretVisible = TRUE;
		}
	}
	event void CaretBlinkTimer.fired() {
		if(entryCaretVisible)
			undrawCaret();
		else
			drawCaret();
		call LCD2.forceRefresh();
	}
	void moveCaret(int8_t offset) {
		undrawCaret();
		if(offset < 0) {
			if(entryPos > 0) {
				--entryPos;
				if(entryCol > 0)
					--entryCol;
				else {
					entryCol = MAX_2LINE_DISPLAY_WIDTH - 1;
					if(entryLine > 0)
						--entryLine;
				}
			}
		} else if(offset > 0) {
			if(entry[entryPos] != 0) {
				++entryPos;
				++entryCol;
				if(entryCol >= MAX_2LINE_DISPLAY_WIDTH) {
					entryCol = 0;
					++entryLine;
				}
			}
		}
		drawCaret();
	}
	event void Keyboard.receivedChar(uint8_t chr) {
		if(strlen(entry) < MAX_ENTRY_SIZE - 1) {
			memmove(&entry[entryPos + 1], &entry[entryPos], MAX_ENTRY_SIZE - entryPos);
			entry[entryPos] = chr;
			call LCD2.goTo(entryLine, entryCol);
			call LCD2.write(&entry[entryPos]);
			moveCaret(1);
		}
	}
	void deleteEntryChar() {
		undrawCaret();
		memmove(&entry[entryPos], &entry[entryPos + 1], MAX_ENTRY_SIZE - (entryPos + 1));
		call LCD2.goTo(entryLine, entryCol);
		call LCD2.write(&entry[entryPos]);
		call LCD2.write(" ");
	}
	void backspaceEntryChar() {
		if(entryPos == 0)
			return;
		moveCaret(-1);
		deleteEntryChar();
	}
	void clearEntry() {
		undrawCaret();
		entryPos = entryLine = entryCol = 0;
		entry[0] = 0;
		call LCD2.clear();
	}
#define XBUDDY(buddyID) (((buddyID) == 0 || (buddyID) == 2) ? 0 : 64)
#define YBUDDY(buddyID) (((buddyID) >= 2) ? 20 : 10)
	uint8_t getHitBuddy(uint8_t x, uint8_t y) {
		if(y < 20) {
			if(y < 10)
				return x < 64 ? 0 : 1;
			else
				return x < 64 ? 2 : 3;
		} else
			return INVALID_BUDDY_ID;
	}
	void updateGUI() {
		uint8_t i;
		call GLCD.fill(0x00);
		/*debug("UPDATING GUI");*/
		for(i = 0; i < MAX_BUDDIES; ++i) {
			buddy_t* buddy = call MessageManager.getBuddy(i);
			if(buddy == NULL)
				continue;
			switch(buddy->status) {
			case BUDDY_STATUS_EMPTY:
				break;
			case BUDDY_STATUS_UNAVAILABLE:
				call GLCD.drawLine(XBUDDY(i), YBUDDY(i) - 4, XBUDDY(i) + 63, YBUDDY(i) - 4);
				break;
			case BUDDY_STATUS_AVAILABLE:
				break;
			case BUDDY_STATUS_SUBSCRIBED: /* WTF FIXME */
				break;
			}
			call GLCD.drawText(buddy->jid, XBUDDY(i) + 2 + ICON_WIDTH, YBUDDY(i));
			if(buddyID == i) { /* currently selected buddy */
				call GLCD.drawRect(XBUDDY(i), YBUDDY(i) - 7 - 2, XBUDDY(i) + 63, YBUDDY(i) + 1);
				if(buddy->gotNewMessage)
					call MessageManager.markMessageSeen(buddy); /* will reset flag */
				if(buddy->message[0] != 0)
					call GLCD.drawText(buddy->message, 0 + 2, 32);
				else if(buddy->requestsPresenceSubscription)
					call GLCD.drawText("<Requests to subscribe to your presence. Answer to subscribe>", 0 + 2, 32);
			}
			if(buddy->gotNewMessage)
				call GLCD.drawText("M", XBUDDY(i) + 2, YBUDDY(i));
		}
		call GLCD.drawLine(0, 23, 127, 23);
	}
	void sendCurrentMessage() {
		call MessageManager.sendMessage(buddyID, entry);
		updateGUI(); /* sendMessage() could have updated the "subscription requested" flag */
	}
	event void Keyboard.keyPressed(enum Key key, uint8_t shiftState) {
		switch(key) {
		case VK_LEFT:
			moveCaret(-1);
			break;
		case VK_RIGHT:
			moveCaret(1);
			break;
		case VK_RETURN:
		case VK_KP_ENTER:
			sendCurrentMessage();
			clearEntry();
			break;
		case VK_BACKSPACE:
			backspaceEntryChar();
			break;
		case VK_DELETE:
			deleteEntryChar();
			break;
		case VK_ESCAPE:
			clearEntry();
			break;
		case VK_END:
			while(entry[entryPos] != 0)
				moveCaret(1);
			break;
		case VK_HOME:
			while(entryPos > 0)
				moveCaret(-1);
			break;
		default:
			break;
		}
	}
	event void TouchScreen.coordinatesReady() {
		uint8_t xbuddyID = getHitBuddy(glcdCoo.x, glcdCoo.y);
		if(xbuddyID != buddyID && xbuddyID != INVALID_BUDDY_ID) {
			buddyID = xbuddyID;
			/* don't allow selecting EMPTY buddies */
			{
				buddy_t* buddy = call MessageManager.getBuddy(buddyID);
				if(buddy == NULL)
					buddyID = INVALID_BUDDY_ID;
			}
			updateGUI();
		}
	}
	event void Boot.booted() {
		entryLine = entryCol = entryPos = 0;
		buddyID = INVALID_BUDDY_ID;
		entry[0] = 0;
		call CaretBlinkTimer.startPeriodic(500);

		call TouchScreen.calibrate(0,-10);
		call TouchTimer.startPeriodic(100);
		call LCD2.autoRefresh(60); /* ms */
		call LCD2.clear();
		call LCD2.write("|"); /* cursor */
		call GLCD.fill(0x00);
		/*call MP3.sineTest(TRUE);*/
		/*playSound(login_mp3, &login_mp3_len);*/
		updateGUI();
	}
	event void MessageManager.presenceUpdated(uint8_t xbuddyID, buddy_t* buddy) {
		switch(buddy->status) {
		case BUDDY_STATUS_UNAVAILABLE:
			playSound(logout_mp3, &logout_mp3_len);
			break;
		case BUDDY_STATUS_AVAILABLE:
			playSound(login_mp3, &login_mp3_len);
			break;
		case BUDDY_STATUS_EMPTY: /* cannot happen */
		case BUDDY_STATUS_SUBSCRIBED: /* TODO what is this? */
		}
		updateGUI();
	}
	event uint8_t MessageManager.subscriptionRequest(char* jid) {
		updateGUI();
		return 0; /* will be manually allowed later (on sendMessage). */
	}
	event void MessageManager.messageReceived(uint8_t xbuddyID, buddy_t* buddy) {
		playSound(noti_mp3, &noti_mp3_len);
		updateGUI();
	}
	event void VolumeReading.readDone(error_t result, uint16_t val) {
		if(result == SUCCESS) {
			call MP3.setVolume(val >> 2);
		}
	}
}
