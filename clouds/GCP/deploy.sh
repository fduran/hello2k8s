#!/bin/bash

# Script to deploy manually (this should be triggered by GitHub merge hook):
# build Docker image -> push image to Registry , re-deploy k8s workload

# Requirements: be authenticated in GitHub and Google Cloud
#    for ECR: 
# enable GCR: gcloud services enable containerregistry.googleapis.com
# gcloud auth configure-docker

# some defensive code settings
# linting with shellcheck is always recommended
set -e # exit immediately on error
set -u # treat unset vars as error an exit
# set -x # print out commands, for debugging

# Parameter: Google Container Registry
# this will be created on first upload, no need to pre-create
PROJECT_ID=hellok8s-307200
REPO=gcr.io/$PROJECT_ID/hello

# last commited sha1, in short form, eg 71ac8f1
# will use as docker image tag 
LASTSHA=$(git rev-parse --short HEAD) 

# build new image locally, tag with last commit
docker build -t hello:$LASTSHA .

# tag and upload to Google Container Registry
docker tag hello:$LASTSHA $REPO:$LASTSHA
docker tag hello:$LASTSHA $REPO

docker push $REPO:$LASTSHA
docker push $REPO

# delete deployment and recreate
# to pull latest image with same tag we need: imagePullPolicy: Always
kubectl delete deployment hello-deployment
kubectl apply -f manifests/hello.yaml
