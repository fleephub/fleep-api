package io.fleep.examples.echo.request;

import org.json.JSONException;

public class LoginRequest extends BaseRequest {

	public LoginRequest(String email, String password) {
		super("account/login", null);
		try {
			put("email", email);
			put("password", password);
			put("remember_me", true);
		} catch (JSONException e) {
			e.printStackTrace();
		}
	}
}
