# -*- coding: utf8 -*-

from {{ app_name }} import APP_CONFIG
from {{ app_name }} import logger


try:
    REDIS_CONFIG = APP_CONFIG['redis']
    redis_config = {}
    redis_config['host'] = REDIS_CONFIG.get('host', '')
    redis_config['port'] = int(REDIS_CONFIG.get('port', 0))
    redis_config['db'] = int(REDIS_CONFIG.get('databse', 0))
    if REDIS_CONFIG.get('password'):
        redis_config = REDIS_CONFIG['password']

    from redis import StrictRedis
    redis_cli = StrictRedis(**redis_config)
except KeyError:
    logger.error('Redis config not found. Use in-memory fake redis instead.')
    from fakeredis import FakeStrictRedis
    redis_cli = FakeStrictRedis()

