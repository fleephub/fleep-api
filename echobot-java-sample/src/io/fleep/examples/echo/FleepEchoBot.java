package io.fleep.examples.echo;
import io.fleep.examples.echo.request.LoginRequest;
import io.fleep.examples.echo.request.PollRequest;
import io.fleep.examples.echo.request.SendMessageRequest;
import io.fleep.examples.echo.request.SyncRequest;

import java.io.IOException;
import java.util.Scanner;

import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;
import org.xmlpull.v1.XmlPullParserException;

/**
 * Fleep.io echo bot example
 * 
 * Replies every message in every conversation where it is added.
 * Separate account might be desired for logging into this bot.
 * 
 * See rest of the API documentation: https://fleep.io/api/describe
 * 
 */

public class FleepEchoBot {
	
	private static HttpHelper httpHelper;
	private static String ticket;
	private static String myAccountId;

	/**
	 * @param args
	 */
	public static void main(String[] args) {
		System.out.println("Fleep Echo Bot");
		System.out.println("Please enter your credentials");
		System.out.println("WARNING: it will echo every message in every conversation where this user is added!");
		System.out.print("username: ");

		Scanner userInput = new Scanner(System.in);
		String username = userInput.next();
		System.out.print("password: ");
		String password = userInput.next();
		userInput.close();
		System.out.println("Logging in with " + username + "...");
		
		httpHelper = new HttpHelper();
		
		// login
		logIn(username, password);
		// request last state of events
		long eventHorizon = requestInitialEventHorizon();
		// start echo
		if (eventHorizon >= 0) {
			startEchoBot(eventHorizon);
		}
	}
	
	/**
	 * Log in the account
	 * @param email
	 * @param password
	 * @return web-ticket that is required for other requests
	 */
	private static void logIn(String email, String password) {
		LoginRequest req = new LoginRequest(email, password);
		HttpResp resp = httpHelper.doRequest(req);
		if (resp != null && resp.getResponseCode() == 200) {
			System.out.println("Login successful.");
			ticket = resp.getString("ticket");
			myAccountId = resp.getString("account_id");
		} else {
			System.out.println("Login failed.");
			System.exit(-1);
		}
	}
	
	/**
	 * Request for current event horizon.
	 * We don't want this bot to receive any history from the server, but only new messages
	 * Therefore we need to request for up to date event horizon to start the long-poll with
	 * @return current event horizon
	 */
	private static long requestInitialEventHorizon() {
		SyncRequest req = new SyncRequest(ticket);
		HttpResp resp = httpHelper.doRequest(req);
		if (resp != null && resp.getResponseCode() == 200) {
			long eventHorizon = resp.getLong("event_horizon");
			System.out.println("Initial event horizon: " + eventHorizon);
			return eventHorizon;
		}
		return -1;
	}
	
	/**
	 * Start actual echo bot
	 * It will connect to server using long poll pattern.
	 * Connection will stay alive for 90 seconds. If new events appear, server returns instantly.
	 * If no events appear, server returns empty array and client will initiate another request.
	 * @param eventHorizon
	 */
	private static void startEchoBot(long initialEventHorizon) {
		long eventHorizon = initialEventHorizon;
		while (true) {
			PollRequest req = new PollRequest(eventHorizon, ticket);
			HttpResp resp = httpHelper.doRequest(req);
			if (resp != null && resp.getResponseCode() == 200) {
				eventHorizon = resp.getLong("event_horizon");
				JSONArray list = resp.getList("stream");
				if (list != null) {
					handlePollResults(list);
				}
			} else if (resp != null && resp.getResponseCode() == 401) {
				// current credentials are not valid any more
				System.out.println("Session expired, stopping program");
				System.exit(-1);
				return;
			} else {
				System.out.println("Connection lost.. retrying in 1 minute");
				try {
					Thread.sleep(60000);
				} catch (InterruptedException e) {
				}
			}
		}
	}
	
	/**
	 * Go through the array of events returned by long poll
	 * @param stream
	 */
	private static void handlePollResults(JSONArray stream) {
		System.out.println("handlePollResults: " + stream.length());
		for (int i = 0; i < stream.length(); i++) {
			try {
				JSONObject item = stream.getJSONObject(i);
				String type = item.getString("mk_rec_type");
				// only interested in messages
				if (type.equals("message")) {
					// new message received
					replyMessage(item);
				}
			} catch (JSONException e) {
				e.printStackTrace();
			}
		}
	}
	
	/**
	 * Reply same message to the same conversation
	 * @param message
	 */
	private static void replyMessage(JSONObject message) {
		String mkMessageType = message.getString("mk_message_type");
		if (mkMessageType.equals("text")) {
			System.out.println("message received...");
			// first, some checks to make sure it's just plain message
			
			// check if it's pin or unpin event
			if (!message.isNull("tags")) {
				JSONArray tags = message.getJSONArray("tags");
				if (tags != null && tags.length() > 0) {
					if (tags.toString().contains("pin")) {
						// either pin or unpin event
						System.out.println("it's a pin, stop here");
						return;
					}
				}
			}
			// check if it is edit to some existing message
			if (!message.isNull("flow_message_nr")) {
				// flow message nr appears on edit events only
				System.out.println("it's an edit, stop here");
				return;
			}
			
			String messageAccountId = message.getString("account_id");
			if (!messageAccountId.equals(myAccountId)) {
				// only reply to messages that are not my own
				System.out.println("sending...");
				String conversationId = message.getString("conversation_id");
				String messageText = parseXmlToText(message.getString("message"));
				System.out.println("message after parsing: " + messageText);
				if (messageText != null && messageText.length() > 0) {
					sendMessage(conversationId, messageText);
				}
			} else {
				System.out.println("it's my own message, stop here");
			}
		}
	}
	
	/**
	 * messages are received in XML format.
	 * Plain text should be sent back.
	 * @return
	 */
	private static String parseXmlToText(String message) {
		System.out.println("parseXmlToText(): " + message);
		try {
			return XmlParser.parse(message);
		} catch (XmlPullParserException e) {
			e.printStackTrace();
			return null;
		} catch (IOException e) {
			e.printStackTrace();
			return null;
		}
	}
	
	/**
	 * Send message to specific conversation
	 * @param conversationId
	 * @param message
	 */
	private static void sendMessage(String conversationId, String message) {
		System.out.println("sendMessage(): " + message);
		SendMessageRequest req = new SendMessageRequest(message, conversationId, ticket);
		httpHelper.doRequest(req);
	}
}
