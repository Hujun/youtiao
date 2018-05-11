# -*- coding: utf-8 -*-

import sys
import os
from pathlib import Path
base_path = Path(__file__).parent.resolve()
sys.path.append(os.path.dirname(base_path))

from {{ app_name }}.client import cli
from {{ app_name }}.proto.{{ app_name }}_pb2 import Null

cli.Ping(Null())

