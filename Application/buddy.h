/**
 * @file buddy.h
 * @brief The header file contains the buddy data type definition.
 */

#ifndef _BUDDY_H
#define _BUDDY_H

/** @brief The maximum length of JIDs */
#define MAX_JID_LENGTH (32)
/** @brief The number of buddies to store */
#define MAX_BUDDIES (4)
/**
 * @brief The length of each text message including the terminating
 * zero character
 */
#define MAX_MESSAGE_LENGTH (81)

#define INVALID_BUDDY_ID MAX_BUDDIES


/**
 * @brief The current status of the buddy
 * @details The buddy status empty indicates an empty buddy slot. 
 * Empty buddies usually won't be propagated.
 */
typedef enum {
	BUDDY_STATUS_EMPTY = 0, BUDDY_STATUS_UNAVAILABLE,
	BUDDY_STATUS_AVAILABLE, BUDDY_STATUS_SUBSCRIBED
} buddy_status_t;

/**
 * @brief Defines a struct containing all relevant information to 
 * manage a buddy
 */
typedef struct
{
	char jid[MAX_JID_LENGTH];
	/** The last message received */
	char message[MAX_MESSAGE_LENGTH];
	buddy_status_t status;
	uint8_t activity; /* 0 nonactive. higher: more active */
	bool requestsPresenceSubscription; /* whether the buddy wants to subscribe to our presence */
	bool hasPresenceSubscription; /* whether the buddy is subscribed to our presence */
	bool gotNewMessage; /* whether we got a message that the user (presumably) hasn't seen yet */
} buddy_t;


#endif

