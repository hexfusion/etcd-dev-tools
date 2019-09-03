#!/usr/bin/env bash

# this script template which creates a custom release including cluster-etcd-operator and MCO.
# the script also will publish the image on quay.

CI_TOKEN=""
QUAY_TOKEN=""
USER=""
OC_PATH=/usr/local/bin/oc
TAG="4.2"


echo -e "Login to CI\n"
$OC_PATH login --token="$CI_TOKEN" --server=https://api.ci.openshift.org \
  && echo -e "Building new release\n" \
  && sudo podman login -u="hexfusion" -p="$QUAY_TOKEN" quay.io \
  && $OC_PATH adm release new -n origin \
    --server https://api.ci.openshift.org \
    --from-release \
    registry.svc.ci.openshift.org/origin/release:$TAG \
    --to-image quay.io/${USER}/origin-release:$TAG \
    cluster-etcd-operator=quay.io/${USER}/cluster-etcd-operator:latest \
    machine-config-operator=quay.io/${USER}/machine-config-operator:latest

