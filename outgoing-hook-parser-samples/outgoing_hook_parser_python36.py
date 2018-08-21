"""
>>> _test('outgoing1.json')
Helmo 18 August 2018 16:18
simple message
>>> _test('outgoing2.json')
Generic Webhook via hook 21 August 2018 13:47
message via hook
>>> _test('outgoing3.json')
Helmo via email 21 August 2018 13:57
Subject: test
<BLANKLINE>
message via email
<BLANKLINE>
--
Helmo
>>> _test('outgoing4.json')
Helmo 21 August 2018 14:04
message with files
https://fleep.io/file/0000000000000000000000/00/0000000000000000000000/Screen%20Shot%202018-08-03%20at%2017.17.40.png
https://fleep.io/file/0000000000000000000000/00/0000000000000000000000/Screen%20Shot%202018-08-03%20at%2017.17.26.png
https://fleep.io/file/0000000000000000000000/00/0000000000000000000000/Screen%20Shot%202018-08-03%20at%2017.15.13.png
>>> _test('outgoing5.json')
Helmo 21 August 2018 14:12
message with url https://www.google.com
"""

import json
import xml.sax
import xml.sax.handler
import datetime


"""
Usage:
    # read data (from file, request body, etc.)
    data = ...
    msg = FleepMessage.from_string(data)
    txt = msg.get_txt()
    # do whatever you want with the text
    ...
"""


class FleepXmlToTextHandler(xml.sax.handler.ContentHandler):
    def __init__(self):
        xml.sax.handler.ContentHandler.__init__(self)
        self._txt = ""
        self._skip = False

    def startElement(self, name, attrs):
        if name == 'p' and self._txt:
            self._txt += '\n\n'
        elif name == 'br':
            self._txt += '\n'
        elif name == 'a':
            self._txt += attrs.get('href')
            self._skip = True
        elif name == 'file':
            self._skip = True

    def endElement(self, name):
        self._skip = False

    def characters(self, data):
        if not self._skip:
            self._txt += data

    def ignorableWhitespace(self, data):
        if not self._skip:
            self._txt += data

    def get_txt(self):
        return self._txt


class FleepMessage():
    def __init__(self, message_json):
        self._message = message_json

    def _convert_fleep_xml_to_text(self, xml_str):
        handler = FleepXmlToTextHandler()
        xml.sax.parseString(xml_str, handler)
        return handler.get_txt()

    def _get_files(self, l_files):
        files_txt = ""
        for r_file in l_files:
            if r_file.get('mk_rec_type') == 'file':
                files_txt += "\nhttps://fleep.io{}".format(r_file.get('file_url'))
        return files_txt

    def _get_message_text(self):
        msg_txt = ""
        r_msg = self._message.get('messages', [])[0]
        msg = r_msg.get('message')
        if msg and not r_msg.get('revision_message_nr'):  # Ignore changed and deleted messages
            msg_txt = ""

            msg_subject = r_msg.get('subject')
            if msg_subject:
                msg_txt = "Subject: {}\n\n".format(msg_subject)

            msg_txt += self._convert_fleep_xml_to_text(msg)

            msg_txt += self._get_files(r_msg.get('attachments', []))

        return msg_txt

    def _get_message_header(self):
        r_msg = self._message.get('messages')[0]
        sender_name = r_msg.get('sender_name')
        if sender_name:
            username = sender_name
        else:
            hook_key = r_msg.get('hook_key')
            if hook_key:
                username = next((
                    r_hook.get('hook_name')
                    for r_hook in self._message.get('hooks', [])
                    if r_hook.get('hook_key') == hook_key))
            else:
                account_id = r_msg.get('account_id')
                username = next((
                    r_contact.get('display_name') or r_contact.get('email')
                    for r_contact in self._message.get('contacts', [])
                    if r_contact.get('account_id') == account_id))

        username_suffix = ""
        if r_msg.get('mk_message_type') in ('email', 'emailV2'):
            username_suffix = " via email"
        elif r_msg.get('hook_key'):
            username_suffix = " via hook"

        posted_time = datetime.datetime.fromtimestamp(r_msg.get('posted_time')).strftime("%d %B %Y %H:%M")

        return "{}{} {}\n".format(username, username_suffix, posted_time)

    def get_txt(self):
        return self._get_message_header() + self._get_message_text()

    @classmethod
    def from_string(cls, s):
        return cls(json.loads(s))


def _test(file_name):
    data = open("./examples/" + file_name, 'r').read()
    msg = FleepMessage.from_string(data)
    txt = msg.get_txt()
    print(txt)


if __name__ == '__main__':
    import doctest
    doctest.testmod(optionflags=doctest.NORMALIZE_WHITESPACE)
