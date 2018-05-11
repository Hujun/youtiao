# -*- coding: utf8 -*-

from {{ app_name }}.error import UNKNOWN_ERROR
from {{ app_name }}.api import GrpcAPI

class SampleAPI(GrpcAPI):

    def Error(self, req, ctx):
        raise UNKNOWN_ERROR

    # MUST define firstly in .proto file API name with
    # input and return message types
    # e.g. API named as HelloWorld
    # in .proto file should be:
    # rpc HelloWorld(<message type>) returns (<return message type>);
    # def HelloWorld(self, req, ctx):
    #     return HelloWorldMessage(wording="hello world!")

