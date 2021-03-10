## Summary

We want to:

- "Hello world" web app -> contenerize in Docker image & push to a Repository
- Create K8s cluster
- Deploy image from container repo to our k8s cluster

Then automate with proper CI/CD so that upon a change in the app code and commit to GitHub, changes (new image) are deployed automatically to our Kubernetes cluster.

## 1. Containerize the app using Docker

See the `Dockerfile` for the different application examples. 

To build this image, from the repo root dir do:  `docker build -t hello .`  

This image is not tagged (default tag will be ":latest"). As for the tag naming convention, we can look into using [Semantic Versioning](https://semver.org/) and potentially also use the [Conventional Commits](https://www.conventionalcommits.org/en/v1.0.0/) strategy as a "shift left" opportunity to empower developers to control what's deployed or how (for ex, we could automatically deploy a new test environment upon major and major commits but not on patches).

To instantiate a container from this image we can do: `docker run -p 8080:8080 -d --name hello hello` 

We can test this is working with for example: 

```
% curl -I http://localhost:8080
HTTP/1.1 200 OK
X-Powered-By: Express
Content-Type: text/html; charset=utf-8
Content-Length: 12
ETag: W/"c-Lve95gjOVATpfV8EL5X4nxwjKHE"
Date: Sun, 31 Jan 2021 20:13:50 GMT
Connection: keep-alive
Keep-Alive: timeout=5

% curl http://localhost:8080/pepe
Hello, pepe!%
```

To push to an account in Docker Hub, we only need to authenticate and push, for ex:  

```
docker login
docker push fduran/hello
```


### GCP Cloud Build


To build using Google Cloud's "Cloud Build", from the directory containing the Dockerfile:


`gcloud builds submit --tag gcr.io/$PROJECT_ID/hello`

or, to also push the built image to the Container Registry:

`gcloud builds submit --config cloudbuild.yaml .`

## 2. Deploy the app to the cloud with Kubernetes


### 2.1 Kubernetes cluster on GKE

To use GGP and GKE we have some prerequisites:

[Download and install Google SDK](https://cloud.google.com/sdk/docs/install) , check:

```
% gcloud version
Google Cloud SDK 325.0.0
bq 2.0.64
core 2021.01.22
gsutil 4.58
```

As requirements for GCP there are manual steps to be done in the [Google Cloud Console](https://console.cloud.google.com/):

- Create a Google Cloud project 
- Enabling the GKE API (this requires enabling Billing. It's always a good idea to also set up a low budget and alerts on it).

Before moving to creating a k8s cluster on GKE using Terraform, is a good idea to try out the SDK and its [gcloud container clusters create](https://cloud.google.com/sdk/gcloud/reference/container/clusters/create) command. This will make sure everything looks fine with our account and project and can also help us familiarize with the different GKE cluster options.


```
# authenticate
gcloud auth login 

# set some variables
PROJECT_ID=hellok8s-307200 
REGION=us-central1

# set default project to work with
gcloud config set project $PROJECT_ID 

# check available versions if you want to pin it
gcloud container get-server-config --region $REGION

# create k8s cluster (--num-nodes is initial node number, minimum is 3)
gcloud container clusters create \
  --num-nodes 1 \
  --region $REGION \
  --cluster-version "1.18.12-gke.1205" \
  hello-cluster

# after a bit we get:
NAME         LOCATION     MASTER_VERSION    MASTER_IP    MACHINE_TYPE  NODE_VERSION      NUM_NODES  STATUS
hello-cluster  us-central1  1.18.12-gke.1205  34.70.18.54  e2-medium     1.18.12-gke.1205  3          RUNNING
```

As another requirement, we want to [install kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl/)

Note that ideally we want to use a kubectl version that is within one minor version difference of our cluster, but GKE is a couple versions behind for k8s and we have the latest stable client version, hopefully this won't be an issue:

```
% kubectl version --client
Client Version: version.Info{Major:"1", Minor:"20", GitVersion:"v1.20.2"...
```

We can check that the newly created cluster in GKE is in our local context with `kubectl config get-contexts` and we can test connectivity to our cluster and see everything that has been deployed for the masters nodes (`kube-system` namespace) with: 

```
% kubectl get all --all-namespaces
NAMESPACE     NAME                                                           READY   STATUS    RESTARTS   AGE
kube-system   pod/event-exporter-gke-564fb97f9-clkx2                         2/2     Running   0          17m
kube-system   pod/fluentbit-gke-86gr9                                        2/2     Running   0          16m
...
```

At this point we could deploy a simple "hello world" workload with a k8s YAML manifest but we may as well destroy this quick test and move on to creating a k8s cluster in GKE with true Infrastructure as Code using Terraform.

`gcloud container clusters delete hello-cluster --region $REGION --async`

### 2.2 Kubernetes on GKE, using Terraform

For **Terraform** Infrastructure as Code, as requirement:

[Download and install Terraform](https://learn.hashicorp.com/tutorials/terraform/install-cli) , check:

```
% terraform version
Terraform v0.14.5
```

I created the resources in a separate directory, see Terraform's [README.md](./clouds/GCP/terraform/README.md)

### 2.2 Deploy Kubernetes Workload

The workload is described in the manifest `manifests/hello.yaml` (Note that the image repository is hardcoded, to template this we would need to introduce another dependency like Helm or at least `envsubst`)

to deploy our application:

```
% kubectl apply -f kubernetes/hello.yaml
deployment.apps/hello-deployment created

# after a bit
% kubectl get deployments
NAME               READY   UP-TO-DATE   AVAILABLE   AGE
hello-deployment   1/1     1            1           3m13s
```

To expose the deployment publicly in a stable fashion we could use a GCP Load Balancer. Entry points to the cluster and authentication are two of the main things that are dependant on the particular cloud vendor we use.

In my case I'll just use a NodePort Service, which is like opening a port route to on all nodes. We picked this port with by adding a `ports.nodePort` (or we can not define this and let k8s pick a port and use that one):

```
% kubectl describe services hello-service |grep NodePort
Type:                     NodePort
NodePort:                 <unset>  30253/TCP
```

Now we need to open this port in our CGP project (we can see here why we don't want to do this in a non-PoC environment):

```
% gcloud compute firewall-rules create test-node-port --allow tcp:30253

Creating firewall...⠹Created [https://www.googleapis.com/compute/v1/projects/hellok8s-307200/global/firewalls/test-node-port].
Creating firewall...done.
NAME            NETWORK  DIRECTION  PRIORITY  ALLOW      DENY  DISABLED
test-node-port  default  INGRESS    1000      tcp:30253        False
```

Now we need a public IP address of one of the nodes:

```
% gcloud compute instances list
NAME                                              ZONE        MACHINE_TYPE  PREEMPTIBLE  INTERNAL_IP  EXTERNAL_IP     STATUS
gke-hellok8s-307200-gke-default-pool-c80470f6-36pd  us-east1-b  e2-medium                  10.142.0.9   35.185.12.232   RUNNING
gke-hellok8s-307200-gke-default-pool-2be07348-rsh6  us-east1-c  e2-medium                  10.142.0.8   35.231.167.209  RUNNING
gke-hellok8s-307200-gke-default-pool-55551f0c-33wj  us-east1-d  e2-medium                  10.142.0.10  34.73.247.38    RUNNING
```

Our service is exposed now via the NodePort:

```
% curl http://35.185.12.232:30253/me
Hello, me!%
```

## 3. Automate the deployment of the App

The objective of a good deployment pipeline is that upon a developer merging (or even doing a PR) on GitHub, this will trigger the build and tagging of a new Docker image, this being pushed to a repository from which the k8s cluster can pull from (in our case, Google Container Registry unless we want to use a public one like Docker Hub) and finally, perform an update of the image.  

The best way to do this is with one CI/CD tool like Jenkins etc. One example such tool is GitHub Actions, with a configuration that would look basically like this [Google Workflow](https://github.com/actions/starter-workflows/blob/main/ci/google.yml)


I've also created a [deploy.sh](./deploy.sh) script that will deploy the latest master commit to the existing k8s cluster.

