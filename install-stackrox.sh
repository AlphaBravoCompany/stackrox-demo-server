#!/bin/bash

set -e

G="\e[32m"
E="\e[0m"

export rox_version=3.69.x-nightly-20220501-amd64
export password=LockItDown

if [ -z "$1" ]
  then
    echo -----------------------------------------------
    echo -e "Please provide your desired Rancher DNS name as part of the install command. eg: ./install.sh rancher.mydomain.tld."
    echo -----------------------------------------------
    exit 1
fi

if ! grep -q 'Ubuntu' /etc/issue
  then
    echo -----------------------------------------------
    echo "Not Ubuntu? Could not find Codename Ubuntu in lsb_release -a. Please switch to Ubuntu."
    echo -----------------------------------------------
    exit 1
fi

## Update OS
echo "Updating OS packages..."
sudo apt update > /dev/null 2>&1
sudo apt upgrade -y > /dev/null 2>&1

## Install Prereqs
echo "Installing Prereqs..."
sudo apt-get update > /dev/null 2>&1
sudo apt-get install -y \
apt-transport-https ca-certificates curl gnupg lsb-release \
software-properties-common haveged bash-completion jq > /dev/null 2>&1

## Install Helm
echo "Installing Helm..."
curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3  > /dev/null 2>&1
chmod 700 get_helm.sh  > /dev/null 2>&1
./get_helm.sh  > /dev/null 2>&1
rm ./get_helm.sh  > /dev/null 2>&1

## Install K3s
echo "Installing K3s..."
sudo curl -sfL https://get.k3s.io | sh -  > /dev/null 2>&1
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml  > /dev/null 2>&1

## Wait for K3s to come online
echo "Waiting for K3s to come online...."
until [ $(kubectl get nodes|grep Ready | wc -l) = 1 ]; do echo -n "." ; sleep 2; done  > /dev/null 2>&1

## Install Longhorn
echo "Deploying Longhorn on K3s..."
helm repo add longhorn https://charts.longhorn.io > /dev/null 2>&1
helm repo update > /dev/null 2>&1
helm install longhorn longhorn/longhorn --namespace longhorn-system --create-namespace --set csi.attacherReplicaCount=1 --set csi.provisionerReplicaCount=1 --set csi.resizerReplicaCount=1 --set csi.snapshotterReplicaCount=1 > /dev/null 2>&1

# Install Roxctl
echo "Installing Roxctl..."
wget https://mirror.openshift.com/pub/rhacs/assets/3.69.1/bin/Linux/roxctl > /dev/null 2>&1
chmod 0755 roxctl > /dev/null 2>&1
chmod +x roxctl > /dev/null 2>&1
mv roxctl /usr/local/bin/ > /dev/null 2>&1

# create the install yamls
# please read the docs about the interactive installer : https://docs.openshift.com/acs/3.68/installing/install-quick-roxctl.html#using-the-interactive-installer_install-quick-roxctl
# Here we are using a PVC from Longhorn and exposing with NodePort. You can apply an ingress to the central pod later.
echo "Generating Stackrox Central and Scanner configs..."
roxctl central generate k8s pvc --storage-class longhorn --size 10 --enable-telemetry=false --lb-type np --password $password  --main-image quay.io/stackrox-io/main:$rox_version --scanner-db-image quay.io/stackrox-io/scanner-db:$rox_version --scanner-image quay.io/stackrox-io/scanner:$rox_version > /dev/null 2>&1

# Update Scanner replicas to only have 1 instead of 3
sleep 10
sed -i '0,/replicas: 3/{s/replicas: 3/replicas: 1/}' central-bundle/scanner/02-scanner-06-deployment.yaml > /dev/null 2>&1
sed -i '0,/cpu: 1000m/{s/cpu: 1000m/cpu: 500m/}' central-bundle/scanner/02-scanner-06-deployment.yaml > /dev/null 2>&1
sed -i '0,/minReplicas: 2/{s/minReplicas: 2/minReplicas: 1/}' central-bundle/scanner/02-scanner-08-hpa.yaml > /dev/null 2>&1
sleep 10

# Create namespace and install central and scanner
echo "Deploying Stackrox Central and Scanner..."
kubectl create ns stackrox > /dev/null 2>&1
kubectl apply -R -f central-bundle/central/ > /dev/null 2>&1
kubectl apply -R -f central-bundle/scanner/ > /dev/null 2>&1

## Wait for Stackrox Central and Scanner
echo "Waiting for Stackrox Central and Scanner to come online (approx 5 minutes)..."
until [ $(kubectl -n stackrox rollout status deploy/scanner-db|grep successfully | wc -l) = 1 ]; do echo -n "." ; sleep 2; done > /dev/null 2>&1
until [ $(kubectl -n stackrox rollout status deploy/scanner|grep successfully | wc -l) = 1 ]; do echo -n "." ; sleep 2; done > /dev/null 2>&1
until [ $(kubectl -n stackrox rollout status deploy/central|grep successfully | wc -l) = 1 ]; do echo -n "." ; sleep 2; done > /dev/null 2>&1

