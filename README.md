# AKS-IngressLink
This repository is a step by step guide for the QUICK deployment of NGINX Ingress Controller, BIG-IP Container Ingress Service and F5 IngressLink for Kubernetes.  

Note: The deployment in this GitHub repository is for demo or experimental purposes and not meant for production use or supported by F5 Support. For example, the Kubernetes nodes have public elastic IP addresses for easy access for troubleshooting. 

## Prerequisites – Securing k8s environments:

1. Install WSL (windows subsystem for linux) if you are user of windows:
https://docs.microsoft.com/en-us/windows/wsl/about
2. Install brew if you are user of MAC
```shell
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```
3. Install jq:

On WSL:

```shell
sudo apt-get install jq
```
On Mac:

```shell
Brew install jq
```
4. Install Azure CLI

On WSL:

```shell
#Execute installation
sudo -i apt-get install npm
sudo -i npm install -g azure-cli
#Verify installation
sudo npm list -g
```
On Mac:

```shell
brew update && brew install azure-cli
```
5. Install kubectl

On WSL:

```shell
curl -LO https://storage.googleapis.com/kubernetes-release/release/`curl -s
https://storage.googleapis.com/kubernetes-release/release/stable.txt`/bin/linux/amd64/kubectl
chmod +x ./kubectl
sudo mv ./kubectl /usr/local/bin/kubectl
kubectl version –client
#Check your home folder
cd ~\
pwd
#set kubeconf folder for kubectl
export KUBECONFIG=/home/valdis/kube.conf
```
On Mac:

```shell
brew install kubectl
```


# 1. Kubernetes Azure AKS Cluster:  
  
Perform the following steps in this README.md to first deploy a Kubernetes cluster on Azure using aks.
  
```shell
az account list-locations --output  table # This command list the AZ locations, useful for the next step.
az account list --output table
az account set --subscription f5-AZR_4261_SALES_SA_ALL

