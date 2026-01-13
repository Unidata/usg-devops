# TODO
# - [ ] Rename this file to 06-nodegroup.nu
# - [ ] Move this logic to a "create" sub-command; Maybe add an argument to feed
#       the command an "arbitrary" nodegroup definition in case we want more
#       than 1
# - [ ] Create a "delete" sub-command

source ./env.nu

let cluster_name = $env.jupyterhub.cluster.name
let nodegroup = $env.jupyterhub.nodegroup

print $"[ INFO ] Creating nodegroup ($nodegroup.name)"

(openstack coe nodegroup create $cluster_name $nodegroup.name
  --node-count 1
  --flavor $nodegroup.flavor
  --labels auto_scaling_enabled=$nodegroup.autoscaling
  --min-nodes 1
  --max-nodes $nodegroup.max_nodes
)

# Wait for nodegroup creation, or error on timeout
let timeout = 10min
let start = date now
let check_status = {|| (openstack coe nodegroup show $cluster_name $nodegroup.name -f yaml | from yaml).status }
mut ready = false
mut status = null

print $"[ INFO ] Wait for nodegroup creation with timeout ($timeout)"

while not $ready and ((date now) - $start) < $timeout {
  $status = do $check_status
  $ready = $status == "CREATE_COMPLETE"
  if $status == "CREATE_FAILED" {
    print "[ ERROR ] Nodegroup creation failed!";
    break
  }
  print $"[ INFO ] Time elapsed: ((date now) - $start)"
  sleep 30sec
}

if not $ready {
  print $"[ [ ERROR ] Failed to create healthy nodegroup in ($timeout)"
  exit 1
}
