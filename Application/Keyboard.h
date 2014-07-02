#ifndef __KEYBOARD_H
#define __KEYBOARD_H

enum Key {
	VK_INSERT = 0xE070,
	VK_HOME = 0xE06C,
	VK_PAGE_UP = 0xE07D,
	VK_DELETE = 0xE071,
	VK_END = 0xE069,
	VK_PAGE_DOWN = 0xE07A,
	VK_UP = 0xE075,
	VK_LEFT = 0xE06B,
	VK_DOWN = 0xE072,
	VK_RIGHT = 0xE074,
	VK_KP_ENTER = 0xE05A,
	VK_RETURN = 0x5A,
	VK_F1 = 0x5,
	VK_F2 = 0x6,
	VK_F3 = 0x4,
	VK_F4 = 0xC,
	VK_F5 = 0x3,
	VK_F6 = 0xB,
	VK_F7 = 0x83,
	VK_F8 = 0x0A,
	VK_F9 = 0x1,
	VK_F10 = 0x9,
	VK_F11 = 0x78,
	VK_F12 = 0x7,
	VK_ESCAPE = 0x76,
	VK_CAPS = 0x58,
	VK_LGUI = 0xE01F,
	VK_RGUI = 0xE027,
	VK_APPS = 0xE02F,
	VK_TAB = 0x0D,
	VK_BACKSPACE = 0x66,
};
enum {
	/* shift state */
	SS_LSHIFT = 1 << 0,
	SS_RSHIFT = 1 << 1,
	SS_LCTRL = 1 << 2,
	SS_RCTRL = 1 << 3,
	SS_LALT = 1 << 4,
	SS_RALT = 1 << 5,
};
#endif /* ndef __KEYBOARD_H */
