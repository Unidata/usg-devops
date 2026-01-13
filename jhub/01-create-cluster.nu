# TODO
# - [ ] Change file name from 01-create-cluster.nu to 01-magnum-cluster.nu
# - [ ] Make this script take arguments, and/or use sub-commands
# - [ ] Move cluster creation logic (everything currently in here) to a "create"
#       command
# - [ ] Create a "delete" command for cluster deletion
# - [ ] Create a "show" command for showing cluster

source ./env.nu

let cluster = $env.jupyterhub.cluster

print $"[ INFO ] Creating cluster: ($cluster.name)"

(openstack coe cluster create
    --cluster-template $cluster.template
    --master-count $cluster.master.count
    --node-count $cluster.worker.count
    --master-flavor $cluster.master.flavor
    --flavor $cluster.worker.flavor
    --labels $"auto_scaling_enabled=($cluster.autoscaling)"
    --labels min_node_count=1
    --labels max_node_count=1
    --fixed-network auto_allocated_network
    $cluster.name
)

# Wait for cluster creation, or error on timeout
let timeout = 20min
let start = date now
let check_status = {|| (openstack coe cluster show $cluster.name -f yaml | from yaml).status }
mut ready = false
mut status = null

print $"[ INFO ] Waiting for cluster creation with timeout ($timeout)"

while not $ready and ((date now) - $start) < $timeout {
  $status = do $check_status
  $ready = $status == "CREATE_COMPLETE"
  if status == "CREATE_FAILED" {
    print "[ ERROR ] Cluster creation failed!";
    break
  }
  print $"[ INFO ] Time elapsed ((date now) - $start)"
  sleep 30sec
}

if not $ready {
  print $"[ ERROR ] Failed to create healthy cluster in ($timeout)"
  exit 1
}
