# -*- coding: utf8 -*-

import sys
import os
from pathlib import Path
base_path = Path(__file__).parent.resolve().joinpath('{{ app_name }}')
sys.path.append(str(base_path))
sys.path.append(os.path.dirname(base_path))
sys.path.append(str(base_path.joinpath('proto')))

from gevent import monkey
monkey.patch_all()
from {{ app_name }}.Http import app
from {{ app_name }} import logger
from {{ app_name }} import APP_CONFIG

app_config = APP_CONFIG.get('app')
host = app_config.get('host', '127.0.0.1')
port = int(app_config.get('port', 8686))
max_worker = app_config.get('max_worker', 5)
key_path = app_config.get('key_path')
cert_path = app_config.get('cert_path')

if __name__ == '__main__':
    logger.debug('HTTP server started on {}:{}'.format(host, port))
    app.run(host=host, port=int(port), debug=True, threaded=True)

