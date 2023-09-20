#!/bin/sh

# This assumes the user has
# * logged in via 'oc login'
# * Added the WildFly Helm repository
#
# Understood environment variables:
# * QS_OPTIMIZED - If set and equal to 1 we will run to run the build optimised. In this case we provision the server
#                   ourselves, create a runtime image, and create and push to the image stream expected by the Helm chart.
# * QS_MAVEN_REPOSITORY - path to the local maven repository, if the standard ~/.m2/repository does not work
# * QS_UNSIGNED_SERVER_CERT - If the OpenShift server is using unsigned certificates for https for client applications,
#                   set this to 1 and a truststore will be created containing the server certificate, and truststore
#                   parameters will be set.
# * QS_SKIP_CLEANUP - If set and equal to 1 we will not delete the contents of the target directory.
# * QS_HELM_INSTALL_TIMEOUT - Default is 10m0s
# * QS_HELM_UNINSTALL_TIMEOUT - Default is 10m0s
# * QS_ARM - If you are developing on an arm64 machine and using QS_OPTIMIZED=1, your image will not
#                   work on OpenShift which expects amd64. Set QS_ARM=1 to build the image with amd instead.
#                   You need to set up Docker to use buildx in the configuration, make sure
#                   "Use containerd for pulling and storing images" in the Beta section of the "Features In Development"
#                   part of the settings IS DISABLED, and also that you have configured the docker engine to use buildx
#                   and created a buildx builder instance with `docker buildx create --use` (`docker buildx ls` should
#                   return an entry with a '*' indicating it is used.

################################################################################################
# Go into the quickstart directory
test_status=0
script_directory="${0%/*}"
script_directory=$(realpath "${script_directory}")
cd "${script_directory}"
qs_dir="${1}"
if [ -z "${1}" ]; then
  echo "No quickstart directory set"
  exit 1
fi

if [ ! -d "../../../../${qs_dir}" ]; then
  echo "$(pwd)/../../../../${qs_dir} does not exist"
  exit 1
fi
cd "../../../../${qs_dir}"

echo "Running the ${qs_dir} tests on OpenShift"
start=$SECONDS

# Determine timeouts
helm_install_timeout=10m0s
helm_uninstall_timeout=10m0s
if [ -n "${QS_HELM_INSTALL_TIMEOUT}" ]; then
  helm_install_timeout="${QS_HELM_INSTALL_TIMEOUT}"
fi
if [ -n "${QS_HELM_UNINSTALL_TIMEOUT}" ]; then
  helm_uninstall_timeout="${QS_HELM_UNINSTALL_TIMEOUT}"
fi


################################################################################################
# Load up the helper functions, possibly overridden in the quickstart
source "${script_directory}/overridable-functions.sh"

qs_override_file="${script_directory}/qs-overrides/${qs_dir}/overridable-functions.sh"
if [ -f "${qs_override_file}" ]; then
  source "${qs_override_file}"
fi

# These functions are from overridable-functions.sh
application=$(applicationName "${qs_dir}")
helm_set_arg_prefix=$(getHelmSetVariablePrefix)

################################################################################################
# Install any pre-requisites. Function is from overridable-functions.sh
echo "Checking if we need to install pre-requisites"
installPrerequisites "${application}"

################################################################################################
# Provision server and push imagestream if QS_OPTIMIZED=1 and disabledOptimized is not set

optimized="0"
if [ "$QS_OPTIMIZED" = 1 ]; then
  disabledOptimized=$(isOptimizedModeDisabled)
  if [ "${disabledOptimized}" = "1" ]; then
    echo "Optimized requested but disabled for this quickstart"
  else
    optimized="1"
  fi
fi

if [ "${optimized}" = "1" ]; then
  echo "Optimized build"

  echo "Building application and provisioning server..."
  mvn -B package -Popenshift wildfly:image -DskipTests ${QS_MAVEN_REPOSITORY}

  echo "Creating docker file locally and pushing to image stream"
  # Copy the template docker file to the target directory and build the image
  export image="${application}:latest"
  docker build -t "${image}" target

  if [ "${QS_ARM}" = "1" ]; then
    # Rebuild with the correct platform for OpenShift (only applicable in a developer environment)
    echo "Rebuilding for linux/amd64...."
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
if [ "${optimized}" = "1" ]; then
   helm_set_arguments=" --set ${helm_set_arg_prefix}build.enabled=false"
fi
additional_arguments="No additional arguments"
if [ -n "${helm_set_arguments}" ]; then
  additional_arguments="Additional arguments: ${helm_set_arguments}"
fi

echo "Performing Helm install and waiting for completion.... (${additional_arguments})"
# helmInstall is from overridable-functions.sh
helmInstall "${application}" "${helm_set_arguments}"

################################################################################################
# Run tests
echo "running the tests"
pwd

# TODO temp
set -x
route=$(oc get route "${application}" --template='{{ .spec.host }}')
truststore_properties=""
if [ "${QS_UNSIGNED_SERVER_CERT}" = "1" ]; then
  pushd "${script_directory}/InstallCert"
  if [ ! -f "jssecacerts" ]; then
    # We haven't already created a truststore so create one
    # We use a pre-compiled version of InstallCert since we don't have javac in the image created by the Dockerfile
    echo 1 | java InstallCert "${route}" changeit
  fi
  popd

  #Set the system properties to use the truststore
  truststore_properties="-Djavax.net.ssl.trustStore=${script_directory}/InstallCert/jssecacerts -Djavax.net.ssl.trustStorePassword=changeit"
fi


mvn -B verify -Parq-remote -Dserver.host=https://${route} ${QS_MAVEN_REPOSITORY} ${truststore_properties}
# TODO temp
set +x

if [ "$?" != "0" ]; then
  test_status=1
fi
################################################################################################
# Helm uninstall
echo "Running Helm uninstall"
helm uninstall "${application}" --wait --timeout=10m0s
if [ "${QS_OPTIMIZED}" = "1" ]; then
   oc delete imagestream "${application}"
fi

################################################################################################
# Clean pre-requisites (cleanPrerequisites is fromm overridable-functions.sh)
echo "Checking if we need to clean pre-requisites"
cleanPrerequisites "${application}"


################################################################################################
# Delete target directory to conserve disk space when running all the tests
if [ "${SKIP_CLEANUP}" = "1" ]; then
  echo "Skipping cleanup..."
else
  echo "Deleting target directory..."
  rm -rf target
fi

end=$SECONDS
duration=$((end - start))
echo "${application} tests run in $(($duration / 60))m$(($duration % 60))s."

exit ${test_status}