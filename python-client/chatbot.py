#! /usr/bin/env python

"""

Input - config file ~/.fleep/client.ini::

    [fleep-client]
    username = xxx
    password = xxx

"""

import sys
import ConfigParser
import logging
import os.path
import time
import urlparse
import uuid
import base64
import time

from fleepclient.api import FleepApi
from fleepclient.cache import FleepCache
from fleepclient.utils import convert_xml_to_text

# how to identify chat
CHAT_URL = None             # https://fleep.io/chat?cid=P6lD79k_TMSYwg8AAbX6Tg
CHAT_TOPIC = None           # 'bot-test'
CHAT_URL = 'https://fleep.io/chat?cid=P6lD79k_TMSYwg8AAbX6Tg'
CHAT_TOPIC = None           # 'bot-test'

SERVER = 'https://fleep.io'
USERNAME = None
PASSWORD = None

def load_config():
    global USERNAME, PASSWORD
    cfn = os.path.expanduser('~/.fleep/client.ini')
    s = ConfigParser.SafeConfigParser()
    s.read([cfn])
    USERNAME = s.get('fleep-client', 'username')
    PASSWORD = s.get('fleep-client', 'password')

    if not USERNAME or not PASSWORD:
        print 'Please create ~/.fleep/client.ini with username and password.'
        sys.exit(1)


def find_chat_by_topic(fc, topic):
    for conv_id in fc.conversations:
        conv = fc.conversations[conv_id]
        if conv.topic == 'bot-test':
            return conv_id
    raise Exception('chat not found')


def uuid_decode(b64uuid):
    ub = base64.urlsafe_b64decode(b64uuid + '==')
    uobj = uuid.UUID(bytes=ub)
    return str(uobj)


def process_msg(fc, chat, msg):
    if msg.mk_message_type == 'text':
        txt = convert_xml_to_text(msg.message).strip()
        print("got msg: %r" % msg.__dict__)
        chat.mark_read(msg.message_nr)
        print('text: %s' % txt)

def main():
    load_config()

    print 'Login'
    fc = FleepCache(SERVER, USERNAME, PASSWORD)
    print 'Loading contacts'
    fc.contacts.sync_all()
    print 'convs: %d' % len(fc.conversations)

    if CHAT_TOPIC:
        chat_id = find_chat_by_topic(CHAT_TOPIC)
    elif CHAT_URL:
        p = urlparse.urlparse(CHAT_URL)
        q = urlparse.parse_qs(p.query)
        chat_id = uuid_decode(q['cid'][0])
    else:
        raise Exception('need chat info')

    chat = fc.conversations[chat_id]
    print('chat_id: %s' % chat_id)

    chat_msg_nr = chat.read_message_nr
    while 1:
        while 1:
            msg = chat.get_next_message(chat_msg_nr)
            if not msg:
                break
            process_msg(fc, chat, msg)
            chat_msg_nr = msg.message_nr

        if not fc.poll():
            time.sleep(1)
            continue


if __name__ == '__main__':
    main()

