# How to image-builder

[Image builder](https://github.com/kubernetes-sigs/image-builder) is a K8s special interest group project that creates "ClusterAPI compatible" images that something like Openstack Magnum can readily use to create cluster nodes. The project makes use of [Packer](https://developer.hashicorp.com/packer), a Hashicorp project that can be used to make machine images for a variety of platforms using a single configuration, and [Ansible](https://docs.ansible.com)--an "IT automation engine" used to configure and run tasks on hosts.

We make use of it on Jetstream2 cloud to be capable of producing CAPI/K8s ready images that incorporate the most recent vulnerability patches and/or mitigations. It can also be used to further customize images as appropriate. For example, this work will also ensure that the `nsf-common` package is installed, allowing for Network File System mounts.

## Unidata Quickstart

Commands run on the `openstack-jetstream2` machine

1) `cd usg-devops/image-builder`
2) Run `image-builder.sh`
3) If successful, set `kube_version` property on resulting image:
   `openstack image set --property kube_version=v${VERSION} $IMAGE_NAME`
4) Edits vars in `create_cluster_template.sh` and run

# WIP
   
## Prerequisites

You will need:

- `docker` and `docker-compose`
- A valid `openrc.sh` file with credentials for Jetstream2
- The `openstack` CLI
- An SSH key-pair; public key available on Jetstream2

### Creating security groups to allow SSH traffic 

The host that image-builder runs on needs to be able to SSH into the server that is created to build the image. To this end, we'll create two security groups:

1) `image-builder`: Opens port 22 (SSH) to any openstack servers with the `image-builder-client` group; will be specified in `var_file.json`
2) `image-builder-client`: A "dummy" security group attached to the server that image-builder runs on; doesn't open any ports

Create these security groups, and the necessary rule, as follows:

```bash
openstack security group create --description "Allow machines with this SG to SSH into machines with the image-builder SG" image-builder-client
openstack security group create --description "Open port 22 (SSH) to any openstack servers with the 'image-builder-client' SG" image-builder
openstack security group rule create --protocol tcp --dst-port 22 --remote-group image-builder-client image-builder
```

Now add the `image-builder-client` to the Jetstream2 host where image-builder is running:

```bash
openstack server add security group <client-name> image-builder-client
```

>[!NOTE]
>At Unidata, we've already done these steps and attached the `image-builder-client` security group to the `openstack-jetstream2` machine.

### Create an SSH keypair

Image-builder uses `ansible` and thus `ssh` to configure our "source instance" that will be snapshot into the resulting image. On your image-builder client machine you must create an SSH keypair in the usual/preferred manner using `ssh-keygen`.

Then, use the `openstack` CLI to upload the public key to Jetstream2. We will refer to this keypair resource in one of our `packer` configuration files.

`openstack keypair create --public-key /path/to/public/key.pub`

>[!IMPORTANT]
>The `openstack` application credentials (i.e. `openrc.sh` or `clouds.yaml`) used to run the above command must be the same that are supplied to the image-builder workflow; `openstack` is not aware of keypairs created by other users.

## Running the workflow

The workflow has been containerized. Thus, there is no need to install or build any additional dependencies other than docker and docker-compose. This workflow is intended to be ran on a Jetstream2 machine
