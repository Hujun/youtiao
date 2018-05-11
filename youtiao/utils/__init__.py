# -*- coding: utf8 -*-

import os


def walk_path(path: str) -> None:
    """Pretty print directory tree

    Args:
        path (str): absolute dir path
    """
    for root, dirs, files in os.walk(path):
        bp = str(path).split(os.sep)
        p = root.split(os.sep)
        print((len(p) - len(bp)) * '---', os.path.basename(root))
        for file in files:
            print((len(p) - len(bp) + 1) * '---', file)


