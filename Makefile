LOCAL := TRUE
RELEASE_NAME := airflow
NAMESPACE := clientops-airflow

.PHONE: setup
setup: ## Create Kubernetes cluster using Kind.
	kind create cluster --image kindest/node:v1.24.2 --config kind-cluster.yaml
	kubectl create namespace ${NAMESPACE}
	kubectl -n ${NAMESPACE} create secret \
		generic my-webserver-secret \
		--from-literal="webserver-secret-key=\
		$(python3 -c 'import secrets; print(secrets.token_hex(16))')"

.PHONY: build
build: ## Install Airflow and Prometheus-Stack using Helm.
	$(if $(LOCAL),kubectl apply -f helm/airflow-pv.yaml -n ${NAMESPACE},)
	helm repo add apache-airflow https://airflow.apache.org
	helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
	helm repo update
	kind load docker-image clientops-airflow --name airflow-cluster
	helm install \
		${RELEASE_NAME} apache-airflow/airflow \
		--namespace ${NAMESPACE} \
		--timeout 20m0s
	@echo "\033[0;Run secondary upgrade workaround: https://github.com/apache/airflow/discussions/24859\033[0m"
	helm upgrade \
		${RELEASE_NAME} apache-airflow/airflow \
		--namespace ${NAMESPACE} \
		--values ./helm/values.yaml \
		--values ./helm/values-statsd.yaml \
		--values ./helm/values-local.yaml \
		--set "env[1].name=AIRFLOW_VAR_POD_NAMESPACE" \
		--set "env[1].value=${NAMESPACE}"
	@echo "\033[0;Install Prometheus Monitoring Stack\033[0m"
	kubectl apply -f helm/grafana-configmap.yaml -n ${NAMESPACE}
	helm install monitoring prometheus-community/kube-prometheus-stack \
		-n ${NAMESPACE} \
		--values helm/prometheus-override.yaml

.PHONY: upgrade
upgrade: ## Build the Airflow image and reload the Airflow deployment.
	docker build --tag clientops-airflow .
	kind load docker-image clientops-airflow --name airflow-cluster
	helm upgrade ${RELEASE_NAME} apache-airflow/airflow \
		--namespace ${NAMESPACE} \
		--values ./helm/values.yaml
	kubectl scale deployment ${RELEASE_NAME}-scheduler \
		--replicas 0 --namespace ${NAMESPACE}
	kubectl scale deployment ${RELEASE_NAME}-scheduler \
		--replicas 1 --namespace ${NAMESPACE}

.PHONY: clean
clean: ## Delete the installed Airflow and Prometheus-Stack, but keep the Kind cluster.
	-helm uninstall ${RELEASE_NAME} --namespace ${NAMESPACE}
	-$(if $(LOCAL),kubectl delete pvc --all --namespace ${NAMESPACE},)
	-$(if $(LOCAL),kubectl delete persistentvolume airflow-dags,)
	-$(if $(LOCAL),kubectl delete persistentvolume airflow-plugins,)
	-helm uninstall monitoring --namespace ${NAMESPACE}
	-kubectl delete configmap grafana-dashboards --namespace ${NAMESPACE}
	-kubectl delete --all pods --namespace=${NAMESPACE}

.PHONY: nuke
nuke: ## Delete the entire Kind cluster.
	kind delete cluster --name airflow-cluster

.PHONY: start
start: setup build ## Run start and build.

.PHONY: nuke-and-start
nuke-and-restart: nuke start ## Run nuke and start.

.PHONY: clean-and-build
clean-and-build: clean build ## Run clean and build.

.PHONY: forward-web
forward-web: ## Forward the Airflow webserver port.
	kubectl port-forward \
		svc/${RELEASE_NAME}-webserver 8080:8080 \
		--namespace ${NAMESPACE}

.PHONY: forward-flower
forward-flower:	## Forward the Flower web interface port.
	kubectl port-forward \
		svc/${RELEASE_NAME}-flower 5555:5555 \
		--namespace ${NAMESPACE}

.PHONY: forward-grafana
forward-grafana: ## Forward the Grafana port.
	kubectl port-forward \
		deployment/monitoring-grafana 3000:3000 \
		--namespace ${NAMESPACE}

.PHONY: install-dashboard
install-dashboard: ## Install Kubernetes Dashboard for monitoring the cluster.
	helm repo add kubernetes-dashboard https://kubernetes.github.io/dashboard/
	helm install dashboard kubernetes-dashboard/kubernetes-dashboard \
		-n kubernetes-dashboard --create-namespace

.PHONY: run-dashboard
run-dashboard: ## Generate login token for Kubernetes Dashboard and forward the port.
	@kubectl apply -f helm/kubernetes-dashboard.yaml
	@echo "\033[0;32mToken for kubernetes dashboard:\033[0m"
	@echo $$(kubectl -n kubernetes-dashboard create token admin-user)
	@echo "\n\033[0;35mDashboard available at:\033[0m"
	@echo "http://localhost:8001/api/v1/namespaces/kubernetes-dashboard/services/https:dashboard-kubernetes-dashboard:https/proxy/#/login"
	@kubectl proxy

.PHONY: help
help: ## Show this help.
	@egrep -h '\s##\s' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m  %-30s\033[0m %s\n", $$1, $$2}'
