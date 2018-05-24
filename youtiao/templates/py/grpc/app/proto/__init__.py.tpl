# -*- coding: utf8 -*-

import sys
from pathlib import Path

proto_path = str(Path(__file__).parent.resolve())
if proto_path not in sys.path:
    sys.path.append(proto_path)

