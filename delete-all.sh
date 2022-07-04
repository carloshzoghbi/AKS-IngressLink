#!/bin/sh
#Pre-requisites: You are in the same root project directory where 'ingresslink.yaml' and the 'kubernetes-ingress' github directory is located.
#Remove ingress link resources
kubectl delete -f ingresslink.yaml
kubectl delete -f cis-deployment.yaml
kubectl delete -f customresourcedefinitions.yaml
kubectl delete -f ingresslink-customresourcedefinition.yaml

#Remove nginx resources.
kubectl delete -f common/ns-and-sa.yaml
kubectl delete -f deployment/appprotect-dos-arb.yaml
kubectl delete -f service/appprotect-dos-arb-svc.yaml
kubectl delete -f rbac/rbac.yaml
kubectl delete -f rbac/ap-rbac.yaml
kubectl delete -f rbac/apdos-rbac.yaml
kubectl delete -f common/default-server-secret.yaml
kubectl delete -f nginx-config.yaml
kubectl delete -f common/ingress-class.yaml
kubectl delete -f common/crds/k8s.nginx.org_virtualservers.yaml
kubectl delete -f common/crds/k8s.nginx.org_virtualserverroutes.yaml
kubectl delete -f common/crds/k8s.nginx.org_transportservers.yaml
kubectl delete -f common/crds/k8s.nginx.org_policies.yaml
kubectl delete -f common/crds/k8s.nginx.org_globalconfigurations.yaml
kubectl delete -f common/crds/appprotect.f5.com_aplogconfs.yaml
kubectl delete -f common/crds/appprotect.f5.com_appolicies.yaml
kubectl delete -f common/crds/appprotect.f5.com_apusersigs.yaml
kubectl delete -f common/crds/appprotectdos.f5.com_apdoslogconfs.yaml
kubectl delete -f common/crds/appprotectdos.f5.com_apdospolicy.yaml
kubectl delete -f common/crds/appprotectdos.f5.com_dosprotectedresources.yaml
kubectl delete -f daemon-set/nginx-plus-ingress.yaml
kubectl delete -f loadbalancer.yaml
kubectl delete -f cafe.yaml
kubectl delete -f cafe-secret.yaml
kubectl delete -f ap-logconf.yaml
kubectl delete -f ap-dataguard-alarm-policy.yaml
kubectl delete -f ap-apple-uds.yaml
kubectl delete -f cafe-ingress.yaml
kubectl delete -f nodeport.yaml

#Remove big-ip cis resources. Warning: This will delete all BIG-IP CIS resources created in the parent directory as well.
kubectl delete -f https://raw.githubusercontent.com/laul7klau/kubernetes-aws/main/bigip-ctrl-ingress/config/k8s-rbac.yaml
kubectl delete serviceaccount bigip-ctlr -n kube-system
kubectl delete secret f5-bigip-ctlr-login -n kube-system
kubectl delete -f f5-hello-world-deployment.yaml
kubectl delete -f f5-hello-world-service.yaml

echo "Manually remove the 'kubernetes-ingress' github directory: 'rm -rf kubernetes-ingress'"
