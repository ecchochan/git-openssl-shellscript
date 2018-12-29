#!/usr/bin/env bash

# Utilize concurrency to build all the docker containers we'll use to test with
echo "Building testable ubuntu linux images... Fair warning, this will take a LONG time"
sleep 5s
declare -a ubuntu_versions=("14.04" "16.04" "18.04" "18.10" "19.04")
function wait_for_jobs()
{
  for job_pid in $(jobs -p); do
    wait "${job_pid}"
  done
}
function build_containers()
{
  for ubuntu_version in "${ubuntu_versions[@]}"; do
    dockerfile="ubuntu-${ubuntu_version//\.}"
    ubuntu_container="ubuntu:${ubuntu_version}-with-sudo"
    echo -e "${green}Building image ${ubuntu_container} from file ${dockerfile}${no_color}"
    docker build -t "${ubuntu_container}" -f "dockerfiles/${dockerfile}" ./dockerfiles &
  done
  # Wait for all jobs to complete
  wait_for_jobs
}
time build_containers


# Now working with the images individually so we can test the script on each container
echo "Running script in each container, this will take even longer"
sleep 5s

temp_directory=$(mktemp -d)
results_file="${temp_directory}/test-results.txt"
green="\033[0;32m"
red="\033[0;31m"
no_color="\033[0m"
script_file="git-openssl.sh"
[[ -f "${results_file}" ]] || rm "${results_file}"

function test_script_on_distro()
{
  tested_ubuntu_version="${1}"
  tested_ubuntu_container="ubuntu:${tested_ubuntu_version}-with-sudo"
  echo "Testing with ${tested_ubuntu_container}"
  if docker run -v "$(pwd):/src" --rm --name "git-openssl-shellscript-on-${tested_ubuntu_version}" "ubuntu:${tested_ubuntu_version}-with-sudo" /bin/bash -c "/src/${script_file}"; then
    echo "Worked on ubuntu:${tested_ubuntu_version}" >> "${results_file}"
  else
    echo "Failed on ubuntu:${tested_ubuntu_version}" >> "${results_file}"
  fi
}

function test_all_distros()
{
  for ubuntu_version in "${ubuntu_versions[@]}"; do
    test_script_on_distro "${ubuntu_version}" &
  done
  # Wait for all jobs to complete
  wait_for_jobs
}

time test_all_distros

printf "\nFinal Results:\n"
cat "${results_file}"
echo -e "${no_color}"
