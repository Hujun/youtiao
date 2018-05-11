# -*- coding: utf8 -*-

from {{ app_name }}.driver import (
    make_engine,
    make_session,
    gen_commit_deco,
    db_commit_required,
)
from {{ app_name }} import APP_CONFIG


try:
    MYSQL_CONFIG = APP_CONFIG['mysql']
except KeyError:
    raise KeyError('MySQL config not found')
try:
    mysql_user = MYSQL_CONFIG['user']
    mysql_password = MYSQL_CONFIG['password']
    mysql_host = MYSQL_CONFIG['host']
    mysql_port = int(MYSQL_CONFIG['port'])
    mysql_database = MYSQL_CONFIG['database']
except KeyError:
    raise KeyError('MySQL config wrong')

db_scheme = 'mysql+mysqldb'
engine = make_engine(db_scheme, mysql_user, mysql_password, mysql_host, mysql_port, mysql_database, 'utf8')
session = make_session(engine)
# DB commit decorator
db_commit = gen_commit_deco(session)

