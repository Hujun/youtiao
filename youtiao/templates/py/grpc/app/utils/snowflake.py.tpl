# -*- coding: utf8 -*-

from random import randint
import time

from {{ app_name }}.driver.Redis import redis_cli
from {{ app_name }} import APP_CONFIG
from {{ app_name }} import APP_NAME, logger
from {{ app_name }}.utils import Singleton


DC_N = APP_CONFIG.get('data_center')
if DC_N is None:
    logger.warn('Data center number not set, use 0 as defautl value. It may cause snowflake ID duplication problem.')
    DC_N = 0
DC_N = int(DC_N)
PID_EXPIRE = 60 * 60 * 24   # process ID expire in 1 day
REDIS_KEY_PREFIX = '{}:pid:{}'.format(APP_NAME, DC_N)
EPOCH_TIMESTAMP = 550281600000


def _get_pid():
    """Generate process ID"""
    while 1:
        pid = randint(0, 255)
        k = '{}:{}'.format(REDIS_KEY_PREFIX, pid)
        if redis_cli.setnx(k, 1):
            redis_cli.expire(k, PID_EXPIRE)
            return pid


class SnowFlakeGenerator(object):
    """Global unique SnowFlake ID Generator"""
    __metaclass__ = Singleton

    def __init__(self, dc, worker):
        self.dc = dc
        self.worker = worker
        self.node_id = ((dc & 0x03)<< 8) | (worker & 0xff)
        self.last_timestamp = EPOCH_TIMESTAMP
        self.sequence = 0
        self.sequence_overload = 0
        self.errors = 0
        self.generated_ids = 0

    def get_next_id(self):
        curr_time = int(time.time() * 1000)

        if curr_time < self.last_timestamp:
            # stop handling requests til we've caught back up
            self.errors += 1
            raise Exception('Clock went backwards! %d < %d' % (curr_time, self.last_timestamp))

        if curr_time > self.last_timestamp:
            self.sequence = 0
            self.last_timestamp = curr_time

        self.sequence += 1

        if self.sequence > 4095:
            # the sequence is overload, just wait to next sequence
            logger.warning('The sequence has been overload')
            self.sequence_overload += 1
            time.sleep(0.001)
            return self.get_next_id()

        generated_id = ((curr_time - EPOCH_TIMESTAMP) << 22) | (self.node_id << 12) | self.sequence

        self.generated_ids += 1
        return generated_id

snowflake_generator = SnowFlakeGenerator(DC_N, _get_pid())


def gen_snowflake_id() -> int:
    """Generate SnowFlake Unique ID"""
    return snowflake_generator.get_next_id()


