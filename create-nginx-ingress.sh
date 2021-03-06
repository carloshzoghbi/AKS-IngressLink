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
cp ../examples/appprotect-dos/syslog.yaml .
cp ../examples/appprotect-dos/syslog2.yaml .
cp ../examples/appprotect-dos/apdos-logconf.yaml .
cp ../examples/appprotect-dos/apdos-policy.yaml .
wget https://raw.githubusercontent.com/carloshzoghbi/kubernetes-aws/main/bigip-ctrl-ingress/ingressLink/config/nodeport.yaml
wget https://raw.githubusercontent.com/carloshzoghbi/kubernetes-aws/main/bigip-ctrl-ingress/ingressLink/config/loadbalancer.yaml
wget https://raw.githubusercontent.com/carloshzoghbi/kubernetes-aws/main/bigip-ctrl-ingress/ingressLink/config/nginx-config.yaml
wget https://raw.githubusercontent.com/carloshzoghbi/AKS-IngressLink/main/cafe-dosprotected.yaml
kubectl apply -f common/ns-and-sa.yaml
kubectl apply -f syslog.yaml
kubectl apply -f syslog2.yaml
kubectl apply -f deployment/appprotect-dos-arb.yaml
kubectl apply -f service/appprotect-dos-arb-svc.yaml
kubectl apply -f rbac/rbac.yaml
kubectl apply -f rbac/ap-rbac.yaml
kubectl apply -f rbac/apdos-rbac.yaml
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
kubectl apply -f common/crds/appprotectdos.f5.com_apdoslogconfs.yaml
kubectl apply -f common/crds/appprotectdos.f5.com_apdospolicy.yaml
kubectl apply -f common/crds/appprotectdos.f5.com_dosprotectedresources.yaml
kubectl apply -f daemon-set/nginx-plus-ingress.yaml
kubectl apply -f loadbalancer.yaml
kubectl apply -f apdos-logconf.yaml
kubectl apply -f apdos-policy.yaml
kubectl apply -f cafe-dosprotected.yaml
kubectl create -f cafe.yaml
kubectl create -f cafe-secret.yaml
kubectl create -f ap-logconf.yaml
kubectl create -f ap-dataguard-alarm-policy.yaml
kubectl create -f ap-apple-uds.yaml
kubectl create -f cafe-ingress.yaml
kubectl apply -f nodeport.yaml
cd ../..
