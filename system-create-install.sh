#!/bin/bash

if [ -z "$API_TOKEN" ]; then
  echo "API_TOKEN not set"
  exit 1
fi

if [ -z "$CLUSTER_NAME" ]; then
  echo "CLUSTER_NAME not set"
  exit 1
fi

if [ -z "$DAS_TENANT" ]; then
  echo "DAS_TENANT not set"
  exit 1
fi

SYSTEM_NAME="cluster-$CLUSTER_NAME"
SYSTEM_NAMESPACES=("dedicated-admin" "default-broker" "hive" "kube-node-lease" "kube-public" "kube-system" "local-cluster" "multicluster-engine" "open-cluster-management" "open-cluster-management-agent" "open-cluster-management-agent-addon" "open-cluster-management-global-set" "open-cluster-management-hub" "openshift" "openshift-addon-operator" "openshift-apiserver" "openshift-apiserver-operator" "openshift-aqua" "openshift-authentication" "openshift-authentication-operator" "openshift-backplane" "openshift-backplane-cee" "openshift-backplane-csa" "openshift-backplane-cse" "openshift-backplane-csm" "openshift-backplane-managed-scripts" "openshift-backplane-mobb" "openshift-backplane-srep" "openshift-backplane-tam" "openshift-build-test" "openshift-cloud-controller-manager" "openshift-cloud-controller-manager-operator" "openshift-cloud-credential-operator" "openshift-cloud-ingress-operator" "openshift-cloud-network-config-controller" "openshift-cluster-csi-drivers" "openshift-cluster-machine-approver" "openshift-cluster-node-tuning-operator" "openshift-cluster-samples-operator" "openshift-cluster-storage-operator" "openshift-cluster-version" "openshift-codeready-workspaces" "openshift-config" "openshift-config-managed" "openshift-config-operator" "openshift-console" "openshift-console-operator" "openshift-console-user-settings" "openshift-controller-manager" "openshift-controller-manager-operator" "openshift-custom-domains-operator" "openshift-customer-monitoring" "openshift-deployment-validation-operator" "openshift-dns" "openshift-dns-operator" "openshift-etcd" "openshift-etcd-operator" "openshift-host-network" "openshift-image-registry" "openshift-infra" "openshift-ingress" "openshift-ingress-canary" "openshift-ingress-operator" "openshift-insights" "openshift-kni-infra" "openshift-kube-apiserver" "openshift-kube-apiserver-operator" "openshift-kube-controller-manager" "openshift-kube-controller-manager-operator" "openshift-kube-scheduler" "openshift-kube-scheduler-operator" "openshift-kube-storage-version-migrator" "openshift-kube-storage-version-migrator-operator" "openshift-logging" "openshift-machine-api" "openshift-machine-config-operator" "openshift-managed-node-metadata-operator" "openshift-managed-upgrade-operator" "openshift-marketplace" "openshift-monitoring" "openshift-multus" "openshift-must-gather-operator" "openshift-network-diagnostics" "openshift-network-operator" "openshift-node" "openshift-nutanix-infra" "openshift-oauth-apiserver" "openshift-observability-operator" "openshift-ocm-agent-operator" "openshift-openstack-infra" "openshift-operator-lifecycle-manager" "openshift-operators" "openshift-operators-redhat" "openshift-osd-metrics" "openshift-ovirt-infra" "openshift-ovn-kubernetes" "openshift-rbac-permissions" "openshift-route-controller-manager" "openshift-route-monitor-operator" "openshift-security" "openshift-service-ca" "openshift-service-ca-operator" "openshift-splunk-forwarder-operator" "openshift-sre-pruning" "openshift-strimzi" "openshift-user-workload-monitoring" "openshift-validation-webhook" "openshift-velero" "openshift-vsphere-infra")

# Convert System name to System ID if already exists
SYSTEM_ID=$(curl -s --request GET \
  --url "$DAS_TENANT/v1/systems?compact=true&policies=false&modules=false&datasources=false&errors=false&authz=false&metadata=false&name=$SYSTEM_NAME" \
  --header 'Authorization: Bearer '$API_TOKEN'' \
  --header 'content-type: application/json' | jq -r '.result[].id')

if [ -z "$SYSTEM_ID" ]; then
  echo "System $SYSTEM_NAME not found, creating"
  OUTPUT=$(curl -s -X POST -H "Authorization: Bearer ${API_TOKEN}" -H "Content-Type:application/json" \
    "$DAS_TENANT/v1/systems" -d \
  '{
    "description": "System for '$CLUSTER_NAME'",
    "name": "'$SYSTEM_NAME'",
    "type": "kubernetes:v2"
  }')
  INSTALL_SCRIPT=$(echo $OUTPUT | jq -r '.result.install.kubectl["kubectl-all"]')
  SYSTEM_ID=$(echo $OUTPUT | jq -r .result.id)
  echo "System $SYSTEM_NAME created with ID $SYSTEM_ID"
  sleep 5 # This is needed for the API key used by the installation command to be provisioned
else
  echo "System $SYSTEM_NAME found with ID $SYSTEM_ID"
fi

if [ -z "$INSTALL_SCRIPT" ]; then
  echo "Fetching install script from System $SYSTEM_NAME with ID $SYSTEM_ID"
  INS_OUTPUT=$(curl -s -H "Authorization: Bearer ${API_TOKEN}" -H "Content-Type:application/json" $DAS_TENANT/v1/systems/$SYSTEM_ID/instructions)
  #echo "Instructions: $INS_OUTPUT"
  COMMANDS=$(echo $INS_OUTPUT | jq '.result.install[] | select(.category == "kubectl") | {commands}')
  #echo "Commands: $COMMANDS"
  INSTALL_SCRIPT=$(echo $COMMANDS | jq -r '.commands[] | select(.title == "kubectl-all") | {action} | join("")')
fi

for ns in "${SYSTEM_NAMESPACES[@]}"; do
  kubectl label ns $ns openpolicyagent.org/webhook=ignore
done;

eval "$INSTALL_SCRIPT"