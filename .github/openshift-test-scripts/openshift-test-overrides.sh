# These functions are 'overridable in the individual quickstarts

# Installs any prerequisites before doing the Helm install.
# The current directory is the quickstart directory.
# The default is to use the quickstart directory as the name, but in some cases
# a quickstart may need to shorten the name of the application in order to control
# the length of the resources created by OpenShift
#
# Parameters
# 1 - the name of the qs directory (not the full path)
function applicationName() {
  echo "${1}"
}


# Installs any prerequisites before doing the Helm install.
# The current directory is the quickstart directory
#
# Parameters
# 1 - application name
function installPrerequisites()
{
  application="${1}"
  echo "No prerequisites required for ${application}"
}

# Cleans any prerequisites after doing the Helm uninstall.
# The current directory is the quickstart directory
#
# Parameters
# 1 - application name
function cleanPrerequisites()
{
  application="${1}"
  echo "No prerequisites to clean for ${application}"
}

# Performs the 'helm install' command.
# The current directory is the quickstart directory
# Parameters
# 1 - application name
# 2 - set arguments
function helmInstall() {
    application="${1}"
    helm_set_arguments="$2"

    # '--atomic' waits until the pods are ready, and removes everything if something went wrong
    # `--timeout` sets the timeout for the wait.
    # https://helm.sh/docs/helm/helm_install/ has more details
    # Don't quote ${helm_set_arguments} since then it fails when there are none
    helm install "${application}" wildfly/wildfly -f charts/helm.yaml  --atomic --timeout=10m0s ${helm_set_arguments}
}

