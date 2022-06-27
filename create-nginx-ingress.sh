#!/bin/sh
git clone https://github.com/carloshzoghbi/kubernetes-ingress
cd kubernetes-ingress/deployments
git checkout v2.1.1
git switch main
cp ../examples/appprotect/cafe.yaml .
cp ../examples/appprotect/cafe-secret.yaml .
cp ../examples/appprotect/cafe-ingress.yaml .
cp ../examples/appprotect/ap-logconf.yaml .
cp ../examples/appprotect/ap-dataguard-alarm-policy.yaml .
cp ../examples/appprotect/ap-apple-uds.yaml .
wget https://raw.githubusercontent.com/carloshzoghbi/kubernetes-aws/main/bigip-ctrl-ingress/ingressLink/config/nodeport.yaml
wget https://raw.githubusercontent.com/carloshzoghbi/kubernetes-aws/main/bigip-ctrl-ingress/ingressLink/config/loadbalancer.yaml
wget https://raw.githubusercontent.com/carloshzoghbi/kubernetes-aws/main/bigip-ctrl-ingress/ingressLink/config/nginx-config.yaml
kubectl apply -f common/ns-and-sa.yaml
kubectl apply -f rbac/rbac.yaml
kubectl apply -f rbac/ap-rbac.yaml
kubectl apply -f common/default-server-secret.yaml
kubectl apply -f nginx-config.yaml
kubectl apply -f common/ingress-class.yaml
kubectl apply -f common/crds/k8s.nginx.org_virtualservers.yaml
kubectl apply -f common/crds/k8s.nginx.org_virtualserverroutes.yaml
kubectl apply -f common/crds/k8s.nginx.org_transportservers.yaml
kubectl apply -f common/crds/k8s.nginx.org_policies.yaml
kubectl apply -f common/crds/k8s.nginx.org_globalconfigurations.yaml
kubectl apply -f common/crds/appprotect.f5.com_aplogconfs.yaml
kubectl apply -f common/crds/appprotect.f5.com_appolicies.yaml
kubectl apply -f common/crds/appprotect.f5.com_apusersigs.yaml
kubectl apply -f daemon-set/nginx-plus-ingress.yaml
kubectl apply -f loadbalancer.yaml
kubectl create -f cafe.yaml
kubectl create -f cafe-secret.yaml
kubectl create -f ap-logconf.yaml
kubectl create -f ap-dataguard-alarm-policy.yaml
kubectl create -f ap-apple-uds.yaml
kubectl create -f cafe-ingress.yaml
kubectl apply -f nodeport.yaml
