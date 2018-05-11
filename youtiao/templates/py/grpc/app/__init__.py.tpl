# -*- coding: utf8 -*-

import logging
import os
from pathlib import Path
import yaml

from raven import Client as SentryClient

from {{ app_name }}.utils.logger import init_logging
from {{ app_name }}.error import init_error

major_version = 0
minor_version = 0
patch_version = 0

__version__  = '{}.{}.{}'.format(major_version, minor_version, patch_version)

APP_BASE_DIR = Path(__file__).parent.parent.resolve()

# read config file
CONFIG_PATH = os.getenv('{{ app_name.upper() }}_CONFIG_PATH', None)
if CONFIG_PATH:
    CONFIG_PATH = Path(CONFIG_PATH)
else:
    CONFIG_PATH = APP_BASE_DIR.joinpath('config', 'default.yaml')
if not CONFIG_PATH.is_file():
    raise FileNotFoundError
with CONFIG_PATH.open() as f:
    APP_CONFIG = yaml.load(f)

# reload config by environment variables
if os.environ.get('{{ app_name | upper }}_APP_HOST'):
    APP_CONFIG['app']['host'] = os.environ.get('{{ app_name | upper }}_APP_HOST')
if os.environ.get('{{ app_name | upper }}_APP_PORT'):
    APP_CONFIG['app']['port'] = os.environ.get('{{ app_name | upper }}_APP_PORT')
if os.environ.get('{{ app_name | upper }}_APP_MAX_WORKER'):
    APP_CONFIG['app']['max_worker'] = int(os.environ.get('{{ app_name | upper }}_APP_MAX_WORKER'))
if os.environ.get('{{ app_name | upper }}_DATA_CENTER'):
    APP_CONFIG['data_center'] = int(os.environ.get('{{ app_name | upper }}_DATA_CENTER'))
if os.environ.get('{{ app_name | upper }}_SENTRY_DSN'):
    APP_CONFIG['sentry']['enabled'] = True
    APP_CONFIG['sentry']['dsn'] = os.environ.get('{{ app_name | upper }}_SENTRY_DSN')
if os.environ.get('{{ app_name | upper }}_SENTRY_ENV'):
    APP_CONFIG['sentry']['enabled'] = True
    APP_CONFIG['sentry']['environment'] = os.environ.get('{{ app_name | upper }}_SENTRY_ENV')
if os.environ.get('{{ app_name | upper }}_MYSQL_USER'):
    APP_CONFIG['mysql']['user'] = os.environ.get('{{ app_name | upper }}_MYSQL_USER')
if os.environ.get('{{ app_name | upper }}_MYSQL_PASSWORD'):
    APP_CONFIG['mysql']['password'] = os.environ.get('{{ app_name | upper }}_MYSQL_PASSWORD')
if os.environ.get('{{ app_name | upper }}_MYSQL_HOST'):
    APP_CONFIG['mysql']['host'] = os.environ.get('{{ app_name | upper }}_MYSQL_HOST')
if os.environ.get('{{ app_name | upper }}_MYSQL_PORT'):
    APP_CONFIG['mysql']['port'] = os.environ.get('{{ app_name | upper }}_MYSQL_PORT')
if os.environ.get('{{ app_name | upper }}_MYSQL_DB'):
    APP_CONFIG['mysql']['database'] = os.environ.get('{{ app_name | upper }}_MYSQL_DB')
if os.environ.get('{{ app_name | upper }}_PG_USER'):
    APP_CONFIG['postgre']['user'] = os.environ.get('{{ app_name | upper }}_PG_USER')
if os.environ.get('{{ app_name | upper }}_PG_PASSWORD'):
    APP_CONFIG['postgre']['password'] = os.environ.get('{{ app_name | upper }}_PG_PASSWORD')
if os.environ.get('{{ app_name | upper }}_PG_HOST'):
    APP_CONFIG['postgre']['host'] = os.environ.get('{{ app_name | upper }}_PG_HOST')
if os.environ.get('{{ app_name | upper }}_PG_PORT'):
    APP_CONFIG['postgre']['port'] = os.environ.get('{{ app_name | upper }}_PG_PORT')
if os.environ.get('{{ app_name | upper }}_PG_DB'):
    APP_CONFIG['postgre']['database'] = os.environ.get('{{ app_name | upper }}_PG_DB')
if os.environ.get('{{ app_name | upper }}_REDIS_PASSWORD'):
    APP_CONFIG['redis']['password'] = os.environ.get('{{ app_name | upper }}_REDIS_PASSWORD')
if os.environ.get('{{ app_name | upper }}_REDIS_HOST'):
    APP_CONFIG['redis']['host'] = os.environ.get('{{ app_name | upper }}_REDIS_HOST')
if os.environ.get('{{ app_name | upper }}_REDIS_PORT'):
    APP_CONFIG['redis']['port'] = os.environ.get('{{ app_name | upper }}_REDIS_PORT')
if os.environ.get('{{ app_name | upper }}_REDIS_DB'):
    APP_CONFIG['redis']['database'] = os.environ.get('{{ app_name | upper }}_REDIS_DB')
if os.environ.get('{{ app_name | upper }}_SQLITE_USER'):
    APP_CONFIG['sqlite']['user'] = os.environ.get('{{ app_name | upper }}_SQLITE_USER')
if os.environ.get('{{ app_name | upper }}_SQLITE_PASSWORD'):
    APP_CONFIG['sqlite']['password'] = os.environ.get('{{ app_name | upper }}_SQLITE_PASSWORD')

APP_NAME = APP_CONFIG['app']['name']

LOGGER_LEVEL_MAP = {
    'DEBUG': logging.DEBUG,
    'INFO': logging.INFO,
    'WARNING': logging.WARNING,
    'ERROR': logging.ERROR,
    'CRITICAL': logging.CRITICAL, }

init_logging()
logger = logging.getLogger(APP_NAME)
LOGGER_LEVEL = APP_CONFIG.get('logger', {}).get('console', {}).get('level', '').upper()
if not LOGGER_LEVEL_MAP.get(LOGGER_LEVEL):
    raise ValueError('Invalid logger level config of `{}`'.format(LOGGER_LEVEL))
logger.setLevel(LOGGER_LEVEL_MAP[LOGGER_LEVEL])

init_error()

SENTRY_CONFIG = APP_CONFIG.get('sentry')
if SENTRY_CONFIG and SENTRY_CONFIG.pop('enabled', False):
    SENTRY_CONFIG['release'] = __version__
    if os.getenv('SENTRY_DSN'):
        SENTRY_CONFIG['dsn'] = os.getenv('SENTRY_DSN')
    if not SENTRY_CONFIG.get('dsn'):
        raise ValueError('Missing Sentry DSN')
    sentry_cli = SentryClient(**SENTRY_CONFIG)
else:
    sentry_cli = None

