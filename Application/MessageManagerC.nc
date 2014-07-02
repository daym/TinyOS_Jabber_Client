#include <stdlib.h>
#include <stdint.h>
#include <string.h>
#include <errno.h>
#include <ctype.h>
#include "ip.h"
#include "printf.h"
#include "buddy.h"
#include "debug.h"
#include "udp_config.h"
#ifdef WLAN
#include "wlan.h"
#endif
#define MAX_DATA 700 /* Byte. Because of (possible) escaping, this can be at least six times larger than you would expect ("&apos;"). */

module MessageManagerC {
        provides interface MessageManager;
	uses interface Boot;
	uses interface UdpSend;
	uses interface UdpReceive;
	uses interface SplitControl as Control;
	uses interface IpControl;
	uses interface BufferedLcd as LCD2;
#ifdef WLAN
	uses interface WlanControl;
#endif
}
implementation {
	buddy_t buddies[MAX_BUDDIES]; /* by ID */
	buddy_status_t presenceStatus = BUDDY_STATUS_EMPTY; /* my own */
	int buddiesCount = 0;
	bool inited = FALSE;
	event void Boot.booted() {
		in_addr_t *ip;
#ifdef CUSTOM_IP_SETTINGS
		in_addr_t cip = { .bytes {IP_LOCAL}};
		in_addr_t cnm = { .bytes {NETMASK}};
		in_addr_t cgw = { .bytes {GATEWAY}};
		call IpControl.setIp(&cip);
		call IpControl.setNetmask(&cnm);
		call IpControl.setGateway(&cgw);
#endif
		ip = call IpControl.getIp();
#ifdef WLAN
		call WlanControl.setSSID(SSID);
		call WlanControl.setSecurityType(SECURITY_TYPE_WPA);
		call WlanControl.setPassphrase(WPA2_PASSPHRASE);
		call WlanControl.setWirelessMode(WIRELESS_MODE_INFRA);
#endif
		call Control.start();
	}

	event void Control.stopDone(error_t error) {

	}


	event void UdpSend.sendDone(error_t error) {
		debug("sendDone: %d", error);
	}

	const uint8_t* datachr(const uint8_t* s, uint8_t c) {
		for(; *s != 0; ++s)
			if(*s == c)
				return s;
		return NULL;
	}
	int datancmp(const uint8_t* s1, const char* s2, int len) {
		return strncmp((const char*) s1, s2, len);
	}
	int datalen(const uint8_t* s) {
		int result = 0;
		for(; *s != 0; ++s, ++result)
			;
		return result;
	}
	/* like strcpy */
	void datacpy(uint8_t* dest, const char* src) {
		for(; *src != 0; ++src, ++dest)
			*dest = (uint8_t) *src;
	}

	/** finds the given XML Tag in haystack. Returns a pointer to the text right behind the tag name.
	    Example result:
	       <hello world="bar">
	             ^
	*/ 
	const uint8_t* findXMLTag(const char* tag, const uint8_t* haystack) {
		int taglen = strlen(tag);
		if(haystack != NULL) while(haystack[0] != 0) {
			while(*haystack != 0 && *haystack != '<')
				++haystack;
			if(*haystack == 0)
				break;
			++haystack;
			if(datancmp(haystack, tag, taglen) == 0 && (isspace(haystack[taglen]) || haystack[taglen] == '>'))
				return &haystack[taglen];
			else { /* false positive */
				++haystack;
			}
		}
		return NULL;
	}
	/** skips a quoted string.
	    Example result:
	      "foo"
	           ^ */
	const uint8_t* skipXMLQuotedString(const uint8_t* haystack) {
		uint8_t c = haystack[0];
		if(c == '"' || c == '\'') {
			++haystack;
			while(haystack[0] != 0 && haystack[0] != c)
				++haystack;
			if(haystack[0] == c)
				return ++haystack;
			else
				return NULL;
		} else 
			return NULL;
	}
	/** skips an attribute. If it encounters a '>', stops there.
	    Example result:
	     foo="bar"
                      ^
	 */
	const uint8_t* skipXMLAttribute(const uint8_t* haystack) {
		while(isspace(*haystack))
			++haystack;
		while(*haystack != 0 && *haystack != '=' && *haystack != '>')
			++haystack;
		if(*haystack == '>')
			return haystack;
		if(*haystack == '=')
			++haystack;
		return skipXMLQuotedString(haystack);
	}
	/** finds the given XML Attribute in haystack. Returns a pointer to the text right behind the equals sign after the attribute name.
	    Assumes that haystack was retrieved by findXMLTag. 
	    Example result:
	      bar="baz" baz="quoox"
	                    ^
	 */
	const uint8_t* getXMLAttribute(const char* name, const uint8_t* haystack) {
		int namelen = strlen(name);
		while(haystack != NULL && haystack[0] != 0 && haystack[0] != '>') {
			while(isspace(haystack[0]))
				++haystack;
			if(datancmp(haystack, name, namelen) == 0 && haystack[namelen] == '=')
				return &haystack[namelen] + strlen("=");
			else
				haystack = skipXMLAttribute(haystack);
		}
		return NULL;
	}
	/** Gets the xml node's children.
	    Assumes that haystack was retrieved by findXMLTag.
	    Example result:
	       bar="baz" baz="quoox">hello world
	                             ^
	 */
	const uint8_t* getXMLChildren(const uint8_t* haystack) {
		if(haystack == NULL)
			return NULL;
		while(*haystack != '>' && *haystack != 0)
			haystack = skipXMLAttribute(haystack);
		/*for(; *haystack != 0 && *haystack != '>'; ++haystack)
			;*/
		if(*haystack != 0)
			++haystack;
		return haystack;
	}
	/** Given an XML Attribute Value
	      "foo"
	    checks whether it's equals to a given value. Note that value is just supposed to be something like
	      foo
	  */
	bool isXMLAttributeValueEqual(const char* value, const uint8_t* haystack) {
		if(haystack[0] == '"' || haystack[0] == '\'') {
			int valuelen = strlen(value);
			char c = haystack[0];
			++haystack;
			return datancmp(haystack, value, valuelen) == 0 && haystack[valuelen] == c;
		} else
			return FALSE;
	}
	/** copies text from src to destination, unescaping xml as we go. srclen does not include 0 terminator. 
	    destination must have at least (srclen + 1) space. */
	void unescape_strpcpy(char* destination, const uint8_t* src, int srclen) {
#if 0
		memcpy(destination, src, srclen);
		destination[srclen] = 0;
#endif
		uint8_t c;
		for(; *src != 0 && srclen > 0; --srclen, ++destination) {
			c = *src;
			if(c == '&') {
				++src;
				if(datancmp(src, "amp;", strlen("amp;")) == 0)
					c = (uint8_t) '&';
				else if(datancmp(src, "lt;", strlen("lt;")) == 0)
					c = (uint8_t) '<';
				else if(datancmp(src, "gt;", strlen("gt;")) == 0)
					c = (uint8_t) '>';
				else if(datancmp(src, "apos;", strlen("apos;")) == 0)
					c = (uint8_t) '\'';
				else if(datancmp(src, "quot;", strlen("quot;")) == 0)
					c = (uint8_t) '"';
				else
					break;
				while(*src != (uint8_t) ';' && *src != 0)
					++src;
				if(*src != 0) /* skip ';' */
					++src;
			} else 
				++src;
			*destination = (char) c;
		}
		*destination = 0;
	}
	/** Extracts text node's text. destinationAllocation is the size of the destination space including the 0 byte.
	    Example result (in destination):
	      blah
	 */
	error_t copyXMLText(const uint8_t* haystack, char* destination, size_t destinationAllocation) {
		const uint8_t* text = haystack;
		const uint8_t* textend;
		if(text == NULL)
			return FAIL;
		for(textend = text; *textend != (uint8_t) '<' && *textend != 0; ++textend)
			;
		if(*textend != 0) {
			int textlen = textend - text;
			if(textlen <= destinationAllocation - 1) {
				unescape_strpcpy(destination, text, textlen);   
				destination[textlen] = 0;
				return SUCCESS;
			}
		}
		return FAIL;
	}
	/** Extracts attribute's value. destinationAllocation is the size of the destination space including the 0 byte.
	    Example result:
	      blah
	 */
	error_t copyXMLAttributeValue(const uint8_t* haystack, char* destination, size_t destinationAllocation) {
		const uint8_t* text = haystack;
		const uint8_t* textend;
		char c;
		if(text == NULL)
			return FAIL;
		c = text[0];
		if(c == '"' || c == '\'') {
			++text;
			textend = datachr(text, c);
			if(textend != NULL) {
				int textlen = textend - text;
				if(textlen <= destinationAllocation - 1) {
					unescape_strpcpy(destination, text, textlen);
					return SUCCESS;
				}
			}
		}
		return FAIL;
	}

#ifdef WLAN
	event void WlanControl.lostConnection() {
		debug("lost connection");
	}
#endif

	uint8_t getBuddyByName(const char* name) {
		int i;
		int nameEndpos;
		if(name == NULL)
			return INVALID_BUDDY_ID;
		nameEndpos = strlen(name);
		if(nameEndpos > MAX_JID_LENGTH - 1)
			return INVALID_BUDDY_ID;
		for(i = 0; i < MAX_BUDDIES; ++i) {
			buddy_t* buddy = &buddies[i];
			if(buddy->status != BUDDY_STATUS_EMPTY) {
				if(strcmp(name, buddy->jid) == 0)
					return i;
			}
		}
		return INVALID_BUDDY_ID;
	}
	/* create a buddy. Must not exist beforehand. nameEtc is the part of the xml text where the buddy name starts. 
	   If there's no space left, drops oldest buddy. */
	uint8_t createBuddy(const char* name) {
		int i;
		uint8_t min_activity = 0;
		uint8_t min_activity_i = 0;
		const char* nameEnd = strchr(name, '"');
		int nameEndpos = (nameEnd != NULL) ? nameEnd - name : strlen(name);
		if(nameEndpos > MAX_JID_LENGTH - 1)
			return INVALID_BUDDY_ID;
		for(i = 0; i < MAX_BUDDIES; ++i) {
			buddy_t* buddy = &buddies[i];
			if(buddy->status == BUDDY_STATUS_EMPTY) {
				buddy->requestsPresenceSubscription = FALSE;
				buddy->hasPresenceSubscription = FALSE;
				buddy->gotNewMessage = FALSE;
				buddy->activity = MAX_BUDDIES - 1; /* for now has maximum activity */
				buddy->status = BUDDY_STATUS_UNAVAILABLE;
				memcpy(buddy->jid, name, nameEndpos);
				buddy->jid[nameEndpos] = 0;
				memset(buddy->message, 0, MAX_MESSAGE_LENGTH);
				return i;
			}
		}
		/* Note: here, everything is full */
		/* find the least active buddy */
		for(i = 0; i < MAX_BUDDIES; ++i) {
			buddy_t* buddy = &buddies[i];
			if(buddy->status != BUDDY_STATUS_EMPTY) {
				if(buddy->activity < min_activity) {
					min_activity = buddy->activity;
					min_activity_i = i;
				}
			}
		}
		/* Note: min_activity should have ended up being 0 */
		for(i = 0; i < MAX_BUDDIES; ++i) {
			buddy_t* buddy = &buddies[i];
			/* (activity - 1) modulus MAX_BUDDIES */
			if(i != min_activity_i)
				--buddy->activity; /* scroll all the existing entries since now the "most inactive" slot got free */
		}
		if(min_activity_i != -1) { /* should be */
			buddy_t* buddy = &buddies[min_activity_i];
			buddy->status = BUDDY_STATUS_UNAVAILABLE;
			buddy->requestsPresenceSubscription = FALSE;
			buddy->hasPresenceSubscription = FALSE;
			buddy->gotNewMessage = FALSE;
			buddy->activity = MAX_BUDDIES - 1; /* for now has maximum activity */
			memcpy(buddy->jid, name, nameEndpos);
			buddy->jid[nameEndpos] = 0;
			memset(buddy->message, 0, MAX_MESSAGE_LENGTH);
			return min_activity_i;
		} else
			return INVALID_BUDDY_ID;
	}

	/* ensures that the given buddy exists. */
	uint8_t ensureBuddyExists(const char* name) {
		uint8_t buddyID = getBuddyByName(name);
		if(buddyID == INVALID_BUDDY_ID)
			buddyID = createBuddy(name);
		return buddyID;
	}

	command buddy_t* MessageManager.getBuddy(uint8_t buddyID) {
		return (buddyID >= MAX_BUDDIES) ? NULL : (buddies[buddyID].status != BUDDY_STATUS_EMPTY) ? &buddies[buddyID] : NULL;
	}
	error_t sendXML(uint8_t* data) {
		static in_addr_t destination = { .bytes {IP_JABBER_GW}};
		return call UdpSend.send(&destination, UDP_REMOTE_PORT, data, datalen(data));
	}
	/* special printf version that does escaping.
	   It supports the format specifiers:
		%as  for text inside attributes. The attribute is assumed to be delimited by single quotes, i.e. foo='%as'.
	        %ms  for text nodes. Example: <bar>textnode</bar>
	   result_alloc is the size of the output buffer (including 0 terminator).
	*/
	int xvsnprintf(uint8_t* result, size_t result_alloc, const char* format, va_list args) {
		size_t result_sz = 0;
		uint8_t f;
		do {
			f = *format;
			if(f == '%') {
				bool isXMLContent = FALSE;
				bool isAttributeContent = FALSE;
				++format;
				if(*format == 'a') {
					isXMLContent = TRUE;
					isAttributeContent = TRUE;
					++format;
				} else if(*format == 'm') {
					isXMLContent = TRUE;
					++format;
				} else if(*format == '%') {
					if(result_sz < result_alloc) {
	                                        *result = f;
	                                        ++result;
	                                        ++result_sz;
	                                }
					++format;
					continue;
				}

				if(*format == 's') {
					const char* arg = va_arg(args, const char*);
					++format;
					if(isXMLContent) {
						for(; *arg != 0; ++arg) {
							uint8_t a = (uint8_t) *arg;
							switch(a) {
							case '<':
								if(result_sz + strlen("&lt;") < result_alloc) {
									datacpy(result, "&lt;");
									result += strlen("&lt;");
									result_sz += strlen("&lt;");
								}
								break;
							case '>':
								if(result_sz + strlen("&gt;") < result_alloc) {
									datacpy(result, "&gt;");
									result += strlen("&gt;");
									result_sz += strlen("&gt;");
								}
								break;
							case '&':
								if(result_sz + strlen("&amp;") < result_alloc) {
									datacpy(result, "&amp;");
									result += strlen("&amp;");
									result_sz += strlen("&amp;");
								}
								break;
							case '"':
								if(result_sz + strlen("&quot;") < result_alloc) {
									datacpy(result, "&quot;");
									result += strlen("&quot;");
									result_sz += strlen("&quot;");
								}
								break;
							case '\'':
								if(result_sz + strlen("&apos;") < result_alloc) {
									datacpy(result, "&apos;");
									result += strlen("&apos;");
									result_sz += strlen("&apos;");
								}
								break;
							default:
								/*if(isAttributeContent && a == '\'') {
									if(result_sz + strlen("&apos;") < result_alloc) {
										datacpy(result, "&apos;");
										result += strlen("&apos;");
										result_sz += strlen("&apos;");
									}
									break;
								} else*/ if(result_sz < result_alloc) {
									*result = a;
									++result;
									++result_sz;
								}
							}
						}
					} else {
						for(; *arg != 0; ++arg) {
							if(result_sz < result_alloc) {
								*result = *arg;
								++result;   
								++result_sz;
							}
						}
					}
				} else { /* unknown format specifier */
					errno = EINVAL;
					return -1;
				}
			} else {
				if(result_sz < result_alloc) {
					*result = f;
					++result;
					++result_sz;
				}
				++format;
			}
		} while(f != 0);
		return result_sz;
	}
	int xsnprintf(uint8_t* result, size_t result_alloc, const char* format, ...) {
		int status;
		va_list args;
		va_start(args, format);
		status = xvsnprintf(result, result_alloc, format, args);
		va_end(args);
		return status;
	}
	command error_t MessageManager.sendPresenceSubscriptionAck(const char* destination_jid) {
		static uint8_t data[MAX_DATA];
		int status;
		if(destination_jid == NULL)
			return FAIL;
		debug("SENDING ACK");
		status = xsnprintf(data, MAX_DATA, "<presence from='%as@jmcvl.tilab.tuwien.ac.at' to='%as@jmcvl.tilab.tuwien.ac.at' type='subscribed'></presence>", JABBER_USERNAME, destination_jid);
		if(status == -1)
			return FAIL;
		if(status >= MAX_DATA)
			return ESIZE;
		{ /* Note: this assumes that the sending of the Ack succeeds */
			uint8_t buddy_id = getBuddyByName(destination_jid);
			buddy_t* buddy = call MessageManager.getBuddy(buddy_id);
			if(buddy != NULL) {
				debug("RESETTING requestsPresenceSubscription");
				buddy->requestsPresenceSubscription = FALSE;
				buddy->hasPresenceSubscription = TRUE;
			}
		}
		return sendXML(data);
	}
	error_t login() {
		uint8_t data[MAX_DATA];
		int status = xsnprintf(data, MAX_DATA, "<presence></presence>");
		if(status == -1)
			return FAIL;
		if(status >= MAX_DATA)
			return ESIZE;
		return sendXML(data);
	}
	event void Control.startDone(error_t error) { /* Ethernet started */
		if(!inited) {
			inited = TRUE;
			login();
		}
	}
	command error_t MessageManager.sendMessage(uint8_t buddyID, char* text) {
		buddy_t* buddy = call MessageManager.getBuddy(buddyID);
		static uint8_t data[MAX_DATA];
		int status;
		if(buddy == NULL)
			return FAIL;
		/* if there is a presence subscription request from the contact, acknowledge it as soon as we send a message */
		if(buddy->requestsPresenceSubscription) {
			debug("requestsPresenceSubscription was set");
			call MessageManager.sendPresenceSubscriptionAck(buddy->jid);
		}
		status = xsnprintf(data, MAX_DATA, "<message from='%as@jmcvl.tilab.tuwien.ac.at' to='%as@jmcvl.tilab.tuwien.ac.at' type='chat'><body>%ms</body></message>", JABBER_USERNAME, buddy->jid, text);
		if(status == -1)
			return FAIL;
		if(status >= MAX_DATA)
			return ESIZE;
		return sendXML(data);
	}
	/*void debugL(char* data) {
		call LCD2.goTo(0,1);
		if(data == NULL)
			data = "?";
		else
			data[31] = 0;
		call LCD2.write(data);
	}*/

	/* "foo@bar" -> "foo" */
	static void cutDomain(char* destination) {
		char* x = strchr(destination, '@');
		if(x != NULL)
			*x = 0;
	}
	event void UdpReceive.received(in_addr_t *srcIp, uint16_t srcPort, uint8_t *data, uint16_t len) {
		const uint8_t* presence;
		const uint8_t* message;
		char sender_jid[MAX_JID_LENGTH + 30]; /* and domain */
		char receiver_jid[MAX_JID_LENGTH + 30]; /* and domain */
		uint8_t sender_id;
		buddy_t* sender_buddy;
		data[len] = 0;
		/*printf("%s", data);*/
		presence = findXMLTag("presence", data);
		message = findXMLTag("message", data);
		if(presence != NULL) {
			const uint8_t* type = getXMLAttribute("type", presence);
			if(copyXMLAttributeValue(getXMLAttribute("from", presence), sender_jid, sizeof(sender_jid)) != SUCCESS)
				return;
			if(copyXMLAttributeValue(getXMLAttribute("to", presence), receiver_jid, sizeof(receiver_jid)) != SUCCESS)
				return;
			if(strcmp(sender_jid, receiver_jid) != 0) { /* don't add myself */
				cutDomain(sender_jid);
				cutDomain(receiver_jid);
				sender_id = ensureBuddyExists(sender_jid);
				sender_buddy = call MessageManager.getBuddy(sender_id);
				if(sender_buddy != NULL && strcmp(receiver_jid, JABBER_USERNAME) == 0) {
					if(type != NULL && isXMLAttributeValueEqual("subscribe", type)) { /* someone else want's to subscribe to my status */
						uint8_t rstatus;
						debug("SETTING requestsPresenceSubscription");
						if(!sender_buddy->hasPresenceSubscription) {
							sender_buddy->requestsPresenceSubscription = TRUE;
							sender_buddy->gotNewMessage = TRUE; /* to make user look at "message" from system */
							rstatus = signal MessageManager.subscriptionRequest(sender_buddy->jid);
						} else
							rstatus = 1;
						if(rstatus != 0) { /* wants to allow */
							call MessageManager.sendPresenceSubscriptionAck(sender_buddy->jid);
						}
					} else if(type != NULL && isXMLAttributeValueEqual("unsubscribe", type)) {
						sender_buddy->hasPresenceSubscription = FALSE;
					} else {
						if(type == NULL)
							sender_buddy->status = BUDDY_STATUS_AVAILABLE;
						else if(isXMLAttributeValueEqual("available", type))
							sender_buddy->status = BUDDY_STATUS_AVAILABLE;
						else if(isXMLAttributeValueEqual("unavailable", type))
							sender_buddy->status = BUDDY_STATUS_UNAVAILABLE;
						signal MessageManager.presenceUpdated(sender_id, sender_buddy);
					}
				}
			}
		}
		if(message != NULL) {
			const uint8_t* body = findXMLTag("body", message);
			if(copyXMLAttributeValue(getXMLAttribute("from", message), sender_jid, sizeof(sender_jid)) != SUCCESS)
				return;
			if(copyXMLAttributeValue(getXMLAttribute("to", message), receiver_jid, sizeof(receiver_jid)) != SUCCESS)
				return;
			cutDomain(sender_jid);
			cutDomain(receiver_jid);
			sender_id = ensureBuddyExists(sender_jid);
			sender_buddy = call MessageManager.getBuddy(sender_id);
			if(body != NULL && sender_buddy != NULL && strcmp(receiver_jid, JABBER_USERNAME) == 0) {
				const uint8_t* text = getXMLChildren(body);
				if(copyXMLText(text, sender_buddy->message, MAX_MESSAGE_LENGTH) == SUCCESS) {
					sender_buddy->gotNewMessage = TRUE;
					signal MessageManager.messageReceived(sender_id, sender_buddy);
				}
			}
		}
	}
	command void MessageManager.markMessageSeen(buddy_t* buddy) {
		buddy->gotNewMessage = FALSE;
	}
}
