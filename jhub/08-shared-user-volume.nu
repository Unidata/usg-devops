# TODO
# - [ ] "main" command that prints help
# - [ ] "create volume" sub-command
# - [ ] "install" sub-command to run the `helm upgrade --install` command
# - [ ] "create pv(c)" sub-command(s) to create or update PV/PVC with NFS IP
# - [ ] "init share" sub-command, to create the "_share" directory in the volume

# Shared home NFS using 2i2c's jupyterhub-home-nfs helm chart

source ./env.nu
let cluster = $env.jupyterhub.cluster
let shared_volume = $env.jupyterhub.shared_volume

let size = $shared_volume.home_size + $shared_volume.data_size

print $"[ INFO ] Configuring jupyterhub-home-nfs volume of size ($size) GB"

# ##############################################
# Create an Openstack volume if one is not already designated in
# ./shared-user-volume/values-nfs.yaml
# ##############################################

let values_nfs = $shared_volume.values_path

# If a volumeId is already set, use that. Useful for when you must recreate a
# cluster but want to keep the same openstack volume
let volume_id = if (open $values_nfs | get openstack.volumeId) != null {
  print $"[ INFO ] Openstack volumeId already set in ($values_nfs), this volume will be reused"
  open $values_nfs | get openstack.volumeId
} else {
  print $"[ INFO ] Creating new Openstack volume"
  (openstack volume create --size $size $"($cluster.name)-nfs-homedirs" -f yaml | from yaml).id
}

print $"[ INFO ] Using Openstack volume with ID ($volume_id)"


# ##############################################
# Deploy the In-Cluster NFS Server; configuring values-nfs.yaml
# ##############################################

# Adjust values-nfs.yaml appropriately

open $values_nfs
| upsert quotaEnforcer.config.QuotaManager.hard_quota $shared_volume.user_quota
| upsert openstack.volumeId $volume_id
| save -f $values_nfs

print "[ INFO ] Deploying helm chart"

# Will likely move this to it's own scirpt later
# Use --wait to ensure the NFS service has a ClusterIP before continuing
(helm upgrade --install jupyterhub-home-nfs
  oci://ghcr.io/2i2c-org/jupyterhub-home-nfs/jupyterhub-home-nfs
  --namespace jupyterhub-home-nfs --create-namespace
  --wait
  --values $values_nfs
)

let nfs_ip = kubectl get svc -n jupyterhub-home-nfs home-nfs -o yaml
| from yaml
| get spec.clusterIP

# ##############################################
# Configure JHub namespace to use shared home
# ##############################################

print "[ INFO ] Configuring PV and PVC"

let pv_path = $shared_volume.pv_path
let pvc_path = $shared_volume.pvc_path

open $pv_path
| upsert spec.nfs.server $nfs_ip
| save -f $pv_path

# Ensure jhub namespace exists before attempting to create pvc
kubectl get ns
| detect columns --guess
| get NAME
| if not ("jhub" in $in) { kubectl create ns "jhub" }

kubectl apply --wait -f $pv_path
kubectl apply --wait -f $pvc_path

# Init the shared directory in the NFS container
let job_path = $shared_volume.job_path
let timeout = "300s"

print $"[ INFO ] Initializing the shared directory with job timeout ($timeout)"

kubectl apply --wait -f $job_path
kubectl wait -n jhub --for=condition=complete $"--timeout=($timeout)" job/init-home-nfs-shared
kubectl logs -n jhub job/init-home-nfs-shared
kubectl delete -n jhub job/init-home-nfs-shared
