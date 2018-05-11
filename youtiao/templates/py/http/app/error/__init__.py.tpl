# -*- coding: utf8 -*-

import sys
import json
from typing import Tuple
from pathlib import Path


class BaseError(Exception):

    def __init__(self, message: str=''):
        self.message = message

    def __str__(self):
        return 'name: {}, code: {}, description: {}, message: {}, status_code: {}'.format(
            self.name,
            self.code,
            self.description,
            self.message,
            self.status_code,
        )

    @classmethod
    def jsonify(cls):
        return json.dumps({
            'code': cls.code,
            'name': cls.name,
            'description': cls.description,
            'status_code': cls.status_code,
            'message': getattr(cls, 'message', ''),
        })


def make_error(name: str, code: int, description: str='', status_code: int=400):
    """Error factory

    Args:
        name (str): error name
        code (str): error code, should be unique in app scope
        description (str): description for error detail info
        status_code (str): http response status code

    Returns:
        Error class in type of given error name
    """
    return type(name, (BaseError,), {
        'name': name,
        'code': code,
        'description': description,
        'status_code': status_code,
    })


def init_error():
    json_path = Path(__file__).parent.joinpath('errors.json')
    error_module = sys.modules[__name__]
    if not json_path.is_file():
        raise FileNotFoundError('Error config json file not found')
    with json_path.open() as f:
        errors = json.load(f)
    code_set = set()
    for en, ec in errors.items():
        code = ec.get('code')
        if code is None:
            raise AttributeError('Error code not defined for error named {}'.format(en))
        if code in code_set:
            raise AttributeError('Error code {} is duplicated for error named {}'.format(code, en))
        description = ec.get('description', '')
        status_code = ec.get('status_code', 400)
        setattr(error_module, en, make_error(en, code, description, status_code))
        code_set.add(code)