# validate the ports for the cluster. 
# wait for central to become active.
server=$(kubectl get nodes -o json | jq -r '.items[0].status.addresses[] | select( .type=="InternalIP" ) | .address ') > /dev/null 2>&1
rox_port=$(kubectl -n stackrox get svc central-loadbalancer |grep Node|awk '{print $5}'|sed -e 's/443://g' -e 's#/TCP##g') > /dev/null 2>&1

# create a sensor "cluster" using the ports and the admin password.
echo "Generating Stackrox Sensor configs..."
roxctl sensor generate k8s -e $server:$rox_port --name k3s --central central.stackrox:443 --insecure-skip-tls-verify --collection-method ebpf --admission-controller-listen-on-updates --admission-controller-listen-on-creates -p $password --main-image-repository quay.io/stackrox-io/main:$rox_version --collector-image-repository quay.io/stackrox-io/collector > /dev/null 2>&1

# Update Sensor Admission Controller replicas to only have 1 instead of 3
sleep 10
sed -i '0,/replicas: 3/{s/replicas: 3/replicas: 1/}' sensor-k3s/admission-controller.yaml > /dev/null 2>&1
sleep 10

# deploy the sensor/collectors
echo "Deploying Stackrox Sensor..."
kubectl apply -R -f sensor-k3s/ > /dev/null 2>&1

## Wait for Stackrox Sensor and Admission Controller
echo "Waiting for Stackrox Sensor to come online..."
until [ $(kubectl -n stackrox rollout status deploy/sensor|grep successfully | wc -l) = 1 ]; do echo -n "." ; sleep 2; done > /dev/null 2>&1
until [ $(kubectl -n stackrox rollout status deploy/admission-control|grep successfully | wc -l) = 1 ]; do echo -n "." ; sleep 2; done > /dev/null 2>&1

# Now add an ingress and profit...
# for example I use traefik
echo "Deploying Stackrox Traefik Config..."
kubectl apply -f https://raw.githubusercontent.com/clemenko/k8s_yaml/master/stackrox_traefik_crd.yml > /dev/null 2>&1

#export Stackrox UI
export STACKROXUI=https://$server:$rox_port > /dev/null 2>&1

## Install Cert-Manager
# Install the CustomResourceDefinition resources separately
echo "Deploying cert-manager on K3s..."
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.8.0/cert-manager.crds.yaml > /dev/null 2>&1

# Add the Jetstack Helm repository
helm repo add jetstack https://charts.jetstack.io > /dev/null 2>&1

# Update your local Helm chart repository cache
helm repo update > /dev/null 2>&1

# Install the cert-manager Helm chart
helm install \
  cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --create-namespace \
  --version v1.8.0  > /dev/null 2>&1

## Wait for cert-manager
echo "Waiting for cert-manager deployment to finish..."
until [ $(kubectl -n cert-manager rollout status deploy/cert-manager|grep successfully | wc -l) = 1 ]; do echo -n "." ; sleep 2; done > /dev/null 2>&1

## Install Rancher
echo "Deploying Rancher on K3s..."
helm repo add rancher-stable https://releases.rancher.com/server-charts/stable > /dev/null 2>&1
kubectl create namespace cattle-system > /dev/null 2>&1
helm install rancher rancher-stable/rancher \
  --namespace cattle-system \
  --set hostname=$1 > /dev/null 2>&1

## Wait for Rancher
echo "Waiting for Rancher UI to come online...."
until [ $(kubectl -n cattle-system rollout status deploy/rancher|grep successfully | wc -l) = 1 ]; do echo -n "." ; sleep 2; done > /dev/null 2>&1

## Get Rancher Password
echo "Exporting Rancher UI password..."
export RANCHERPW=$(kubectl get secret --namespace cattle-system bootstrap-secret -o go-template='{{ .data.bootstrapPassword|base64decode}}{{ "\n" }}') > /dev/null 2>&1

## Print Server Information and Links
touch ./server-details.txt
echo -----------------------------------------------
echo -e ${G}Install is complete. Please use the below information to access your environment.${E} | tee ./server-details.txt
echo -e ${G}Please update your DNS or Hosts file to point https://$1 to the IP of this server $NODE_IP.${E} | tee -a ./server-details.txt
echo -e ${G}StackRox UI:${E} $STACKROXUI | tee -a ./server-details.txt
echo -e ${G}StackRox Login${E}: admin/$password | tee -a ./server-details.txt
echo -e ${G}Rancher UI:${E} https://$1 | tee -a ./server-details.txt
echo -e ${G}Rancher Password:${E} $RANCHERPW | tee -a ./server-details.txt
echo Details above are saved to the file at ./server-details.txt
echo -----------------------------------------------