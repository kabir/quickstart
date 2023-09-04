function installPrerequisites()
{
  echo "Adding bitnami repository"
  helm repo add bitnami https://charts.bitnami.com/bitnami

  helm dependency update todo-backend-chart/
}

function helmInstall() {
    application="${1}"
    helm_set_arguments="$2"
    # Don't quote ${helm_set_arguments} as it breaks the command when empty, and seems to work without
    helm install "${application}" todo-backend-chart/   --atomic --timeout=10m0s ${helm_set_arguments}
}

function cleanPrerequisites()
{
  oc delete all -l template=postgresql-ephemeral-template
  oc delete secret todo-backend-db
  helm repo remove bitnami
}

function isOptimizedModeDisabled() {
  echo "1"
}