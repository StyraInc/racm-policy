# racm-policy

Policies for RedHat Advanced Cluster Manager (RACM) that will ensure the Styra 
installation of OPA is performed on each managed cluster.

## Description

Each OpenShift cluster managed by RACM needs to have a corresponding Styra DAS system created.
Once the system is created, OPA, SLP (Styra Local Plane) and the Styra Datasources agent need
to be installed on the cluster to provide Rego policy-based admission control.

The policies contained in policy.yaml will:
1. Create the styra-system namespace on the target cluster.
2. Create BuildConfig that builds a new image, which will contain the installation script and 
all dependencies (oc, jq, curl).
3. Create a ServiceAccount to run the installation Job under.
4. Create a Job that will run the installation script.
5. The installation script will create a System in Styra DAS
6. It will retrieve the DAS-provided installation script and run it, installing
OPA, SLP and the Datasources agent.
7. Finally it will mark all OpenShift system namespaces as exempted from under OPA control. 

## Usage

Assuming RACM is configured, execute the following steps on the Hub cluster. You can use a namespace
that works best for you.

1. Create a new API token in Styra DAS (https://${DAS_TENANT_URL}/access-control/api-tokens/added). Make
sure the token has WorkspaceAdministrator permissions.
2. Create a new secret in the target namespace with the API token:
```shell
oc create secret generic styra-das-api-key --from-literal=api_key=${API_KEY}
```
3. Edit policy.yaml and set the spec.clusterSelector.matchExpressions if you don't want RACM policies
to be applied to all clusters including the hub.
4. Apply the policies:
```shell
oc apply -f policy.yaml
```
5. This should start the process described above on all RACM-managed clusters. Running
`oc get all -n styra-system` should show a similar output after a few minutes:
```shell
NAME                                            READY   STATUS      RESTARTS   AGE
pod/datasources-agent-5bd865b6d7-j2cj5          1/1     Running     0          2m37s
pod/opa-0                                       2/2     Running     0          2m37s
pod/opa-1                                       2/2     Running     0          2m9s
pod/opa-2                                       2/2     Running     0          106s
pod/ose-cli-with-installscript-and-jq-1-build   0/1     Completed   0          21m
pod/styra-installer-lj456                       0/1     Completed   0          6m57s

NAME                                READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/datasources-agent   1/1     1            1           2m37s

NAME                                           DESIRED   CURRENT   READY   AGE
replicaset.apps/datasources-agent-5bd865b6d7   1         1         1       2m37s

NAME                        COMPLETIONS   DURATION   AGE
job.batch/styra-installer   1/1           4m25s      6m58s
```