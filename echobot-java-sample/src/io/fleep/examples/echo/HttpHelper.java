package io.fleep.examples.echo;

import io.fleep.examples.echo.request.BaseRequest;

import java.io.BufferedOutputStream;
import java.io.BufferedReader;
import java.io.IOException;
import java.io.InputStream;
import java.io.InputStreamReader;
import java.io.OutputStream;
import java.io.UnsupportedEncodingException;
import java.net.URL;
import java.util.List;
import java.util.zip.GZIPInputStream;

import javax.net.ssl.HttpsURLConnection;

import org.json.JSONException;

public class HttpHelper {

	private static final int CONNECTION_TIMEOUT = 120000;
	private static final String USER_AGENT = "FleepEchoBot/java";
	
	private String cookie;
	
	public HttpResp doRequest(BaseRequest req) {
		HttpResp resp = null;
		try {
			byte[] outputBytes = req.toString().getBytes("UTF-8");
			URL url = new URL(req.getRequestUrl());
			System.out.println("doRequest(): " + url.toString());
			System.out.println("doRequest(): " + req.toLog());
			final HttpsURLConnection urlConnection = (HttpsURLConnection) url.openConnection();
			urlConnection.setReadTimeout(CONNECTION_TIMEOUT);
			urlConnection.setConnectTimeout(CONNECTION_TIMEOUT);
			urlConnection.setRequestMethod("POST");
			urlConnection.setRequestProperty("Content-Type", "application/json");
			urlConnection.setRequestProperty("User-Agent", USER_AGENT);
			urlConnection.setRequestProperty("Accept-Encoding", "gzip");
			urlConnection.setDoInput(true);
			urlConnection.setDoOutput(true);
			if (outputBytes != null) {
				urlConnection.setFixedLengthStreamingMode(outputBytes.length);
			}
		    
			if (cookie != null) {
				// Set cookie in request
				urlConnection.setRequestProperty("Cookie", cookie);
			}
			urlConnection.connect();
			
			if (outputBytes != null) {
				OutputStream os = new BufferedOutputStream(urlConnection.getOutputStream());
				os.write(outputBytes);
				os.flush();
				os.close();
			}

			InputStream is;
			try {
				String encoding = urlConnection.getContentEncoding();
				if (encoding != null && encoding.equals("gzip")) {
					is = new GZIPInputStream(urlConnection.getInputStream());
				} else {
					is = urlConnection.getInputStream();
				}
			} catch (IOException e) {
				is = urlConnection.getErrorStream();
			}
			if (is != null) {
				BufferedReader br = new BufferedReader(new InputStreamReader(is, "UTF-8"));
				StringBuilder sb = new StringBuilder();
				String line;
				while ((line = br.readLine()) != null) {
					sb.append(line);
				}
				br.close();
				
				resp = new HttpResp(urlConnection.getResponseCode(), sb.toString());
				
				if (resp.getResponseCode() == 200 && cookie == null) {
					// cookie was not yet initiated, so it should be login request
					List<String> cookieList = urlConnection.getHeaderFields().get("Set-Cookie");
					if (cookieList != null && cookieList.size() > 0) {
						cookie = cookieList.get(0);
					}
				}
				
				urlConnection.disconnect();
				System.out.println(resp.toString());
				return resp;
			}
		} catch (UnsupportedEncodingException e) {
			e.printStackTrace();
		} catch (IOException e) {
			e.printStackTrace();
		} catch (JSONException e) {
			e.printStackTrace();
		}
		return null;
	}
}
