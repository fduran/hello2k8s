## Using Terraform to create a GKE cluster

I'm following mostly [Hashicorp's tutorial repo](https://github.com/hashicorp/learn-terraform-provision-gke-cluster) but:
- I modified the variable `project_id` -> `project`, otherwise while applying and trying to create the service account, Terraform complaints that it's missing.
- I commented out the  node_config.service_account setting, since this associates the GKE node pool with a service account `service-account-id@$PROJECT_ID.iam.gserviceaccount.com`, and this account doesn't have permissions to pull from our gcr.io/$PROJECT_ID/ Container Repository. To fix this in GCP Storage we would need to add this account with role `Storage Object Viewer` to the bucket that holds our GCR images ( `artifacts.$PROJECT_ID.appspot.com` in our case).

I used the following Terraform files to create the most basic GKE cluster, using default values (not suitable for anything other than a quick test or exercise. Note that while `initial_node_count` is documented as optional it's a required paramenter, at least for Terraform):

- (Missing) Ideally we should create a VPC to isolate what we create from the rest of the network.
- `variables.tf` contains the same variables we used with SDK
- `versions.tf` to set Google provider and versions
- `gke.tf` provisions a GKE cluster and a separately managed node pool

Also we want to store the state of Terraform, for example in a Google Storage bucket with versioning enabled (I didn't implement this).


To run, cd to this terraform directory and then:

```
# authenticate
gcloud auth application-default login

# init terraform
terraform init

# optionally, check plan
terraform plan

# apply
terraform apply

google_service_account.default: Creating...
google_service_account.default: Creation complete after 2s [id=projects/hellok8s-307200/serviceAccounts/service-account-id@hellok8s-307200.iam.gserviceaccount.com]
google_container_cluster.primary: Creating...
google_container_cluster.primary: Still creating... [10s elapsed]
...
google_container_cluster.primary: Still creating... [3m20s elapsed]
google_container_cluster.primary: Creation complete after 3m21s [id=projects/hellok8s-307200/locations/us-east1/clusters/hello-gke]

Apply complete! Resources: 2 added, 0 changed, 0 destroyed.

Outputs:

cluster_host = "34.75.41.52"
cluster_name = "hello-gke"

# check cluster
gcloud container clusters list
NAME       LOCATION  MASTER_VERSION    MASTER_IP    MACHINE_TYPE  NODE_VERSION      NUM_NODES  STATUS
hello-gke  us-east1  1.17.14-gke.1600  34.75.41.52  e2-medium     1.17.14-gke.1600  3          RUNNING

# get credentials
gcloud container clusters get-credentials hello-gke --region us-east1

# check access to cluster
kubectl get all --all-namespaces
NAMESPACE     NAME                                                              READY   STATUS    RESTARTS   AGE
kube-system   pod/event-exporter-gke-666b7ffbf7-d6cmk                           2/2     Running   0          9m15s
kube-system   pod/fluentbit-gke-5drhn                                           2/2     Running   0          8m59s
...

# to destroy:
terraform destroy
```