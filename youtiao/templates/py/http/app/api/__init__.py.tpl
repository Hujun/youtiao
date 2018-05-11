# -*- coding: utf8 -*-

from {{ app_name }}.Http import Api, Resource
from {{ app_name }}.error import UNKNOWN_ERROR

api = Api(doc='/doc')


@api.route('/ping')
class Ping(Resource):
    @api.doc(responses={200: 'Pong'})
    def get(self):
        return 'Pong'


@api.route('/error')
class Error(Resource):
    def get(self):
        raise UNKNOWN_ERROR

