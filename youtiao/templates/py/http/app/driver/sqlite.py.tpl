# -*- coding:utf-8 -*-

from sqlite3 import dbapi2 as sqlite

from sqlalchemy import create_engine

from {{ app_name }} import APP_BASE_DIR
from {{ app_name }}.driver import (
    make_session,
    gen_commit_deco,
)
from {{ app_name }} import APP_CONFIG

try:
    SQLITE_CONFIG = APP_CONFIG['sqlite']
except KeyError:
    raise KeyError('Sqlite config not found')
try:
    sqlite_user = SQLITE_CONFIG['user']
    sqlite_password = SQLITE_CONFIG['password']
except KeyError:
    raise KeyError('Sqlite config not found')

engine = create_engine('sqlite+pysqlite:///{}/db.sqlite3'.format(APP_BASE_DIR), module=sqlite)
session = make_session(engine)
# DB commit decorator
db_commit = gen_commit_deco(session)

