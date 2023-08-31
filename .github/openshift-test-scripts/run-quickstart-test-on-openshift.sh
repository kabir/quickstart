#!/bin/sh

# This assumes the user has
# * logged in via 'oc login'
# * Added the WildFly Helm repository
#
# Understood environment variables:
# * QS_OPTIMIZED - If set and equal to 1 we will run to run the build optimised. In this case we provision the server
#                   ourselves, create a runtime image, and create and push to the image stream expected by the Helm chart.
# * QS_SKIP_CLEANUP - If set and equal to 1 we will not delete the contents of the target directory.
# * QS_ARM - If you are developing on an arm64 machine and using QS_OPTIMIZED=1, your image will not
#                   work on OpenShift which expects amd64. Set QS_ARM=1 to build the image with amd instead.
#                   You need to set up Docker to use buildx in the configuration, make sure
#                   "Use containerd for pulling and storing images" in the Beta section of the "Features In Development"
#                   part of the settings IS DISABLED, and also that

################################################################################################
# Go into the quickstart directory

script_directory="${0%/*}"
cd "$script_directory"
qs_dir="${1}"
if [ -z "${1}" ]; then
  echo "No quickstart directory set"
  exit 1
fi

application="${qs_dir}"
if [ ! -d "../../${qs_dir}" ]; then
  echo "$(pwd)/../../${qs_dir} does not exist"
  exit 1
fi
cd "../../${qs_dir}"

echo "Running the ${qs_dir} tests on OpenShift"
start=$SECONDS

################################################################################################
# Provision server and push imagestream if QS_OPTIMIZED=1
if [ "${QS_OPTIMIZED}" = "1" ]; then
  echo "Optimized build"

  echo "Building application and provisioning server..."
  mvn package -Popenshift wildfly:image

  echo "Creating docker file locally and pushing to image stream"
  # Copy the template docker file to the target directory and build the image
  export image="${application}:latest"
  docker build -t "${image}" target

  if [ "${QS_MULTIARCH}" = "1" ]; then
    # Rebuild with the correct platform for OpenShift (only applicable in a developer environment)
    echo "Rebuilding...."
    docker build  --platform linux/amd64 -t "${image}" target
  fi


  # Log in to the registry and push to the image stream expected by the application
  openshift_project=$(oc project -q)
  oc registry login
  openshift_image_registry=$(oc registry info)
  docker login -u openshift -p $(oc whoami -t)  "${openshift_image_registry}"
  docker tag  "${image}" "${openshift_image_registry}/${openshift_project}/${image}"
  docker push  "${openshift_image_registry}/${openshift_project}/${image}"
  oc set image-lookup "${application}"
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
# Don't quote ${helm_set_arguments} since then it fails when there are none
helm install "${application}" wildfly/wildfly -f charts/helm.yaml  --atomic --timeout=10m0s ${helm_set_arguments}
################################################################################################
# Run tests
echo "running the tests"
pwd
mvn verify -Parq-remote -Dserver.host=https://$(oc get route "${application}" --template='{{ .spec.host }}')

################################################################################################
# Helm uninstall
echo "Running Helm uninstall"
helm uninstall "$application"
if [ "${QS_OPTIMIZED}" = "1" ]; then
   oc delete imagestream ${application}
fi

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

