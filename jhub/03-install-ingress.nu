# TODO
# - [ ] Move current logic to a main function, I guess

print "[ INFO ] Installing an ingress resource"

(helm upgrade --install ingress-nginx ingress-nginx
  --repo https://kubernetes.github.io/ingress-nginx
  --namespace ingress-nginx --create-namespace
  --set 'controller.nodeSelector.capi\.stackhpc\.com/node-group=default-worker'
  --wait
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
