#! /usr/bin/env python

"""Post message to chat with specific topic.
"""

import requests
import json

# api location
HOST = "https://fleep.io"

# auth info
FLEEP_ID = "my.test.bot"
PSW = "12345678"

# chat topic to find
TOPIC = "Api send test"

# message to post
MESSAGE = "Hello world!"

# members for new chat
MEMBERS = "scott.bluemount@fleep.ee, paul.greenlamp@fleep.ee, mary.whitecloud@fleep.ee, julie.roseplum@fleep.ee"


# login
r = requests.post(HOST + "/api/account/login",
        headers = {"Content-Type": "application/json"},
        data = json.dumps({
            "email": FLEEP_ID,
            "password": PSW}))
r.raise_for_status()
TICKET = r.json()["ticket"]
TOKEN = r.cookies["token_id"]

# initial sync via poll, find chat
event_horizon = 0
CONV_ID = None
while 1:
    r = requests.post(HOST + "/api/account/poll",
            cookies = {"token_id": TOKEN},
            headers = {"Content-Type": "application/json"},
            data = json.dumps({
                "event_horizon": event_horizon,
                "wait": False,
                "ticket": TICKET}))
    r.raise_for_status()

    # find test conversation
    res = r.json()
    for srec in res['stream']:
        if srec['mk_rec_type'] == 'conv':
            if srec['topic'] == TOPIC:
                CONV_ID = srec['conversation_id']
                break

    # fetch more data?
    if res['event_horizon'] != event_horizon:
        event_horizon = res['event_horizon']
    else:
        break

if CONV_ID:
    # send message
    r = requests.post(HOST + "/api/message/send/" + CONV_ID,
            cookies = {"token_id": TOKEN},
            headers = {"Content-Type": "application/json"},
            data = json.dumps({
                "message": MESSAGE,
                "ticket": TICKET}))
else:
    # no chat was found, create & post
    r = requests.post(HOST + "/api/conversation/create",
            cookies = {"token_id": TOKEN},
            headers = {"Content-Type": "application/json"},
            data = json.dumps({
                "topic": TOPIC,
                "emails": MEMBERS,
                "message": MESSAGE,
                "ticket": TICKET}))
r.raise_for_status()

print 'Posted'

