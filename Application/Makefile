COMPONENT=JabberClientAppC

PFLAGS += -I${TOSDIR}/chips_ecs/atm1280/spi -I${TOSDIR}/chips_ecs/enc28j60

include $(MAKERULES)

ifndef JABBER_USERNAME
JABBER_USERNAME = $(shell id -un)
endif

PFLAGS += -DJABBER_USERNAME='"$(JABBER_USERNAME)"'
#CFLAGS += -DDEBUG

