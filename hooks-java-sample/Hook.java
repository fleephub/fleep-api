import java.io.BufferedReader;
import java.io.IOException;
import java.io.InputStream;
import java.io.InputStreamReader;
import java.io.OutputStreamWriter;
import java.io.UnsupportedEncodingException;
import java.net.URL;
import java.net.URLEncoder;

import javax.net.ssl.HttpsURLConnection;

/**
 * 
 * Hooks:
 * Hooks is url that can be used to post directly into fleep.io chat
 * without authentication.
 * 
 * /create_hook <descr> - with optional description
 * /show_hooks - list all hooks in chat
 * /drop_hook <hook_key> - disable hook
 * 
 * For using hooks:
 * 1) create new hook in any Fleep conversation
 * 2) use /show_hooks to get hook url
 * 3) run this program
 * 
 * response code 200 indicates successful post
 *
 */

public class Hook {

	/**
	 * @param args
	 */
	public static void main(String[] args) {
		if (args.length < 2) {
			System.out.println("usage: java -jar Hook.jar [message] [hook_url]");
			return;
		}
		String message = args[0];
		String hookUrl = args[1];

		try {
			String data = URLEncoder.encode("message", "UTF-8") + "=" + URLEncoder.encode(message, "UTF-8");
			URL url = new URL(hookUrl);
			final HttpsURLConnection urlConnection = (HttpsURLConnection) url.openConnection();
			urlConnection.setReadTimeout(10000);
			urlConnection.setConnectTimeout(10000);
			urlConnection.setRequestMethod("POST");
			urlConnection.setRequestProperty("Content-Type", "application/x-www-form-urlencoded");
			urlConnection.setRequestProperty("User-Agent", "HookSenderBot");
			urlConnection.setDoInput(true);
			urlConnection.setDoOutput(true);
			urlConnection.connect();

			OutputStreamWriter wr = new OutputStreamWriter(urlConnection.getOutputStream());
			wr.write(data);
			wr.flush();

			InputStream is;
			try {
				is = urlConnection.getInputStream();
			} catch (IOException e) {
				is = urlConnection.getErrorStream();
			}
			if (is != null) {
				BufferedReader br = new BufferedReader(new InputStreamReader(is));
				StringBuilder sb = new StringBuilder();
				String line;
				while ((line = br.readLine()) != null) {
					sb.append(line);
				}
				br.close();

				System.out.println("responseCode: " + urlConnection.getResponseCode());
				System.out.println("response: " + sb.toString());

				urlConnection.disconnect();
			}
		} catch (UnsupportedEncodingException e) {
			e.printStackTrace();
		} catch (IOException e) {
			e.printStackTrace();
		}
	}
}
