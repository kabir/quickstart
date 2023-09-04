# The main script to run the quickstarts
# It iterates over all found quickstart directories, ignoring the ones found in
# excluded-directories.txt, and runs the run-quickstart-test-on-openshift-for each of them

# Runs a single quickstart
#
# Parameters
# 1 - the directory containing this script
# 2 - the name of the quickstart directory
function runQuickstart() {
  script_dir="${1}"
  qs_dir="${2}"

  echo "================================================================="
  echo "Running tests for ${qs_dir} "
  echo "================================================================="

  "${script_dir}"/run-quickstart-test-on-openshift.sh "${qs_dir}"
}

script_directory="${0%/*}"
script_directory=$(realpath "${script_directory}")
cd "${script_directory}"

IFS=$'\r\n' GLOBIGNORE='*' command eval  'excluded_dirs=($(cat excluded-directories.txt))'
echo "${excluded_dirs[@]}"

basedir="${script_directory}/../.."
for file in ${basedir}/*; do
  fileName=$(basename "${file}")
  if [ ! -d "${file}" ]; then
    # echo "${fileName} is not a directory!"
    continue
  fi

  grep -q "^${fileName}$" excluded-directories.txt
  if [ "$?" = "0" ]; then
    # echo "Skipping ${fileName}!"
    continue
  fi

  runQuickstart "${script_directory}" "${fileName}"
done