#!/usr/bin/env nu

source ./env.nu

def main [
  cluster: string
  --dry-run
  --delete-home-volume
  --i-understand-this-deletes-cluster
  --timeout: duration = 30min # Cluster deletion wait timeout.
] {
  let configured_cluster = $env.jupyterhub.cluster.name

  if $cluster != $configured_cluster {
    print $"[ ERROR ] Refusing to teardown cluster '($cluster)': env.nu is configured for '($configured_cluster)'"
    exit 1
  }

  if ((not $dry_run) and (not $i_understand_this_deletes_cluster)) {
    print "[ ERROR ] Refusing to teardown cluster without --i-understand-this-deletes-cluster"
    exit 1
  }

  let zone = $env.jupyterhub.zone
  let fqdn = $"($cluster).($zone)"
  let values_nfs = $env.jupyterhub.shared_volume.values_path
  let home_volume_id = (open $values_nfs | get -o openstack.volumeId)

  def run [cmd: string, dry_run: bool] {
    if $dry_run {
      print $"[ DRY RUN ] ($cmd)"
    } else {
      print $"[ RUN ] ($cmd)"
      bash -lc $cmd
    }
  }

  def wait-for-cluster-delete [cluster: string, dry_run: bool, timeout: duration] {
    if $dry_run {
      print $"[ DRY RUN ] wait until cluster is deleted: ($cluster)"
      return
    }

    let start = date now

    print $"[ INFO ] Waiting for cluster deletion for ($cluster) with timeout ($timeout)"

    while ((date now) - $start) < $timeout {
      let r = (openstack coe cluster show $cluster -f value -c status | complete)

      if $r.exit_code != 0 {
        print $"[ INFO ] Cluster no longer found: ($cluster)"
        return
      }

      let status = ($r.stdout | str trim)
      print $"[ INFO ] Cluster status: ($status)"

      if $status == "DELETE_FAILED" {
        print $"[ ERROR ] Cluster deletion failed: ($cluster)"
        exit 1
      }

      sleep 30sec
    }

    print $"[ ERROR ] Timed out waiting for cluster deletion: ($cluster)"
    exit 1
  }

  print $"[ INFO ] Cluster: ($cluster)"
  print $"[ INFO ] DNS record: ($fqdn)"

  run "kubectl get pv -A | tail -n +2 | cut -f 1 -d ' ' > /tmp/pv.out" $dry_run
  run "openstack volume list | grep -f /tmp/pv.out || true" $dry_run

  run $"openstack coe cluster delete ($cluster)" $dry_run
  wait-for-cluster-delete $cluster $dry_run $timeout

  print $"[ INFO ] After cluster deletion completes for ($cluster), verify PV-backed volumes:"
  run "openstack volume list | grep -f /tmp/pv.out || true" $dry_run

  run $"openstack recordset delete ($zone) ($fqdn)" $dry_run

  if $home_volume_id != null {
    if $delete_home_volume {
      run $"openstack volume delete ($home_volume_id)" $dry_run
    } else {
      print $"[ WARN ] Preserving home NFS volume: ($home_volume_id)"
      print $"[ INFO ] Delete manually with: openstack volume delete ($home_volume_id)"
    }
  }

  print $"[ INFO ] Teardown complete/requested for cluster: ($cluster)"
}
