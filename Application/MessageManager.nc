/**
 * @brief Message interface used to exchange and manage chat messages
 */

#include "buddy.h"

interface MessageManager
{

	/**
	 * @brief Signals an updated presence field
	 * @details On receiving a presence stanza the destined
	 * buddy will be updated and this event will be triggered.
	 * @param buddyID A unique identifier
	 *      between 0 and MAX_BUDDIES-1
	 * @param A pointer to the updated buddy
	 */
	event void presenceUpdated(uint8_t buddyID, buddy_t* buddy);

	/**
	 * @brief Signals a subscription request from the given JID
	 * @details The subscription request has to return the
	 *     result immediately. 
	 *     A non-zero value indicates a granted request.
	 * @param jid The jid of the requesting entity
	 * @returns The result of the request, zero on denied.
	 */
	event uint8_t subscriptionRequest(char* jid);

	/** 
	 * @brief Signals the reception of a new message
	 * @param buddyID A unique identifier
	 *     between 0 and MAX_BUDDIES-1
	 * @param A pointer to the updated buddy
	 */
	event void messageReceived(uint8_t buddyID, buddy_t* buddy);

	/**
	 * @brief Sends the given message
	 * @param If the transmitter is currently busy the request
	 *     will be discarded and an appropriate value
	 *     will be returned.
	 * @param buddyID The unique buddy identifier,
	 *     lower than MAX_BUDDIES
	 * @param message A valid pointer to the message to send
	 * @return The status of the operation
	 */
	command error_t sendMessage(uint8_t buddyID, char* message);

	/**
	 * @brief Returns the buddy from the list of known buddies
	 * @details If the buddy ID is invalid NULL will be returned
	 * @return The corresponding buddy
	 */
	command buddy_t* getBuddy(uint8_t buddyID);

	/**
	 * @brief Sends an acknowledgement for a presence subscription
	 * @param destination_jid receiver of the acknowledgement
	 * @return status of the operation
	 */
	command error_t sendPresenceSubscriptionAck(const char* destination_jid);

	/**
	 * @brief Marks the last message from buddy as seen.
	 * @param buddy
	 */
	command void markMessageSeen(buddy_t* buddy);
}
