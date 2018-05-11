# -*- coding: utf8 -*-

from decimal import Decimal
from datetime import datetime, timezone

from sqlalchemy import (
    Column,
    DateTime,
    String,
    BigInteger,
)
from sqlalchemy.ext.declarative import declarative_base

from {{ app_name }} import APP_CONFIG
from {{ app_name }}.utils.snowflake import gen_snowflake_id

ALLOWED_RDBMS = ('mysql', 'postgre', 'sqlite')
db_config = [i for i in ALLOWED_RDBMS if i in APP_CONFIG]
if not db_config:
    raise KeyError('Missing RDBMS config.')
if len(db_config) > 1:
    raise KeyError('More than one RDBMS config of {} found.'.format(', '.join(db_config)))
if db_config[0] == 'postgre':
    from {{ app_name }}.driver.postgre import session as DBSession
    from {{ app_name }}.driver.postgre import db_commit
    from {{ app_name }}.driver.postgre import engine
elif db_config[0] == 'mysql':
    from {{ app_name }}.driver.mysql import session as DBSession
    from {{ app_name }}.driver.mysql import db_commit
    from {{ app_name }}.driver.mysql import engine
elif db_config[0] == 'sqlite':
    from {{ app_name }}.driver.sqlite import session as DBSession
    from {{ app_name }}.driver.sqlite import db_commit
    from {{ app_name }}.driver.sqlite import engine

# Base class for SQLAlchemy defined model
DeclarativeBase = declarative_base()


class TimestampMixin(object):
    """Timestamp Mixin for SQLAlchemy Defined Models
    With columns of `created_at` for record create time and `updated_at`
    for record update time. Every model should use the mixin as best
    practise and never forget to add the two columns in corresponding
    database tables.
    """
    created_at = Column(DateTime(timezone=True), default=datetime.now(timezone.utc))
    updated_at = Column(DateTime(timezone=True), default=datetime.now(timezone.utc), onupdate=datetime.now(timezone.utc))


class MethodMixin(object):
    """Mixin for Common Used Method in Models
    It defines some table schema design protocols:
    1. Table MUST have a primary key column called `id`
    2. Table MUST have a string column named as `status`
    3. The `status` column MUST have at least two enum value to mark the
    status of `DEFAULT` and `DELETED`
    4. Model object do not offer real data delete method, but soft delete
    method to mark `status` column as `DELETED`
    """

    # to be override
    QUERY_IGNORE_FIELD = []
    DEFAULT_OFFSET = 0
    DEFAULT_LIMIT = 1000
    STATUS_DELETE = 'DELETED'
    STATUS_DEFAULT = 'DEFAULT'

    SERIALIZE_IGNORE_FIELDS = []
    PROTECT_FIELDS = []

    id = Column(BigInteger, primary_key=True, default=gen_snowflake_id, comment='primary key using unique snowflake ID')
    status = Column(String(20), default=STATUS_DEFAULT)

    @classmethod
    def get(cls, primary_id):
        q = DBSession.query(cls).filter(
            cls.id==primary_id, cls.status!=cls.STATUS_DELETE)
        return q.first()

    @classmethod
    def mget(cls, ids, include_deleted=False):
        if not ids:
            return []
        q = DBSession.query(cls).filter(cls.id.in_(ids))
        if include_deleted:
            return q
        return q.filter(cls.status!=cls.STATUS_DELETE)

    @classmethod
    def new(cls, **kwargs):
        obj = cls()
        for k, v in kwargs.iteritems():
            if k in obj.__table__.columns.keys() and v is not None:
                setattr(obj, k, v)
        DBSession.add(obj)
        return obj

    @classmethod
    def remove(cls, primary_id):
        obj = DBSession.query(cls).filter_by(id=primary_id).first()
        if obj:
            if obj.status == cls.STATUS_DELETE:
                return obj
            obj.status = cls.STATUS_DELETE
            DBSession.add(obj)
        return obj

    def update(self, **kwargs):
        cols = self.__table__.columns.keys()
        for k, v in kwargs.items():
            if k in cols and k not in self.PROTECT_FIELDS:
                setattr(self, k, v)
        DBSession.add(self)
        return self

    def serialize(self):
        """Serialize SQLAlchemy Query Set to Dict"""

        obj_dict = {}

        for f in self.__table__.columns.keys():
            if f in self.SERIALIZE_IGNORE_FIELDS:
                continue
            item = getattr(self, f)
            if isinstance(item, Decimal):
                item = float(item)
            if isinstance(item, datetime):
                item = item.strftime('%Y-%m-%dT%H:%M:%SZ%z')
            obj_dict.update({f: item})

        return obj_dict

    @classmethod
    def exist(cls, primary_id):
        q = DBSession.query(cls).filter(
            cls.id==primary_id, cls.status!=cls.STATUS_DELETE)
        return q.count() == 1

    @classmethod
    def all_exist(cls, ids):
        if not ids:
            return False
        ids = set(ids)
        q = DBSession.query(cls).filter(cls.id.in_(ids))
        return q.count() == len(ids)

    @classmethod
    def query(cls, **kwargs):
        q = DBSession.query(cls).filter(cls.status!=cls.STATUS_DELETE)

        query_fields = dict((k, v) for k, v in kwargs.items() if k not in cls.QUERY_IGNORE_FIELD and k in cls.__table__.columns.keys())
        if query_fields:
            q = q.filter_by(**query_fields)

        if isinstance(kwargs.get('ids'), (list, tuple, set)):
            q = q.filter(cls.id.in_(kwargs['ids']))

        total = q.count()

        if hasattr(cls, 'updated_at') and kwargs.get('order_by_update'):
            if kwargs.get('order_by_update') == 1:
                q = q.order_by(cls.updated_at)
            elif kwargs.get('order_by_update') == -1:
                q = q.order_by(cls.updated_at.desc())
        if hasattr(cls, 'created_at') and kwargs.get('order_by_create'):
            if kwargs.get('order_by_create') == 1:
                q = q.order_by(cls.created_at)
            elif kwargs.get('order_by_create') == -1:
                q = q.order_by(cls.created_at.desc())

        offset = kwargs.get('offset', cls.DEFAULT_OFFSET)
        limit = kwargs.get('limit', cls.DEFAULT_LIMIT)

        return q.offset(offset).limit(limit), total

