package io.fleep.examples.echo.request;

import org.json.JSONException;

public class SendMessageRequest extends BaseRequest {

	public SendMessageRequest(String message, String conversationId, String ticket) {
		super("message/send/" + conversationId, ticket);
		try {
			put("message", message);
		} catch (JSONException e) {
			e.printStackTrace();
		}
	}
}
