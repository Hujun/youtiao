# -*- coding: utf8 -*-

import json
import sys
from pathlib import Path

import grpc
from grpc._channel import _Rendezvous

from {{ app_name }}.error import (
    make_error,
    GRPC_API_UNDEFINED,
)
from {{ app_name }} import logger


class Client(object):
    """
    Usage:
    >>> import foo_pb2.FooStub
    >>> cli = Client('FooClient', 'localhost', '1234')
    >>> cli.set_stub(foo_pb2_grpc.FooSub)
    """

    class StubWrapper(object):
        """API Error Wrapper"""
        def __init__(self, name, stub_method):
            self.name = name
            self.stub_method = stub_method

        def __call__(self, *args, **kwargs):
            try:
                return self.stub_method(*args, **kwargs)
            except _Rendezvous as e:
                if e.code() == grpc.StatusCode.INTERNAL:
                    details = json.loads(e.details())
                    error_name = '{}.error.{}'.format(self.name, details['name'])
                    logger.error(e)
                    raise make_error(
                        error_name, details['code'], details['description'], details.get('status_code', 500))
                else:
                    e = make_error('{}.error'.format(self.name), 0, '未知错误', 500)
                    logger.error(e)
                    raise e

    def __init__(self, name: str, host: str, port: int, cert_path: str=None):
        """
        Args:
            name (str): service name
            host (str): host name
            port (int): port
            cert_path (str): absolute path for certification file used for http setting
        """
        self._ssl_mode = False
        self.name = name

        if cert_path:
            with Path(cert_path).open() as f:
                self._ssl_cert = grpc.ssl_channel_credentials(f.read())
            self._ssl_mode = True
            self._chan = grpc.secure_channel('{}:{}'.format(host, port), self._ssl_cert,
                                             options=[('grpc.max_message_length', 8388608),
                                                      ('grpc.max_send_message_length', 8388608),
                                                      ('grpc.max_receive_message_length', 8388608)])
        else:
            self._chan = grpc.insecure_channel('{}:{}'.format(host, port),
                                               options=[('grpc.max_message_length', 8388608),
                                                        ('grpc.max_send_message_length', 8388608),
                                                        ('grpc.max_receive_message_length', 8388608)])


    def set_stub(self, stub):
        self.stub = stub(self._chan)

    def __getattr__(self, m):
        try:
            stub_method = getattr(self.stub, m)
        except AttributeError:
            raise GRPC_API_UNDEFINED
        if callable(stub_method):
            return self.StubWrapper(self.name, stub_method)

