#!/bin/sh

# This assumes the user has
# * logged in via 'oc login'
# * Added the WildFly Helm repository
#
# Understood environment variables:
# * QS_OPTIMIZED - If set and equal to 1 we will run to run the build optimised. In this case we provision the server
#                   ourselves, create a runtime image, and create and push to the image stream expected by the Helm chart.
# * QS_SKIP_CLEANUP - If set and equal to 1 we will not delete the contents of the target directory.

################################################################################################
# Go into the quickstart directory

cd "${0%/*}"
qs_dir="${1}"
if [ -z "${1}" ]; then
  echo "No quickstart directory set"
  exit 1
fi

application="${qs_dir}"
if [ ! -d "${qs_dir}" ]; then
  echo "$(pwd)/${qs_dir} does not exist"
  exit 1
fi
cd "${qs_dir}"

echo "Running the ${qs_dir} tests on OpenShift"
start=$SECONDS
################################################################################################
# Provision server and push imagestream if QS_OPTIMIZED=1
if [ "${QS_OPTIMIZED}" = "1" ]; then
  echo "optimized build"
  # TODO
fi

################################################################################################
# Helm install, waiting for the pods to come up
helm_set_arguments=""
if [ "${QS_OPTIMIZED}" = "1" ]; then
   helm_set_arguments=" --set build.enabled=false"
fi
# '--atomic' waits until the pods are ready, and removes everything if something went wrong
# `--timeout` sets the timeout for the wait.
# https://helm.sh/docs/helm/helm_install/ has more details
if [ -n "${helm_set_arguments}" ]; then
  helm install "${application}" wildfly/wildfly -f charts/helm.yaml  --atomic --timeout=10m0s "${helm_set_arguments}"
else
  helm install "${application}" wildfly/wildfly -f charts/helm.yaml  --atomic --timeout=10m0s
fi

################################################################################################
# Run tests
echo "running the tests"
pwd
mvn clean verify -Parq-remote -Dserver.host=https://$(oc get route "${application}" --template='{{ .spec.host }}')

################################################################################################
# Helm uninstall
echo "Running Helm uninstall"
helm uninstall "$application"

################################################################################################
# Delete target directory so we don't run out of disk space when running all the tests
if [ "${SKIP_CLEANUP}" = "1" ]; then
  echo "Skipping cleanup..."
else
  echo "Deleting target directory..."
  rm -rf target
fi

end=$SECONDS
duration=$((end - start))
echo "${application} tests run in $(($duration / 60))m$(($duration % 60))s."

