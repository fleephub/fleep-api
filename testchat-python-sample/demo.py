#! /usr/bin/env python

"""Post message to chat with specific topic.
"""

import requests
import json

# api location
HOST = "https://fleep.io"

# auth info
EMAIL = "scott.bluemount@gmail.com"
PSW = "1234"

# chat topic to find
TOPIC = "Api send test"

MESSAGE = "Hello world!"

# login
r = requests.post(HOST + "/api/account/login",
        headers = {"Content-Type": "application/json"},
        data = json.dumps({
            "email": EMAIL,
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
                "emails": EMAIL,
                "message": MESSAGE,
                "ticket": TICKET}))
r.raise_for_status()

print 'Posted'

