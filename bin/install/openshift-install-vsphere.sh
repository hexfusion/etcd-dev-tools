#!/usr/bin/env bash

if [ "$1" = "" ]; then
  echo "install dir path is required"
  exit 1
fi

INSTALL_DIR=$PWD/$1
NOW=$(date +"%m_%d_%Y")

init () {
  mkdir -p $INSTALL_DIR
  cd $INSTALL_DIR
  git init
  git remote add origin git@github.com:openshift/installer.git
  git config core.sparseCheckout true
  echo "upi/vsphere/" >> .git/info/sparse-checkout
  git pull origin master
  mv upi/vsphere/* .
  rm -rf upi
}

gen_config() {
  oc registry login --to=/home/remote/sbatsche/.PULL_SECRET_LOCATION
  if [ "$?" -ne 0 ]; then
    echo "refresh pull secret failed"
  fi
  PULL_SECRET=$(cat /home/remote/sbatsche/.PULL_SECRET_LOCATION |  jq . -c | jq . -R)

  cat > $INSTALL_DIR/install-config.yaml << EOF
apiVersion: v1
baseDomain: devcluster.openshift.com
metadata:
  name: hexfusion
networking:
  machineCIDR: "139.178.89.192/26"
platform:
  vsphere:
    vCenter: vcsa.vmware.devcluster.openshift.com
    username: $ADD_ME
    password: $ADD_ME
    datacenter: dc1
    defaultDatastore: nvme-ds1
pullSecret: ${PULL_SECRET}
sshKey: ${SSH_KEY}
EOF
}

gen_tfstate() {
  cd $INSTALL_DIR
  installer-src create ignition-configs
  MASTER_IGNITION=$(cat $INSTALL_DIR/master.ign)
  WORKER_IGNITION=$(cat $INSTALL_DIR/worker.ign)
cat > $INSTALL_DIR/terraform.tfvars << EOF
cluster_id = "sbatsche"
cluster_domain = "sbatsche.devcluster.openshift.com"
base_domain = "devcluster.openshift.com"
vsphere_server = "vcsa.vmware.devcluster.openshift.com"
vsphere_user = "$ADD_ME"
vsphere_password = "$ADD_ME"
vsphere_cluster = "devel"
vsphere_datacenter = "dc1"
vsphere_datastore = "nvme-ds1"
vm_template = "rhcos-latest"
machine_cidr = "139.178.89.192/26"
control_plane_count = 3
compute_count = 3
bootstrap_ignition_url = "http://${IGNITION_SERVER_IP_ADDRESS}:81/sbatsche/sbatsche-${NOW}-bootstrap.ign"

control_plane_ignition = <<END_OF_MASTER_IGNITION
${MASTER_IGNITION}
END_OF_MASTER_IGNITION

compute_ignition = <<END_OF_WORKER_IGNITION
${WORKER_IGNITION}
END_OF_WORKER_IGNITION

ipam = "$IPAM_ADDRESS"
ipam_token = "$IPAM_TOKEN"
EOF
}

installer-src() {
  /home/remote/sbatsche/go/src/github.com/openshift/installer/bin/openshift-install "$@" ;
}

ssh_config() {
scp -i ~/.ssh/libra.pem $INSTALL_DIR/bootstrap.ign root@${IGNITION_SERVER_IP_ADDRESS}:/var/www/ignition/sbatsche/sbatsche-${NOW}-bootstrap.ign
}

install() {
  terraform init
  terraform apply -auto-approve
  installer-src wait-for bootstrap-complete
  terraform apply -auto-approve -var 'bootstrap_complete=true'
  openshift-install wait-for install-complete
}


init
gen_config
gen_tfstate
install

