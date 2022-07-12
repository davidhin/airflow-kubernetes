import pendulum

from airflow.decorators import dag
from airflow.providers.ssh.operators.ssh import SSHOperator


@dag(
    start_date=pendulum.today("UTC").add(days=-7),
    catchup=False,
    tags=["sandbox"],
    description="Test ssh_ec2_sandbox connection",
)
def test_ssh():
    SSHOperator(task_id="uptime", ssh_conn_id="ssh_ec2_sandbox", command="uptime")
    SSHOperator(
        task_id="touch",
        ssh_conn_id="ssh_ec2_sandbox",
        command="touch `date +%Y-%m-%d_%H-%M-%S`",
    )


test_ssh = test_ssh()
