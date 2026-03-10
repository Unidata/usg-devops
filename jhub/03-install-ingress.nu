# TODO
# - [ ] Move current logic to a main function, I guess

source ./env.nu

let existing_ip = $env.jupyterhub.cluster.existing_ip

let existing_ip_flag = if $existing_ip != null {
  print $"[ INFO ] Using existing IP address for load balancer: ($existing_ip)"
  ["--set" $"controller.service.loadBalancerIP=($existing_ip)"]
} else { [] }

print "[ INFO ] Installing an ingress resource"

(helm upgrade --install ingress-nginx ingress-nginx
  --repo https://kubernetes.github.io/ingress-nginx
  --namespace ingress-nginx --create-namespace
  --set 'controller.nodeSelector.capi\.stackhpc\.com/node-group=default-worker'
  --wait
  ...$existing_ip_flag
)
| complete
| if $in.exit_code != 0 {
  print "[ ERROR ] See stderr below..."
  print $in
  exit 1
}

let ingress_ip = kubectl get svc -n ingress-nginx
| detect columns
| get 0.EXTERNAL-IP

print $"[ INFO ] Load balancer created with IP ($ingress_ip)"
