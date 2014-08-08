package io.fleep.examples.echo.request;

public class SyncRequest extends BaseRequest {

	public SyncRequest(String ticket) {
		super("account/sync", ticket);
	}
}
