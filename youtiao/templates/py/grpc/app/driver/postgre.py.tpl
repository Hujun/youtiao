# -*- coding: utf8 -*-

from {{ app_name }}.driver import (
    make_engine,
    make_session,
    gen_commit_deco,
    db_commit_required,
)
from {{ app_name }} import APP_CONFIG

try:
    POSTGRE_CONFIG = APP_CONFIG['postgre']
except KeyError:
    raise KeyError('PostgreSQL config not found')
try:
    pg_user = POSTGRE_CONFIG['user']
    pg_password = POSTGRE_CONFIG['password']
    pg_host = POSTGRE_CONFIG['host']
    pg_port = int(POSTGRE_CONFIG['port'])
    pg_database = POSTGRE_CONFIG['database']
except KeyError:
    raise KeyError('PostgreSQL config not found')

db_scheme = 'postgresql+psycopg2'
engine = make_engine(db_scheme, pg_user, pg_password, pg_host, pg_port, pg_database)
session = make_session(engine)
# DB commit decorator
db_commit = gen_commit_deco(session)

