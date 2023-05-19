import sys
sys.path.append('../python-client')

import random
import string
import time

from skytools import BaseScript
from fleepclient.cache import FleepCache
from fleepclient.utils import convert_xml_to_text
from twilio.rest import Client


__all__ = ['HeartBeatMonitor']

REQ_CONF_KEYS = ('server', 'username', 'password', 'heartbeat_conversation_id', 'control_conversation_id',
                 'twilio_account_sid', 'twilio_auth_token', 'twilio_from')
PING_PREFIX = 'PING '
ACK_PREFIX = 'ACK '
PING_LEN = 8
MIN_PHONE_LEN = 10
PING_INTERVAL = 60  # in seconds
PING_ALERT_TIME = 300  # in seconds

class HeartBeatMonitorException(Exception):
    """ Errors """


class HeartBeatMonitor(BaseScript):

    _fc = None
    _hb_conv = None
    _hb_conv_read_msg_nr = 0
    _control_conv = None
    _control_conv_read_msg_nr = 0
    _phones = []
    _disabled = False
    _pending_pings = {}
    _last_ping_time = None
    _last_successful_ping_time = time.time()
    _alert_pending = None
    _twilio_client = None

    def reload(self):
        super(HeartBeatMonitor, self).reload()
        for k in REQ_CONF_KEYS:
            if not self.cf.get(k):
                raise HeartBeatMonitorException("{} not configured in {}.".format(k, self.cf.filename))

        self._twilio_client = Client(self.cf.get('twilio_account_sid'), self.cf.get('twilio_auth_token'))

    def startup(self):
        super(HeartBeatMonitor, self).startup()
        self._fc = FleepCache(self.cf.get('server'), self.cf.get('username'), self.cf.get('password'))

        self._hb_conv = self._fc.conversations.get(self.cf.get('heartbeat_conversation_id'))
        if not self._hb_conv:
            raise HeartBeatMonitorException("Heartbeat conversation not found.")

        self._control_conv = self._fc.conversations.get(self.cf.get('control_conversation_id'))
        if not self._control_conv:
            raise HeartBeatMonitorException("Control conversation not found.")

        self._reload()

    def work(self):
        while self._fc.poll(False):
            pass
        self._sync_control_conv()
        self._sync_hb_conv()
        self._process_alerts()
        self._send_ping()

    def _reload(self):
        self._reset()
        self._load_phones()
        if self._phones:
            msg = 'Monitoring started, phones: {}'.format(','.join(self._phones))
            self._control_conv.message_send(msg)
            self.log.info(msg)
        else:
            self.log.warning('No phone numbers found!')
            self._disabled = True

    def _reset(self):
        self._disabled = False
        self._pending_pings = {}
        self._last_ping_time = time.time()
        self._last_successful_ping_time = time.time()
        self._alert_pending = False
        self._hb_conv_read_msg_nr = self._hb_conv.last_message_nr
        self._control_conv_read_msg_nr = self._control_conv.last_message_nr

    def _load_phones(self):
        self._control_conv.sync_pins2()
        self._phones = []
        for msg_nr in self._control_conv.pinboard:
            msg = convert_xml_to_text(self._control_conv.messages[msg_nr].message).strip()
            for ln in msg.splitlines():
                if ln.startswith('+'):
                    phone = ln.split(' ', 1)[0]
                    if len(phone) >= MIN_PHONE_LEN and phone[1:].isdigit():
                        self._phones.append(phone)

    def _sync_control_conv(self):
        while self._control_conv.last_message_nr > self._control_conv_read_msg_nr:
            msg = self._control_conv.get_next_message(self._control_conv_read_msg_nr)
            if not msg:
                break
            self._control_conv.mark_read(msg.message_nr)
            self._control_conv_read_msg_nr = msg.message_nr
            if msg.mk_message_type == 'text':
                msg_txt = convert_xml_to_text(msg.message).strip()
                self._process_control_msg(msg_txt)

    def _process_control_msg(self, msg):
        if msg.startswith('/'):
            self.log.info('Got control message: {}'.format(msg))

            reply = ''
            if msg.startswith('/broadcast '):
                self._send_alert(msg[11:])
            elif msg == '/disable':
                self._disabled = True
                reply = 'Alerts disabled'
            elif msg == '/phones':
                reply = 'Current alert phones: <{}>'.format(','.join(self._phones))
            elif msg == '/ping':
                reply = 'pong'
            elif msg == '/reset':
                self._reload()
                reply = 'Robot status reset'
            else:
                reply = 'Unrecognized command: {}'.format(msg[1:])

            if reply:
                self._control_conv.message_send(reply)

    def _sync_hb_conv(self):
        while self._hb_conv.last_message_nr > self._hb_conv_read_msg_nr:
            msg = self._hb_conv.get_next_message(self._hb_conv_read_msg_nr)
            if not msg:
                break
            self._hb_conv.mark_read(msg.message_nr)
            self._hb_conv_read_msg_nr = msg.message_nr
            if msg.mk_message_type == 'text':
                msg_txt = convert_xml_to_text(msg.message).strip()
                self.log.debug('Got hb message: {}'.format(msg_txt))
                self._process_hb_msg(msg_txt)

    def _process_hb_msg(self, msg):
        if msg.startswith(ACK_PREFIX):
            self._confirm_ack(msg[len(ACK_PREFIX):])
        elif msg.startswith(PING_PREFIX):
            self._ack_ping(msg)

    def _confirm_ack(self, ping):
        if ping.startswith(PING_PREFIX):
            ping_id = ping[len(PING_PREFIX):]
            ts = self._pending_pings.pop(ping_id, None)
            if ts:
                self.log.info(ping_id + ' confirmed')
                self._last_successful_ping_time = time.time()
                self._pending_pings = {}  # clear pending pings, we don't really care anymore

    def _ack_ping(self, ping):
        ping_id = ping[len(PING_PREFIX):]
        if ping_id not in self._pending_pings:
            self.log.info(ping_id + ' ack')
            self._hb_conv.message_send(ACK_PREFIX + ping)

    def _send_ping(self):
        if not self._disabled and not self._alert_pending:
            now = time.time()
            if not self._last_ping_time or now - self._last_ping_time > PING_INTERVAL:
                self._last_ping_time = now
                ping_id = ''.join(random.sample(string.ascii_lowercase, PING_LEN))
                ping = PING_PREFIX + ping_id
                self._pending_pings[ping_id] = now
                self.log.info(ping_id + ' send')
                self._hb_conv.message_send(ping)

    def _process_alerts(self):
        if not self._disabled and not self._alert_pending:
            if time.time() - self._last_successful_ping_time > PING_ALERT_TIME:
                self._alert_pending = True
                self._send_alert('Heartbeat failure')

    def _send_alert(self, txt):
        account = self._fc.account
        username = account.get('display_name') or account.get('fleep_address') or account.get('email') or ''
        msg = '{}: {}'.format(username, txt)
        self.log.info('Sending SMS - ' + msg)
        for nr in self._phones:
            self.log.info('Phone ' + nr)
            self._twilio_client.messages.create(to=nr, from_=self.cf.get('twilio_from'), body=msg)
