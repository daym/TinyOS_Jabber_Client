#ifndef __HPLVS1011E_H__
#define __HPLVS1011E_H__

typedef enum {
	OP_WRITE= 0x02,
	OP_READ	= 0x03,
} opcode_t;

typedef enum {
	CLOCKF	= 0x03,
	MODE	= 0x00,
	VOL	= 0x0b,
} mp3_reg_t;

#endif
