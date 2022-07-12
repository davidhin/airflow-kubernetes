FROM apache/airflow:2.3.3

RUN pip install --no-cache-dir apache-airflow-providers-ssh
RUN pip install --no-cache-dir apache-airflow-providers-cncf-kubernetes

COPY ./dags /opt/airflow/dags
COPY ./plugins /opt/airflow/plugins
COPY --chown=airflow:root ./.ssh /opt/airflow/.ssh
