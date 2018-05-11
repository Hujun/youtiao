# -*- coding: utf-8 -*-

import sys
import os
from pathlib import Path
base_path = Path(__file__).parent.resolve()
sys.path.append(os.path.dirname(base_path))

from http.client import HTTPConnection
from {{ app_name }} import APP_CONFIG
conn = HTTPConnection('localhost', APP_CONFIG['app']['port'])
conn.request('GET', '/api/ping')
res = conn.getresponse()
if res.status != 200:
    raise Exception('Health check failed')

