LOCAL := TRUE
RELEASE_NAME := airflow
NAMESPACE := airflow

.PHONE: setup
setup: ## Create Kubernetes cluster using Kind.
	kind create cluster --image kindest/node:v1.24.2 --config kind-cluster.yaml

.PHONY: build
build: ## Install Airflow, Prometheus-Stack, and EFK using Helm.
	kubectl create namespace ${NAMESPACE}
	kubectl -n ${NAMESPACE} create secret \
		generic my-webserver-secret \
		--from-literal="webserver-secret-key=\
		$(python3 -c 'import secrets; print(secrets.token_hex(16))')"
	helm install airflow chart -n ${NAMESPACE} --timeout 20m0s

.PHONY: clean
clean: ## Delete the installed Airflow and Prometheus-Stack, but keep the Kind cluster.
	-kubectl delete namespace ${NAMESPACE}
	-kubectl delete pv --all
	-kubectl delete validatingwebhookconfiguration --all
	-kubectl delete mutatingwebhookconfiguration --all
	-kubectl delete crd --all

.PHONY: nuke
nuke: ## Delete the entire Kind cluster.
	kind delete cluster --name airflow-cluster

.PHONY: forward-web
forward-web: ## Forward the Airflow webserver port.
	kubectl port-forward svc/${RELEASE_NAME}-webserver 8080 -n ${NAMESPACE}

.PHONY: forward-flower
forward-flower:	## Forward the Flower web interface port.
	kubectl port-forward svc/${RELEASE_NAME}-flower 5555 -n ${NAMESPACE}

.PHONY: forward-grafana
forward-grafana: ## Forward the Grafana port.
	kubectl port-forward deployment/${RELEASE_NAME}-grafana 3000 -n ${NAMESPACE}

.PHONY: forward-kibana
forward-kibana: ## Forward the Kibana port.
	kubectl port-forward svc/kibana 5601 -n ${NAMESPACE}

.PHONY: help
help: ## Show this help.
	@egrep -h '\s##\s' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m  %-30s\033[0m %s\n", $$1, $$2}'
