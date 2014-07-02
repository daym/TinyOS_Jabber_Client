#ifndef UDP_CONFIG_H
#define UDP_CONFIG_H

// The local udp jabber port to use
#define UDP_LOCAL_PORT	5222UL
// The udp port of the jabber gateway
#define UDP_REMOTE_PORT	5222UL

// note the ',' (instead of the usual '.') between numbers
#define IP_JABBER_GW	10,60,0,1

// If this macro is defined custom settings will be applied
#define CUSTOM_IP_SETTINGS

// the following settings are only applied if CUSTOM_IP_SETTINGS is defined
// note the ',' (instead of the usual '.') between numbers
#define IP_LOCAL 10,60,0,10
#define NETMASK	255,255,255,0
#define GATEWAY	10,60,0,1

#ifndef JABBER_USERNAME /* see Makefile */
#define JABBER_USERNAME "m0826039"
#endif

#endif
