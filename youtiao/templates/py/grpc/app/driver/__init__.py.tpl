# -*- coding: utf8 -*-

import functools

from threading import local
from sqlalchemy import create_engine
from sqlalchemy.orm import (
    Session,
    scoped_session,
    sessionmaker,
)


# db session context
db_ctx = local()


class SessionContext(object):
    def __init__(self, session):
        self.session = session
        self.do_commit = False

    def __enter__(self):
        register_db_commit = getattr(db_ctx, 'register_db_commit', False)
        if not register_db_commit:
            db_ctx.register_db_commit = True
            self.do_commit = True
        else:
            self.do_commit = False

    def __exit__(self, exc_type, exc_val, exc_tb):
        if self.do_commit:
            if exc_tb is None:
                try:
                    self.session().commit()
                finally:
                    db_ctx.register_db_commit = False
                    self.session().close()
            else:
                db_ctx.register_db_commit = False
                self.session().close()
        else:
            if exc_tb is None:
                self.session().flush()


def gen_commit_deco(db_session):
    """Session Commit Decorator Factory
    """
    def wrap(func_=None):
        if func_ is not None:
            @functools.wraps(func_)
            def wrapper(*args, **kwargs):
                with SessionContext(db_session):
                    result = func_(*args, **kwargs)
                return result
            return wrapper
        else:
            return SessionContext(db_session)

    return wrap


def db_commit_required(func_):
    """Decorator to ensure commitment in outter function
    """
    @functools.wraps(func_)
    def wrapper(*args, **kwargs):
        register_db_commit = getattr(db_ctx, 'register_db_commit', None)
        if not register_db_commit:
            raise RuntimeError("{} must be executed in db commit".format(func_.__name__))
        return func_(*args, **kwargs)
    return wrapper


def make_engine(scheme: str, user: str, password: str, host: str,
                port: int, database: str, charset: str=''):
    """DB Engine Factory
    A SQLAlchemy DB engine references both a `SQL Dialect` and a `Connection Pool`,
    which together interpret the `DBAPI`'s module functions as well as the behaviour
    of the database.

    Note:
        Do NOT use db engine directly. It is better to use scoped session in program.

    Args:
        schema (str): database system plus db driver name
        user (str): db login username
        password (str): db login password
        host (str): db host
        port (int): db port
        database (str): db namespace
        charset (str): charset for db session connection

    Returns:
        SQLAlchemy DB engine
    """
    default_url = ("{scheme}://{user}:{password}"
                   "@{host}:{port}/{database}")
    dsn = default_url.format(scheme=scheme, user=user, password=password,
                             host=host, port=int(port), database=database)
    if charset:
        dsn += '?charset={}'.format(charset)
    return create_engine(dsn, pool_size=10, max_overflow=-1, pool_recycle=1200)


def make_session(engine):
    """DB Session Factory
    Make thread-local session using registry pattern. The session has proxy behaviour and
    is thread safe by saving context in thread local storage.

    Args:
        engine (object): SQLAlchemy DB engine
    Returns:
        SQLAlchemy DB Session
    """
    return scoped_session(
        sessionmaker(
            class_=Session,
            expire_on_commit=False,
            autoflush=False,
            bind=engine,
        )
    )

