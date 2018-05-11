FROM python:3.6
COPY . /app/{{ app_name }}
WORKDIR /app/{{ app_name }}
RUN pip install -r requirements.txt -i https://mirrors.aliyun.com/pypi/simple/
{% if mode_grpc -%}
ONBUILD RUN python -m grpc_tools.protoc -I/app/{{ app_name }}/{{ app_name }}/proto --python_out=/app/{{ app_name }}/{{ app_name }}/proto --grpc_python_out=/app/{{ app_name }}/{{ app_name }}/proto /app/{{ app_name }}/{{ app_name }}/proto/{{ app_name }}.proto
{%- endif %}
HEALTHCHECK --interval=10s --start-period=5s CMD python /app/{{ app_name }}/scripts/health_check.py
ENTRYPOINT ["python"]
CMD ["start.py"]
