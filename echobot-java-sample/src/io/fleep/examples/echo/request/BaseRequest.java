package io.fleep.examples.echo.request;

import org.json.JSONException;
import org.json.JSONObject;

public class BaseRequest extends JSONObject {

	private static final String API_URL = "https://fleep.io/api/";

	private String requestUrl;

	public BaseRequest(String requestUrl, String ticket) {
		this.requestUrl = API_URL + requestUrl;
		if (ticket != null) {
			try {
				put("ticket", ticket);
			} catch (JSONException e) {
				e.printStackTrace();
			}
		}
	}

	public String getRequestUrl() {
		return requestUrl;
	}

	public String toLog() {
		if (has("password")) {
			try {
				// do not log actual password
				JSONObject json = new JSONObject(toString());
				json.put("password", "********");
				return json.toString();
			} catch (JSONException e) {
				e.printStackTrace();
			}
		}
		return toString();
	}
}
