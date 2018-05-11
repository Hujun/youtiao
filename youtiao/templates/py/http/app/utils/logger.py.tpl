# -*- coding: utf-8 -*-

import os
import logging
import logging.config

LOGGING_CONFIG = {
    'version': 1,
    'disable_existing_loggers': False,
    'formatters': {
        'generic': {
            'format': '%(asctime)s [%(process)d] [%(levelname)s] [%(filename)s:%(lineno)d] : %(message)s',
        },
    },
    'handlers': {
        'console': {
            'level': 'INFO',
            'class': 'logging.StreamHandler',
            'formatter': 'generic',
        },
    },
    'loggers': {
        '': {
            'handlers': ['console'],
            'level': 'INFO',
            'propagate': True,
        },
    }
}

DEFAULT_LOGGERS = [
    'requests.packages.urllib3.connectionpool',
    'urllib3.connectionpool',
]

DEFAULT_LEVEL = logging.ERROR

def init_logging() -> None:
    logging.config.dictConfig(LOGGING_CONFIG)
    for logger_name in DEFAULT_LOGGERS:
        logger = logging.getLogger(logger_name)
        logger.setLevel(DEFAULT_LEVEL)

