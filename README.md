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
export RG="XXX-k8s-guada"
export LOCATION="eastus2"
export VNET="XXX-k8s-vnet"
export SUBMASTER="master-subnet"
export SUBWORKER="worker-subnet"
export SUBSERVER="server-subnet"
export NSG="XXX-NSG"
export MYIP=$(curl -s https://ipv4.myip.wtf/text)
export AKSCLUSTER="XXXAKS"
export F5VM="f5vm01"

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


# Deploy AKS
az aks create -l $LOCATION --resource-group $RG --name $AKSCLUSTER --node-count 2 --enable-addons monitoring --generate-ssh-keys --api-server-authorized-ip-ranges $MYIP --vnet-subnet-id $VNETSUBID
az aks get-credentials --name $AKSCLUSTER --resource-group $RG --file ~/.kube/config
kubectl get nodes
```
Note: It is highly recommended to use USER assigned identity (option --assign-identity) when you want to bring your ownsubnet, which will have no latency for the role assignment to take effect. When using SYSTEM assigned identity, azure-cli will grant Network Contributor role to the system assigned identity after the cluster is created, and the role assignment will take some time to take effect, see https://docs.microsoft.com/azure/aks/use-managed-identity, proceed to create cluster with system assigned identity? (y/N): 
>>Type: y

# 2. F5 BIG-IP AWAF VE in Azure 
Deploy F5 BIG-IP (15 - 20 min):

```shell
# Install the BIG-IP AWAF VE
az vm create -n $F5VM -g $RG -l $LOCATION --image f5-networks:f5-big-ip-advanced-waf:f5-big-awf-plus-hourly-25mbps:16.1.202000 --admin-username azureuser --admin-password f5DEMOs4uLATAM --tags "owner=$TAG" --vnet-name $VNET --subnet server-subnet --nsg "" --size Standard_D2s_v3

#IMPORTANT NOTE: Ensure you can access the VE by the GUI before proceed!

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
# 3. Create a Kali VM

- On the Azure portal go to your Resource Group, click and enter on it.
- Click on 'Create'
- Click on 'Virtual machine'
- Fill in and choose the following configuration:
  - Virtual machine name: kali
  - Region: Select the region you chose when you created the RG
  - Avaliability options: No infrastructure redundancy required
  - Image: Click on "See all images" and search for Kali GUI Linux by Techlatest.net
  Note: Let deafult values on the other options.
- On the "Networking" tab 
  - In 'Subnet' chose server-subnet
  - In 'Configure network security group' select the NSG you create for this lab
- Click on 'Review + create' and 'Create'
- Click on 'Download private key and create resource'. You will use it for connect later to this VM.

# 4. F5 IngressLink 
This is a step by step guide to deploy f5 IngressLink.

***Image***

1. Ensure you can login to the BIG-IP (you can use echo $IP)

- Login to BIG-IP GUI https://<IP>:8443
Verify AS3 is installed at iApps > Package Managment LX. See "f5-appsvcs"

### Create the BIG-IP Container Ingress Service
#### Configure the CIS deployment files:
2. Copy and paste the following commands:

```shell
git clone https://github.com/carloshzoghbi/AKS-IngressLink.git
```

3. Edit the following 2 files:  
**cis-deployment.yaml**:  
  - Fill in the value of "--bigip-url" with the self IP of the BIG-IP. This is the private IP address of the BIG-IP that the controller will contact. Using the external IP may work but is not secure.

  - Uncomment "--custom-resource-mode=true",
  
**ingresslink.yaml**:
  - Replace 'virtualServerAddress: "??????"' with the VS IP. For single NIC, this is the self IP address.
      

4. Create the following iRule on the BIG-IP instance:
   - Follow steps from 1 to 6 in [Lab4.1 BIG-IP Setup](https://clouddocs.f5.com/training/community/containers/html/class1/module4/lab1.html) to create the iRule *Proxy_Protocol_iRule* on the BIG-IP instance.

5. Create the NGINX KIC:  

```shell
chmod u+x create-nginx-ingress.sh

./create-nginx-ingress.sh

# Check the services until the endpoints are populated
Kubectl describe svc -n nginx-ingress  
```
  
6. Create the F5 CIS and IngressLink

```shell
kubectl create secret generic f5-bigip-ctlr-login -n kube-system --from-literal=username=admin --from-literal=password=f5DEMOs4uLATAM

kubectl create -f bigip-ctlr-clusterrole.yaml

kubectl apply -f cis-deployment.yaml

kubectl apply -f customresourcedefinitions.yaml

kubectl apply -f ingresslink.yaml
```

  NGINX ingress controller, BIG-IP CIS, BIG-IP instance and F5 Ingress link are deployed! 
  
  
# 4. Test the App
  
### Login to Kali and test de app
  1. Open your Kali Linux terminal in SSH by using the IP Public assigned to the VM. Use the private key you download in previows steps.
  
  ```shell
  #Ensure you have read-only access to the private key
  chmod 400 <keyname>
  ssh -i <keyname> azureuser@xxx.xxx.xxx.xxx
  ```
  2. Type 'sudo bash'
  2. Use the following command to install the tool:
  ```shell
  git clone https://github.com/jseidl/GoldenEye.git 
  ```
  3. Modify the 'hosts' file pointing 'cafe.example.com' to the VS IP
  4. Use the following command to launch the attack:
  ```shell
  ./GoldenEye/goldeneye.py https://cafe.example.com -s 1000 -m post -n
  ```
