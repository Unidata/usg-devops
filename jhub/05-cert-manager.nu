# TODO
# - [ ] Move this logic to a "create" command, or something
# - [ ] When using this at one point, I got a "connection refused" after 30s
#       from the webhook pod, maybe because the pod was not yet "ready" due to
#       needing to pull the image. The default timeout is 5min, but maybe the
#       manifest on GitHub overrides this? 
#       - I *think* this is because of the behavior or `kubectl apply --wait,
#         which, according to `--help` "If true, wait for resources to be gone
#         before returning. This waits for finalizers." In other words, this
#         doesn't wait for things to finish applying. Go figure. Instead, we
#         could do `kubectl apply -f $cert_manager; kubectl wait -n cert-manager
#         --for=create --all`
# - [ ] We can alternatively use the cert-manager helm chart, which *does* have
#       a --wait option that does what I expect
#       - One (dis)advantage of this is that we get *options* via yet another
#         values.yaml file, or we can simply pass those via a `--set` flag to
#         helm

let cert_manager = "https://github.com/cert-manager/cert-manager/releases/download/v1.16.2/cert-manager.yaml" 

print "[ INFO ] Configuring cert-manager to grab an SSL cert"

# print "[ INFO ] Applying cert-manager manifests"
# # Default timeout for --wait is 5min according to kubectl apply --help
# # I'm assuming that the command will exit with code 1 in the case of a timeout
# kubectl apply -f $cert_manager --wait
# | complete
# | if $in.exit_code != 0 {
#   print "[ ERROR ] See stderr below..."
#   print $in
#   exit 1
# }

print "[ INFO ] Applying cert-manager helm chart"
(helm upgrade --install
  cert-manager oci://quay.io/jetstack/charts/cert-manager
  --version v1.19.2
  --namespace cert-manager
  --create-namespace
  --set crds.enabled=true
  --set 'nodeSelector.capi\.stackhpc\.com/node-group=default-worker'
  --wait
)
| complete
| if $in.exit_code != 0 {
  print "[ ERROR ] See stderr below..."
  print $in
  exit 1
  }

let issuer = "./jhub/https_cluster_issuer.yaml"
| path expand

print "[ INFO ] Applying cluster issuer manifest"
kubectl apply -f $issuer --wait
| complete
| if $in.exit_code != 0 {
  print "[ ERROR ] See stderr below..."
  print $in
  exit 1
}
