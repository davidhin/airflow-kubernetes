import pendulum

from airflow.decorators import dag
from airflow.models import Variable
from airflow.providers.cncf.kubernetes.operators.kubernetes_pod import (
    KubernetesPodOperator,
)


@dag(
    start_date=pendulum.today("UTC").add(days=-7),
    catchup=False,
    tags=["sandbox"],
    description="Test kubernetes on local kubernetes cluster",
)
def test_local_kube():
    KubernetesPodOperator(
        name="test_local_kubenetes",
        namespace=Variable.get("pod_namespace"),
        image="debian",
        cmds=["bash", "-cx"],
        arguments=["echo", "10"],
        labels={"foo": "bar"},
        task_id="echo_10",
        in_cluster=True,
        is_delete_operator_pod=True,
        get_logs=True,
    )


test_local_kube = test_local_kube()