#Change the XXX for your alias resource names
RG="XXX-k8s-gud"
LOCATION="eastus2"
VNET="XXX-k8s-vnet"
SUBMASTER="master-subnet"
SUBWORKER="worker-subnet"
SUBSERVER="server-subnet"
NSG="XXX-NSG"
MYIP=$(curl -s https://ipv4.myip.wtf/text)
AKSCLUSTER="XXXAKS"
F5VM="f5vm01"

#Create Resource Group
az group create -l $LOCATION -n $RG

#Create NSG (Allow all from your IP Address)
az network nsg create -g $RG -n $NSG
az network nsg rule create -g $RG --nsg-name $NSG -n All_myIP --priority 100 \
  --source-address-prefixes $MYIP --source-port-ranges '*' --direction Inbound \
  --destination-address-prefixes '*' --destination-port-ranges '*' --access Allow \
  --protocol '*' --description "Allow ALL from my IP"

#Create VNET & 2 Subnets
az network vnet create  -l $LOCATION --resource-group $RG --name $VNET --address-prefixes 10.1.0.0/16
az network vnet subnet create --resource-group $RG --vnet-name $VNET --name aks-subnet --address-prefixes 10.1.240.0/24 --service-endpoints Microsoft.ContainerRegistry --network-security-group $NSG
az network vnet subnet create --resource-group $RG --vnet-name $VNET --name server-subnet --address-prefixes 10.1.10.0/24 --network-security-group $NSG
VNETSUBID=$(az network vnet subnet show -g $RG -n aks-subnet --vnet-name $VNET | jq -r .id)
echo $VNETSUBID


# Deploy AKS & Registry
az aks create -l $LOCATION --resource-group $RG --name $AKSCLUSTER --node-count 2 --enable-addons monitoring --generate-ssh-keys --api-server-authorized-ip-ranges $MYIP --vnet-subnet-id $VNETSUBID
az aks get-credentials --name $AKSCLUSTER --resource-group $RG --file ~/.kube/config
kubectl get nodes
```


# 2. F5 BIG-IP AWAF VE in Azure 
Deploy F5 BIG-IP (15 - 20 min):

```shell
# Install the BIG-IP AWAF VE
az vm create -n $F5VM -g $RG -l $LOCATION --image f5-networks:f5-big-ip-advanced-waf:f5-big-awf-plus-hourly-25mbps:16.1.202000 --admin-username azureuser --admin-password f5DEMOs4uLATAM --tags "owner=$TAG" --vnet-name $VNET --subnet server-subnet --nsg "" --size Standard_D2s_v3

# Install AS3. Download package first !!!
wget https://github.com/F5Networks/f5-appsvcs-extension/releases/download/v3.36.0/f5-appsvcs-3.36.0-6.noarch.rpm

FN="f5-appsvcs-3.36.0-6.noarch.rpm"
CREDS="admin:f5DEMOs4uLATAM"
IP="$(az vm show -d -g $RG -n $F5VM --query publicIps -o tsv):8443"
LEN=$(wc -c $FN | awk 'NR==1{print $1}')
curl -kvu $CREDS https://$IP/mgmt/shared/file-transfer/uploads/$FN -H 'Content-Type: application/octet-stream' -H "Content-Range: 0-$((LEN - 1))/$LEN" -H "Content-Length: $LEN" -H 'Connection: keep-alive' --data-binary @$FN
DATA="{\"operation\":\"INSTALL\",\"packageFilePath\":\"/var/config/rest/downloads/$FN\"}"
curl -kvu $CREDS "https://$IP/mgmt/shared/iapp/package-management-tasks" -H "Origin: https://$IP" -H 'Content-Type: application/json;charset=UTF-8' --data $DATA
#Validate (wait 30-60 sec)
curl -kvu $CREDS https://$IP/mgmt/shared/appsvcs/info

# Create cis partition
curl -kvu $CREDS https://$IP/mgmt/tm/sys/folder -X POST -H 'Content-Type: application/json;charset=UTF-8' -d '{"name": "cispartition", "partition": "/"}'
```
# 3. F5 IngressLink 
This is a step by step guide to deploy f5 IngressLink.

***Image***

1. Ensure you can login to the BIG-IP

- Login to BIG-IP GUI https://<IP>:8443
Verify AS3 is installed at iApps > Package Managment LX. See "f5-appsvcs"

### Create the BIG-IP Container Ingress Service
#### Configure the CIS deployment files:
2. Copy and paste the following commands:

```shell

wget https://raw.githubusercontent.com/carloshzoghbi/kubernetes-aws/main/bigip-ctrl-ingress/ingressLink/create-nginx-ingress.sh

wget https://raw.githubusercontent.com/carloshzoghbi/kubernetes-aws/main/bigip-ctrl-ingress/config/cis-deployment.yaml

wget https://raw.githubusercontent.com/carloshzoghbi/kubernetes-aws/main/bigip-ctrl-ingress/ingressLink/config/ingresslink.yaml

wget https://raw.githubusercontent.com/carloshzoghbi/kubernetes-aws/main/bigip-ctrl-ingress/ingressLink/config/customresourcedefinitions.yaml

wget https://raw.githubusercontent.com/carloshzoghbi/kubernetes-aws/main/bigip-ctrl-ingress/ingressLink/config/ingresslink-customresourcedefinition.yaml
```

3. Edit the following 2 files:  
   -- **cis-deployment.yaml**:  
      &nbsp;&nbsp;&nbsp;&nbsp;- Fill in the value of "--bigip-url" with the self IP of the BIG-IP. This is the private IP address of the BIG-IP that the controller will contact. Using the external IP may work but is not secure.
  -- **ingresslink.yaml**:
      &nbsp;&nbsp;&nbsp;&nbsp;- Replace 'virtualServerAddress: "??????"' with the VS IP. For single NIC, this is the self IP address.

4. Create the following iRule on the BIG-IP instance:
   - Follow steps 4 and 5 in [Lab4.1 BIG-IP Setup](https://clouddocs.f5.com/training/community/containers/html/class1/module4/lab1.html) to create the iRule *Proxy_Protocol_iRule* on the BIG-IP instance.

5. Create the NGINX KIC:  

```shell
chmod u+x create-nginx-ingress.sh

./create-nginx-ingress.sh
```
  
6. Create the NGINX KIC

```shell
kubectl create secret generic f5-bigip-ctlr-login -n kube-system --from-literal=username=admin --from-literal=password=????

kubectl create -f https://raw.githubusercontent.com/laul7klau/kubernetes-aws/main/bigip-ctrl-ingress/config/bigip-ctlr-clusterrole.yaml

kubectl apply -f cis-deployment.yaml

kubectl apply -f ingresslink-customresourcedefinition.yaml

kubectl apply -f customresourcedefinitions.yaml

kubectl apply -f ingresslink.yaml
```
NGINX ingress controller, BIG-IP CIS, BIG-IP instance and F5 Ingress link are deployed!

BIG-IP Container Ingress Service is deployed!  

Optional: Change from Nodeport to Cluster IP mode   
The setup is currently running in Nodeport mode. See the verification section below to verify the nodeport vs clusterIP set up.  
To switch to ClusterIP mode, run:  
``kc edit -f cis-deployment.yaml -n kube-system``  

Replace 
``- --pool-member-type=nodeport``  with   ``- --pool-member-type=cluster``   

## Verification:   
- Access the BIG-IP virtual server: http://??bigip external IP address??   
- The following should be configured on the BIG-IP:
  - A New partition called **mypartition-name** is created with virtual server, pool, and the Kubernetes nodes as pool members. 
  - In CIS **nodeport**, the pool members are the Node IP addresses and port numbers are different ephemeral random port numbers  
  - In CIS **ClusterIP**, pool members are Pod IP addresses and port number is the one defined in the *f5-hello-world-deployment.yaml* file.  
- The BIG-IP Controller is deployed as a pod in the kube-system namespace.  
  $ kubectl get pods -n kube-system  
  NAME                                         READY   STATUS    RESTARTS   AGE   
  [...]   
  k8s-bigip-ctlr-deployment-7f56b674ff-lj5kk   1/1     Running   0          85s  
  [...]   

## What's next:  
Go to the sub directory [*ingresslink*](https://github.com/carloshzoghbi/kubernetes-aws/tree/main/bigip-ctrl-ingress/ingressLink), to create NGINX ingress controller and F5 Ingress Link.  

## Destroy
1. On Azure portal, destroy the RG.  
   - Go to Azure Portal > Resource Group > Name-of-Resource-Group  
   - *Delete*.   

## Source
[F5 CIS on Clouddocs](https://clouddocs.f5.com/containers/latest/userguide/kubernetes/#examples-repository).  
The [F5Networks / k8s-bigip-ctlr repository](https://github.com/F5Networks/k8s-bigip-ctlr).  
