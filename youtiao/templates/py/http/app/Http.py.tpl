# -*- coding: utf8 -*-

import time
import sys
import os
import re
from enum import IntEnum
from importlib import import_module

from flask import (
    Flask,
    g,
    Blueprint,
    current_app,
    request,
    url_for,
)
from flask.signals import got_request_exception
from werkzeug.contrib.fixers import ProxyFix
from werkzeug.datastructures import Headers
from werkzeug.exceptions import HTTPException
from flask_cors import CORS
from flask_restplus import (
    Api as RestplusApi,
    Resource as RestplusResource,
)
from flask_restplus.utils import unpack

from {{ app_name }} import (
    APP_NAME,
    sentry_cli,
    logger,
)
from {{ app_name }}.error import BaseError, UNKNOWN_ERROR

app = Flask(APP_NAME)
app.wsgi_app = ProxyFix(app.wsgi_app)
CORS(app, supports_credentials=True)

API_DIR = os.path.join(os.path.dirname(__file__), 'api')


class HTTPStatus(IntEnum):
    """HTTP status codes and reason phrases

    Status codes from the following RFCs are all observed:

        * RFC 7231: Hypertext Transfer Protocol (HTTP/1.1), obsoletes 2616
        * RFC 6585: Additional HTTP Status Codes
        * RFC 3229: Delta encoding in HTTP
        * RFC 4918: HTTP Extensions for WebDAV, obsoletes 2518
        * RFC 5842: Binding Extensions to WebDAV
        * RFC 7238: Permanent Redirect
        * RFC 2295: Transparent Content Negotiation in HTTP
        * RFC 2774: An HTTP Extension Framework
    """
    def __new__(cls, value, phrase, description=''):
        obj = int.__new__(cls, value)
        obj._value_ = value

        obj.phrase = phrase
        obj.description = description
        return obj

    def __str__(self):
        return str(self.value)

    # informational
    CONTINUE = 100, 'Continue', 'Request received, please continue'
    SWITCHING_PROTOCOLS = (101, 'Switching Protocols',
            'Switching to new protocol; obey Upgrade header')
    PROCESSING = 102, 'Processing'

    # success
    OK = 200, 'OK', 'Request fulfilled, document follows'
    CREATED = 201, 'Created', 'Document created, URL follows'
    ACCEPTED = (202, 'Accepted',
        'Request accepted, processing continues off-line')
    NON_AUTHORITATIVE_INFORMATION = (203,
        'Non-Authoritative Information', 'Request fulfilled from cache')
    NO_CONTENT = 204, 'No Content', 'Request fulfilled, nothing follows'
    RESET_CONTENT = 205, 'Reset Content', 'Clear input form for further input'
    PARTIAL_CONTENT = 206, 'Partial Content', 'Partial content follows'
    MULTI_STATUS = 207, 'Multi-Status'
    ALREADY_REPORTED = 208, 'Already Reported'
    IM_USED = 226, 'IM Used'

    # redirection
    MULTIPLE_CHOICES = (300, 'Multiple Choices',
        'Object has several resources -- see URI list')
    MOVED_PERMANENTLY = (301, 'Moved Permanently',
        'Object moved permanently -- see URI list')
    FOUND = 302, 'Found', 'Object moved temporarily -- see URI list'
    SEE_OTHER = 303, 'See Other', 'Object moved -- see Method and URL list'
    NOT_MODIFIED = (304, 'Not Modified',
        'Document has not changed since given time')
    USE_PROXY = (305, 'Use Proxy',
        'You must use proxy specified in Location to access this resource')
    TEMPORARY_REDIRECT = (307, 'Temporary Redirect',
        'Object moved temporarily -- see URI list')
    PERMANENT_REDIRECT = (308, 'Permanent Redirect',
        'Object moved temporarily -- see URI list')

    # client error
    BAD_REQUEST = (400, 'Bad Request',
        'Bad request syntax or unsupported method')
    UNAUTHORIZED = (401, 'Unauthorized',
        'No permission -- see authorization schemes')
    PAYMENT_REQUIRED = (402, 'Payment Required',
        'No payment -- see charging schemes')
    FORBIDDEN = (403, 'Forbidden',
        'Request forbidden -- authorization will not help')
    NOT_FOUND = (404, 'Not Found',
        'Nothing matches the given URI')
    METHOD_NOT_ALLOWED = (405, 'Method Not Allowed',
        'Specified method is invalid for this resource')
    NOT_ACCEPTABLE = (406, 'Not Acceptable',
        'URI not available in preferred format')
    PROXY_AUTHENTICATION_REQUIRED = (407,
        'Proxy Authentication Required',
        'You must authenticate with this proxy before proceeding')
    REQUEST_TIMEOUT = (408, 'Request Timeout',
        'Request timed out; try again later')
    CONFLICT = 409, 'Conflict', 'Request conflict'
    GONE = (410, 'Gone',
        'URI no longer exists and has been permanently removed')
    LENGTH_REQUIRED = (411, 'Length Required',
        'Client must specify Content-Length')
    PRECONDITION_FAILED = (412, 'Precondition Failed',
        'Precondition in headers is false')
    REQUEST_ENTITY_TOO_LARGE = (413, 'Request Entity Too Large',
        'Entity is too large')
    REQUEST_URI_TOO_LONG = (414, 'Request-URI Too Long',
        'URI is too long')
    UNSUPPORTED_MEDIA_TYPE = (415, 'Unsupported Media Type',
        'Entity body in unsupported format')
    REQUESTED_RANGE_NOT_SATISFIABLE = (416,
        'Requested Range Not Satisfiable',
        'Cannot satisfy request range')
    EXPECTATION_FAILED = (417, 'Expectation Failed',
        'Expect condition could not be satisfied')
    UNPROCESSABLE_ENTITY = 422, 'Unprocessable Entity'
    LOCKED = 423, 'Locked'
    FAILED_DEPENDENCY = 424, 'Failed Dependency'
    UPGRADE_REQUIRED = 426, 'Upgrade Required'
    PRECONDITION_REQUIRED = (428, 'Precondition Required',
        'The origin server requires the request to be conditional')
    TOO_MANY_REQUESTS = (429, 'Too Many Requests',
        'The user has sent too many requests in '
        'a given amount of time ("rate limiting")')
    REQUEST_HEADER_FIELDS_TOO_LARGE = (431,
        'Request Header Fields Too Large',
        'The server is unwilling to process the request because its header '
        'fields are too large')

    # server errors
    INTERNAL_SERVER_ERROR = (500, 'Internal Server Error',
        'Server got itself in trouble')
    NOT_IMPLEMENTED = (501, 'Not Implemented',
        'Server does not support this operation')
    BAD_GATEWAY = (502, 'Bad Gateway',
        'Invalid responses from another server/proxy')
    SERVICE_UNAVAILABLE = (503, 'Service Unavailable',
        'The server cannot process the request due to a high load')
    GATEWAY_TIMEOUT = (504, 'Gateway Timeout',
        'The gateway server did not receive a timely response')
    HTTP_VERSION_NOT_SUPPORTED = (505, 'HTTP Version Not Supported',
        'Cannot fulfill request')
    VARIANT_ALSO_NEGOTIATES = 506, 'Variant Also Negotiates'
    INSUFFICIENT_STORAGE = 507, 'Insufficient Storage'
    LOOP_DETECTED = 508, 'Loop Detected'
    NOT_EXTENDED = 510, 'Not Extended'
    NETWORK_AUTHENTICATION_REQUIRED = (511,
        'Network Authentication Required',
        'The client needs to authenticate to gain network access')


