# TODO
# - [ ] Move this to a main function, although this isn't strictly necessary
# - [ ] If I really wanted to, make a "backup" sub-command

source ./env.nu

let cluster_name = $env.jupyterhub.cluster.name

print "[ INFO ] Fetching kubectl config file"

cd /tmp/
openstack coe cluster config $cluster_name --force
| complete

# Make sure the file created correctly
if not ("/tmp/config" | path exists) {
  print "[ ERROR ] Failed to create kube config file"
  exit 1
}

chmod 600 config
mkdir ~/.kube

if ("~/.kube/config" | path exists) {
  let backup = $"~/.kube/config-(date now | format date "%F")" | path expand
  print $"[ WARNING ] ~/.kube/config already exists. Creating a backup at ($backup)"
  mv ~/.kube/config $backup
}

mv config ~/.kube/config

print "[ INFO ] Running `kubectl get nodes` to verify ~/.kube/config"

kubectl get nodes
| complete
| if $in.exit_code == 0 {
      print "[ INFO ] OK!"
      print $in.stdout
    } else {
      print "[ ERROR ] See stderr below..."
      print $in
      exit 1
  }
