#! /usr/bin/env python

"""Dump Fleep chat history into JSON file.

Input - config file ~/.fleep/client.ini::

    [fleep-client]
    username = xxx
    password = xxx

Output: history.json

"""

import sys
import os.path
import subprocess
import time
import logging
import re
import hashlib
import hmac
import stat
import json
import socket
import ConfigParser

from fleepclient.api import FleepApi
from fleepclient.cache import FleepCache

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

def json_encode_stable(data = None, **kwargs):
    """JSON with sorted keys, needed for tests.
    """
    data = data or kwargs
    e = json.JSONEncoder(sort_keys=True, indent=2)
    return e.encode(data)

def main():
    load_config()

    print 'Login'
    fc = FleepCache(SERVER, USERNAME, PASSWORD)
    print 'Loading contacts'
    fc.contacts.sync_all()
    print 'Loading conversations'
    for conv_id in fc.conversations:
        conv = fc.conversations[conv_id]
        print '  %s - %s' % (conv_id, conv.topic)
        conv.sync_to_first()
    data = {
        'account': {
            'account_id': fc.account['account_id'],
            'display_name': fc.account['display_name'],
        },
        'contacts': fc.contacts.contacts,
        'conversations': {},
    }
    for conv_id in fc.conversations:
        conv = fc.conversations[conv_id]
        cdata = {
            'topic': conv.topic,
            'members': conv.members,
            'messages': [],
        }
        mlist = conv.messages.keys()
        mlist.sort()
        for mnr in mlist:
            m = conv.messages[mnr]
            cdata['messages'].append(m.as_dict())
        data['conversations'][conv_id] = cdata

    fn = 'history.json'
    jsdata = json_encode_stable(data)
    with open(fn, 'w') as f:
        f.write(jsdata)
    print 'Wrote', fn

if __name__ == '__main__':
    main()

