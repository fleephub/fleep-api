package io.fleep.examples.echo;

import java.io.IOException;
import java.io.StringReader;

import org.kxml2.io.KXmlParser;
import org.xmlpull.v1.XmlPullParser;
import org.xmlpull.v1.XmlPullParserException;

public class XmlParser {

	/**
	 * Used to parse XML messages into plain text
	 * 
	 * @param message - XML message
	 * @return plain text
	 * @throws XmlPullParserException
	 * @throws IOException
	 */
	public static String parse(String message) throws XmlPullParserException, IOException {
		if (message == null || message.length() == 0 || message.equals("<msg><p/></msg>")) {
			return "";
		}
		KXmlParser parser = new KXmlParser();
		StringReader reader = new StringReader(message);
		parser.setInput(reader);
		parser.nextTag();
		return readMsg(parser);
	}

	private static String readMsg(XmlPullParser parser) throws XmlPullParserException, IOException {
		parser.require(XmlPullParser.START_TAG, null, "msg");
		StringBuilder text = new StringBuilder();
		int count = 0;
		while (parser.next() != XmlPullParser.END_TAG) {
			if (parser.getEventType() != XmlPullParser.START_TAG) {
				continue;
			}
			String name = parser.getName();
			// Look for paragraphs
			if (name.equals("p")) {
				String paragraph = readParagraph(parser);
				if (count > 0 && paragraph.length() > 0) {
					text.append("\n\n");
				}
				text.append(paragraph);
			} else if (name.equals("q")) {
				String quote = readQuote(parser);
				if (count > 0 && quote.length() > 0) {
					text.append("\n\n");
				}
				text.append(quote);
			}
			count++;
		}
		parser.require(XmlPullParser.END_TAG, null, "msg");
		return text.toString();
	}

	private static String readQuote(XmlPullParser parser) throws XmlPullParserException, IOException {
		parser.require(XmlPullParser.START_TAG, null, "q");
		String text = read(parser) + "\n";
		parser.require(XmlPullParser.END_TAG, null, "q");
		return text;
	}

	private static String readParagraph(XmlPullParser parser) throws XmlPullParserException, IOException {
		parser.require(XmlPullParser.START_TAG, null, "p");
		String text = read(parser);
		parser.require(XmlPullParser.END_TAG, null, "p");
		return text;
	}

	private static String readLink(XmlPullParser parser) throws XmlPullParserException, IOException {
		parser.require(XmlPullParser.START_TAG, null, "a");
		String tag = parser.getName();
		String text = "";
		if (tag.equals("a")) {
			if (parser.next() == XmlPullParser.TEXT) {
				text = parser.getText();
				parser.nextTag();
			}
		}
		parser.require(XmlPullParser.END_TAG, null, "a");
		return text;
	}

	private static String read(XmlPullParser parser) throws XmlPullParserException, IOException {
		StringBuilder text = new StringBuilder();
		while (parser.next() != XmlPullParser.END_TAG) {
			if (parser.getEventType() != XmlPullParser.START_TAG) {
				if (parser.getEventType() == XmlPullParser.TEXT) {
					text.append(parser.getText());
				}
				continue;
			}
			String name = parser.getName();
			if (name.equals("emo")) {
				text.append(readEmo(parser));
			} else if (name.equals("br")) {
				text.append("\n");
				parser.nextTag();
			} else if (name.equals("b")) {
				text.append(readBold(parser));
			} else if (name.equals("i")) {
				text.append(readItalic(parser));
			} else if (name.equals("pre")) {
				text.append(readPre(parser));
			} else if (name.equals("q")) {
				text.append(readQuote(parser));
			} else if (name.equals("a")) {
				text.append(readLink(parser));
			} else {
				text.append(read(parser));
			}
		}
		return text.toString();
	}

	private static String readEmo(XmlPullParser parser) throws IOException, XmlPullParserException {
		parser.require(XmlPullParser.START_TAG, null, "emo");
		String tag = parser.getName();
		String text = "";
		if (tag.equals("emo")) {
			if (parser.next() == XmlPullParser.TEXT) {
				text = parser.getText();
				parser.nextTag();
			}
		}
		parser.require(XmlPullParser.END_TAG, null, "emo");
		return text;
	}

	private static String readBold(XmlPullParser parser) throws IOException, XmlPullParserException {
		parser.require(XmlPullParser.START_TAG, null, "b");
		String flp = parser.getAttributeValue(null, "flp");
		String fls = parser.getAttributeValue(null, "fls");
		StringBuilder sb = new StringBuilder();
		if (flp != null && flp.length() > 0) {
			sb.append(flp);
		}
		sb.append(read(parser));
		if (fls != null && fls.length() > 0) {
			sb.append(fls);
		}
		parser.require(XmlPullParser.END_TAG, null, "b");
		return sb.toString();
	}

	private static String readItalic(XmlPullParser parser) throws IOException, XmlPullParserException {
		parser.require(XmlPullParser.START_TAG, null, "i");
		String flp = parser.getAttributeValue(null, "flp");
		String fls = parser.getAttributeValue(null, "fls");
		StringBuilder sb = new StringBuilder();
		if (flp != null && flp.length() > 0) {
			sb.append(flp);
		}
		sb.append(read(parser));
		if (fls != null && fls.length() > 0) {
			sb.append(fls);
		}
		parser.require(XmlPullParser.END_TAG, null, "i");
		return sb.toString();
	}

	private static String readPre(XmlPullParser parser) throws IOException, XmlPullParserException {
		parser.require(XmlPullParser.START_TAG, null, "pre");
		String flp = parser.getAttributeValue(null, "flp");
		String fls = parser.getAttributeValue(null, "fls");
		StringBuilder sb = new StringBuilder();
		if (flp != null && flp.length() > 0) {
			sb.append(flp);
		}
		sb.append(read(parser));
		if (fls != null && fls.length() > 0) {
			sb.append(fls);
		}
		parser.require(XmlPullParser.END_TAG, null, "pre");
		return sb.toString();
	}
}
