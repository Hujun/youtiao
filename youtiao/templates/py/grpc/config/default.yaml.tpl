app:
    name: {{ app_name }}
    host: 127.0.0.1
    port: 8686
    max_worker: 5
    mode: grpc
logger:
    console:
        level: DEBUG
        format: "%(asctime)s %(levelname)-8s:%(name)s-%(message)s"
data_center: 0  # for snowflake ID generation
sentry:
    enabled: False
    dsn: ''
    environment: 'dev'
mysql:
    user: root
    password: root
    host: 127.0.0.1
    port: 3306
    database: root
postgre:
    user: root
    password: root
    host: 127.0.0.1
    port: 5432
    database: root
redis:
    host: 127.0.0.1
    port: 6379
    password: ''
    database: 0
sqlite:
    user: root
    password: root
