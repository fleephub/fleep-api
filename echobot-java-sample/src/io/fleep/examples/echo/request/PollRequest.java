package io.fleep.examples.echo.request;

import org.json.JSONException;

public class PollRequest extends BaseRequest {

	public PollRequest(long eventHorizon, String ticket) {
		super("account/poll", ticket);
		try {
			put("event_horizon", eventHorizon);
			put("wait", true);
		} catch (JSONException e) {
			e.printStackTrace();
		}
	}
}
