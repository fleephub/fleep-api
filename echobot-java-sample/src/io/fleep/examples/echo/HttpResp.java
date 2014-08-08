package io.fleep.examples.echo;

import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;

public class HttpResp {
	
	private int responseCode;
	private JSONObject response;
	
	public HttpResp(int responseCode, String responseText) throws JSONException {
		try {
			this.responseCode = responseCode;
			this.response = new JSONObject(responseText);
		} catch (JSONException e) {
			e.printStackTrace();
		}
	}

	public int getResponseCode() {
		return responseCode;
	}

	public String getString(String name) {
		try {
			return response.getString(name);
		} catch (JSONException e) {
			e.printStackTrace();
			return null;
		}
	}
	
	public long getLong(String name) {
		try {
			if (response.isNull(name)) {
				return 0;
			}
			return response.getLong(name);
		} catch (JSONException e) {
			e.printStackTrace();
			return -1;
		}
	}
	
	public JSONArray getList(String name) {
		try {
			return response.getJSONArray(name);
		} catch (JSONException e) {
			e.printStackTrace();
			return null;
		}
	}
	
	public JSONObject getJSONObject(String name) {
		try {
			return response.getJSONObject(name);
		} catch (JSONException e) {
			e.printStackTrace();
			return null;
		}
	}
	
	@Override
	public String toString() {
		return "httpResponse[responseCode: " + responseCode + ", responseText: " + response.toString() + "]";
	}
}