@app.before_request
def before_request_hook():
    # ignore preflight requests for CORS
    if request.method == 'OPTIONS':
        return
    # request arrive ts
    g.start_time = time.time()
    g.ua = request.headers.get('User-Agent', u'')
    g.ip = request.headers.get('X-FORWARDED-FOR', request.remote_addr)


@app.after_request
def after_request_hook(res):
    # ignore CORS preflight request
    if request.method == 'OPTIONS':
        return res
    # request end ts
    g.end_time = time.time()

    return res


class HTTPRequestValidationError(Exception):
    def __init__(self, error_data, message=None):
        self.error_data = error_data
        self.message = message or 'Input payload not valid'
        self.code = 422

    def __str__(self):
        return 'Validation error: {}'.format(self.error_data)

    __repr__ = __str__


class Resource(RestplusResource):
    pass


HEADERS_BLACKLIST = ('Content-Length',)

class Api(RestplusApi):

    def handle_error(self, e):
        '''
        Error handler for the API transforms a raised exception into a Flask response,
        with the appropriate HTTP status code and body.
        :param Exception e: the raised Exception object
        '''
        got_request_exception.send(current_app._get_current_object(), exception=e)

        headers = Headers()

        if e.__class__ in self.error_handlers:
            handler = self.error_handlers[e.__class__]
            result = handler(e)
            default_data, code, headers = unpack(result, 500)
        elif isinstance(e, HTTPException):
            code = HTTPStatus(e.code)
            default_data = {
                'message': getattr(e, 'description', code.phrase),
            }
            headers = e.get_response().headers
        elif self._default_error_handler:
            result = self._default_error_handler(e)
            default_data, code, headers = unpack(result, 500)
        elif isinstance(e, BaseError):
            default_data = {
                'message': e.name,
                'code': e.code,
                'description': e.description,
            }
            code = e.status_code
        elif isinstance(e, HTTPRequestValidationError):
            default_data = {
                'message': e.message,
                'code': e.code,
                'data': e.data,
            }
        else:
            code = 500
            default_data = {
                'message': UNKNOWN_ERROR.name,
                'code': UNKNOWN_ERROR.code,
                'description': UNKNOWN_ERROR.description,
            }

        default_data['message'] = default_data.get('message', str(e))
        data = getattr(e, 'data', default_data)
        if 'code' not in data:
            data['code'] = e.code or 0
        fallback_mediatype = None

        if code >= 500:
            exc_info = sys.exc_info()
            if exc_info[1] is None:
                exc_info = None
            current_app.log_exception(exc_info)

        elif code == 404 and current_app.config.get("ERROR_404_HELP", True):
            data['message'] = self._help_on_404(data.get('message', None))

        elif code == 406 and self.default_mediatype is None:
            # if we are handling NotAcceptable (406), make sure that
            # make_response uses a representation we support as the
            # default mediatype (so that make_response doesn't throw
            # another NotAcceptable error).
            supported_mediatypes = list(self.representations.keys())
            fallback_mediatype = supported_mediatypes[0] if supported_mediatypes else "text/plain"

        # Remove blacklisted headers
        for header in HEADERS_BLACKLIST:
            headers.pop(header, None)

        resp = self.make_response(data, code, headers, fallback_mediatype=fallback_mediatype)

        # sentry capture
        if sentry_cli:
            sentry_cli.captureException()

        return resp

    def register_resource(self, namespace, resource, *urls, **kwargs):
        endpoint = kwargs.pop('endpoint', None)
        endpoint = str(endpoint or self.default_endpoint(resource, namespace))

        kwargs['endpoint'] = endpoint
        self.endpoints.add(endpoint)

        if self.app is not None:
            self._register_view(self.app, resource, *urls, **kwargs)
        else:
            self.resources.append((resource, urls, kwargs))
        return endpoint

    def set_url_prefix(self, url_prefix: str):
        self.url_prefix = url_prefix

    def authorization_handler_setter(self, func):
        if not callable(func):
            raise Exception('Authorization handler must be function')
        self._authorization_handler = func
        return func

    @property
    def specs_url(self):
        url = url_for(self.endpoint('specs'), _external=False)
        if app.config.get('SWAGGER_BASEPATH'):
            url = '{}{}'.format(app.config.get('SWAGGER_BASEPATH'), url)
        return url


