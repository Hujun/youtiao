# -*- coding: utf8 -*-

import functools
import threading
import json
import time
import inspect
import os.path
from concurrent import futures
from pathlib import Path
from importlib import import_module

import grpc

from {{ app_name }} import logger, sentry_cli
from {{ app_name }}.error import BaseError, UNKNOWN_ERROR, GRPC_API_UNDEFINED
from {{ app_name }}.utils import pb2dict
from {{ app_name }} import APP_CONFIG
from {{ app_name }}.api import GrpcAPI
from {{ app_name }}.proto import {{ app_name }}_pb2_grpc
from {{ app_name }}.proto.{{ app_name }}_pb2_grpc import {{ app_name }}Servicer
from {{ app_name }}.proto.{{ app_name }}_pb2 import Null, Pong


_ONE_DAY_IN_SECONDS = 60 * 60 * 24
request_info = threading.local()
exc_info_format = '{}.{}[{:.3f}][{}][{}]'


def grpc_wrapper(cls):
    """Wrap errors and finalize DB sessions"""

    def request_wrapper(func):
        @functools.wraps(func)
        def wrapper(req, ctx):
            st = time.time()
            msg = json.dumps(pb2dict(req))
            try:
                res = func(req, ctx)
            except Exception as e:
                # handle exception
                et = time.time()
                if isinstance(e, BaseError):
                    # service raised error
                    e_msg = e.jsonify()
                    exc_info = exc_info_format.format(cls.__name__, func.__name__, et - st, msg, e_msg)
                    request_info.data = exc_info
                    logger.error(exc_info)
                    if sentry_cli:
                        sentry_cli.captureException()
                    ctx.set_code(grpc.StatusCode.INTERNAL)
                    ctx.set_details(e_msg)
                    return Null()
                elif isinstance(e, NotImplementedError):
                    e_msg = GRPC_API_UNDEFINED.jsonify()
                    exc_info = exc_info_format.format(cls.__name__, func.__name__, et - st, msg, e_msg)
                    request_info.data = exc_info
                    logger.error(exc_info)
                    if sentry_cli:
                        sentry_cli.captureException()
                    ctx.set_code(grpc.StatusCode.INTERNAL)
                    ctx.set_details(e_msg)
                    return Null()
                else:
                    # other error
                    exc_info = exc_info_format.format(cls.__name__, func.__name__, et - st, msg, e)
                    request_info.data = exc_info
                    logger.error(exc_info)
                    if sentry_cli:
                        sentry_cli.captureException()
                    raise
            else:
                et = time.time()
                exc_info = exc_info_format.format(cls.__name__, func.__name__, et -  st, '', '')
                request_info.data = exc_info
                logger.info(exc_info)

            finally:
                if 'mysql' in APP_CONFIG:
                    from {{ app_name }}.driver.mysql import session as MySQLSession
                    MySQLSession.close()
                if 'postgre' in APP_CONFIG:
                    from {{ app_name }}.driver.postgre import session as PostgreSession
                    PostgreSession.close()
                if 'sqlite' in APP_CONFIG:
                    from {{ app_name }}.driver.sqlite import session as SqliteSession
                    SqliteSession.close()

            return res

        return wrapper

    class ClassWrapper(object):

        def __init__(self, *args, **kwargs):
            self.instance = cls(*args, **kwargs)

        def __getattr__(self, k):
            try:
                v = super(ClassWrapper, self).__getattribute__(k)
            except AttributeError:
                pass
            else:
                return v
            v = getattr(self.instance, k)
            v = request_wrapper(v)
            setattr(self, k, v)
            return v

    return ClassWrapper


api_path = Path(__file__).parent.joinpath('api')
api_mixins = []
for f in api_path.iterdir():
    fname = f.name
    if fname == '__init__.py' or fname.startswith('__'):
        continue
    module_name = fname.split('.')[0]
    module = import_module('{{ app_name }}.api.{}'.format(module_name))
    for m in dir(module):
        cc = getattr(module, m)
        if inspect.isclass(cc):
            if issubclass(cc, GrpcAPI) and cc.__name__ != 'GrpcAPI':
                api_mixins.append(cc)
api_mixins.append({{ app_name }}Servicer)


@grpc_wrapper
class {{ app_name }}GRPCServer(*api_mixins):
    def Ping(self, req, ctx):
        return Pong(pong='pong from {{ app_name }}')


def run(host: str, port: int, max_worker: int, key_path: str=None, cert_path: str=None) -> None:
    """
    Args:
        host (str): hostname
        port (int): port
        max_worker (int): number of workers
        key_path (str): optional absolute path of ssl key file for https setting
        cert_path (str): optional absolute path of certificate file for https setting
    """
    srv = grpc.server(futures.ThreadPoolExecutor(max_workers=max_worker))
    {{ app_name }}_pb2_grpc.add_{{ app_name }}Servicer_to_server({{ app_name }}GRPCServer(), srv)
    wording = 'with insecure channel'
    if key_path and cert_path:
        with open(key_path) as key_file:
            with open(cert_path) as certificate_file:
                credentials = grpc.ssl_server_credentials(
                    [(key_file.read(), certificate_file.read())])
        srv.add_secure_port('{}:{}'.format(host, port), credentials)
        wording = 'with SSL channel'
    else:
        srv.add_insecure_port('{}:{}'.format(host, port))
    srv.start()
    logger.info('{{ app_name }} GRPC server %s started on %i with %i workers!' % (wording, port, max_worker))
    try:
        while 1:
            time.sleep(_ONE_DAY_IN_SECONDS)
    except KeyboardInterrupt:
        srv.stop(0)
        logger.info('{{ app_name }} GRPC server stopped')

