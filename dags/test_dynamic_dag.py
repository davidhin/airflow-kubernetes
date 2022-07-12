from datetime import datetime
from random import randint

from airflow import DAG
from airflow.decorators import task

with DAG(
    dag_id="test_dynamic_dag",
    start_date=datetime(2022, 6, 23),
    default_args={"retries": 3},
) as dag:

    @task
    def a():
        return [i + 1 for i in range(randint(1, 10))]

    @task
    def b():
        return [i + 1 for i in range(randint(1, 10))]

    @task
    def sum_it(vals):
        return sum(vals)

    @task
    def multiply(a, b):
        return a * b

    combinations = multiply.expand(a=a(), b=b())
    total = sum_it(combinations)