def init_api():
    PREFIX_API_MODULE_MAP = {}
    URL_MAP = {}
    URL_CLASS_MAP = {}

    for dirname, subdir_list, files in os.walk(API_DIR):
        for f in files:
            if not f.endswith('.py'):
                continue
            if f == '__init__.py':
                prefix = []
                module_path = 'api'
                title = '{} API'.format(APP_NAME)
            else:
                prefix = [os.path.splitext(f)[0]]
                sub_path = '.'.join(re.sub(API_DIR, '', dirname).split('/')[1:])
                if sub_path:
                    module_path = 'api.{}.{}'.format(sub_path, os.path.splitext(f)[0])
                else:
                    module_path = 'api.{}'.format(os.path.splitext(f)[0])
                title = '{} {} API'.format(APP_NAME, os.path.splitext(f)[0].upper())
            for d in dirname.split('/')[::-1]:
                prefix.append(d)
                if d == 'api':
                    break
            bp_prefix = '/' + '/'.join(prefix[::-1])
            try:
                api_module = import_module(module_path)
                bp = Blueprint(module_path, module_path)
                api_module.api.set_url_prefix(bp_prefix)
                api_module.api.init_app(bp, title=title)
                app.register_blueprint(bp, url_prefix=bp_prefix)
                logger.info('API at {}/{} loaded'.format(dirname, f))
            except ImportError as e:
                logger.error(e)
                continue

            PREFIX_API_MODULE_MAP[bp_prefix] = api_module

    for rule in app.url_map.iter_rules():
        URL_MAP[str(rule)] = str(rule.endpoint)

    for prefix, module in PREFIX_API_MODULE_MAP.items():
        for url in URL_MAP:
            if url.startswith(prefix):
                endpoint = URL_MAP[url]
                endpoint_name = endpoint.split('.')[-1]
                classname = ''.join(
                    map(lambda s: s.capitalize(), endpoint_name.split('_')))
                if classname in dir(module):
                    URL_CLASS_MAP[url] = getattr(module, classname)


init_api()

