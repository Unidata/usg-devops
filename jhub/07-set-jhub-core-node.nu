# TODO
# - [ ] Move logic to main function, or something...

print "[ INFO ] Configuring 'default-worker' nodes to run JHub core Pods"

let default_workers = kubectl get nodes -l capi.stackhpc.com/node-group=default-worker
| detect columns
| get NAME
| sort

$default_workers
| each {|node| kubectl label node $node hub.jupyter.org/node-purpose=core }

# Ensure that every default-worker got labeled appropriately
let core_nodes = kubectl get nodes -l hub.jupyter.org/node-purpose=core
| detect columns
| get NAME
| sort

# Craft a pretty table for output
let t = ($default_workers | wrap "Default Workers") | merge ($core_nodes | wrap "JHub Core")
print $t

if $default_workers != $core_nodes {
  print $"[ ERROR ] Not all default-workers were appropriately labeled ..."
  exit 1
}

print "[ INFO ] All default-worker nodes labeled as JupyterHub Core nodes"
