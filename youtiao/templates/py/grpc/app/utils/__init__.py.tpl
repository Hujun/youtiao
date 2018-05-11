# -*- coding: utf8 -*-

import re
import sys
from sys import _getframe as gf
from importlib import import_module
from six import reraise
from uuid import uuid4
from datetime import datetime
from typing import Mapping, Iterable

import pytz
from google.protobuf.message import Message as PbMessage


FIRST_CAP_RE = re.compile('(.)([A-Z][a-z]+)')
ALL_CAP_RE = re.compile('([a-z0-9])([A-Z])')
CN_MOBILE_RE = re.compile('^1[34578]\d{9}$')

LOCAL_TZ = pytz.timezone('Asia/Shanghai').localize(datetime.now()).tzinfo  # type: pytz.tzinfo.DstTzInfo
LOCAL_ZERO_DATETIME = datetime(1970, 1, 1, 8)
DEFAULT_DATETIME_FORMAT = "%Y-%m-%d %H:%M:%S"


def get_current_info():
    """Get current stack info for debug"""
    return {
        'file_name': gf().f_code.co_filename,
        'func_name': gf(0).f_code.co_name,
        'caller': gf(1).f_code.co_name,
        'line_no': gf().f_lineno,
    }


class Singleton(type):
    """
    Usage:
    class Foo(BaseFoo):
        __metaclass__ = Singleton
    """
    _instances = {}

    def __call__(cls, *args, **kwargs):
        if cls not in cls._instances:
            cls._instances[cls] = super(Singleton, cls).__call__(*args, **kwargs)
        return cls._instances[cls]


def import_string(dotted_path):
    """
    Import a dotted module path and return the attribute/class designated by the
    last name in the path. Raise ImportError if the import failed.

    Args:
        dotted_path (str): module path
    """
    try:
        module_path, class_name = dotted_path.rsplit('.', 1)
    except ValueError:
        msg = "%s doesn't look like a module path" % dotted_path
        reraise(ImportError, ImportError(msg), sys.exc_info()[2])

    module = import_module(module_path)

    try:
        return getattr(module, class_name)
    except AttributeError:
        msg = 'Module "%s" does not define a "%s" attribute/class' % (
            module_path, class_name)
        reraise(ImportError, ImportError(msg), sys.exc_info()[2])


def camel_to_dash(value: str) -> str:
    '''
    Transform a CamelCase string into a low_dashed one

    Args:
        value (str): a CamelCase string to transform
    Returns:
        low_dashed string
    '''
    first_cap = FIRST_CAP_RE.sub(r'\1_\2', value)
    return ALL_CAP_RE.sub(r'\1_\2', first_cap).lower()


def gen_uuid() -> str:
    """Generate uuid4 string in hex
    """
    return uuid4().hex


def is_mobile_cn(mobile: str):
    if CN_MOBILE_RE.match(str(mobile)):
        return True
    return False


def dt2epoch(dt):   # type: (datetime) -> float
    """Transform datetime object to epoch"""
    if dt.tzinfo is None:
        return (dt - LOCAL_ZERO_DATETIME).total_seconds()
    return (dt - datetime(1970, 1, 1, tzinfo=pytz.utc)).total_seconds()


def epoch2dt(epoch, tz=LOCAL_TZ):  # type: (float, tzinfo) -> datetime
    """Transform epoch to datetime object"""
    return datetime.fromtimestamp(epoch).replace(tzinfo=tz)


def pb2dict(msg):
    """Transform GRPC message to dict"""
    if not isinstance(msg, PbMessage):
        raise TypeError('Not a Protobuf message')
    rtn = {}
    for f in msg.DESCRIPTOR.fields:
        v = getattr(msg, f.name)
        if isinstance(v, PbMessage):
            rtn[f.name] = pb2dict(v)
        elif isinstance(v, Mapping):
            rtn[f.name] = dict((k, pb2dict(v)) for k, v in v.items())
        elif isinstance(v, Iterable) and not isinstance(v, str):
            rtn[f.name] = [pb2dict(el) for el in v]
        else:
            rtn[f.name] = v

    return rtn

