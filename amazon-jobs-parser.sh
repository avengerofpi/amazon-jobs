#!/bin/bash

# Fail on errors (-e). Make accessing undeclared variables an error (-u).
# See `man bash` or `man bash-builtins` for more details (search for 'set')
set -eu;

# Try to create a fresh job details directory to use
jobDetailsDir="";
jobDetailsDirDefault="jobDetails";
for suffix in _{01..99}; do
  putative_jobDetailsDir="${jobDetailsDirDefault}${suffix}";
  mkdir -p "${putative_jobDetailsDir}";
  check_putative_jobDetailsDir="`find ${putative_jobDetailsDir} -mindepth 1 | head -1`";
  if [ -z "${check_putative_jobDetailsDir}" ]; then
    jobDetailsDir="${putative_jobDetailsDir}";
    break;
  fi;
done;

# Log result of trying to choose a job details directory. Exit if selection failed.
if [ -n "${jobDetailsDir}" ]; then
  echo "Using job details directory '${jobDetailsDir}'";
else
  echo "Error: failed to choose a 'job details directory' to use";
  exit 1;
fi;

# Get number of job advertizements. Exit if none were found.
#jobsFile="jobs.aws.json";
jobsFile="jobs.aws.md-local.software-development.2021-03-02.json";
[ -r "${jobsFile}" ] || { echo "Error: the jobs file '${jobsFile}' does not exist or cannot be read" && exit 3; }
echo "Processing jobs file '${jobsFile}'";
totalNumJobs="`jq '.jobs | length' ${jobsFile}`";
numJobs="${totalNumJobs}";
[ ${numJobs} -gt 0 ] || { echo "Error: could not find any jobs in files '${jobsFile}'" && exit 2; }


# for testing, use a smaller value of numJobs
[ ${numJobs} -gt 5 ] && numJobs=5;

# Get specified JSON attribute from specified file
function getJobAttributes() {
  local jobFile="${1}";
  jobId="`jq '.id_icims'   ${jobFile} | sed -e 's@"@@g' -e 's@ @_@g'`";
  team="` jq '.team.label' ${jobFile} | sed -e 's@"@@g' -e 's@ @_@g'`";
  city="` jq '.city'       ${jobFile} | sed -e 's@"@@g' -e 's@ @_@g'`";
  state="`jq '.state'      ${jobFile} | sed -e 's@"@@g' -e 's@ @_@g'`";
}

# Create an files for each job ad
echo "Processing ${numJobs} of ${totalNumJobs} jobs:";
for (( i=0; i<numJobs; i++ )) {
  tmpJobFile="`mktemp`";
  jq ".jobs[${i}]" "${jobsFile}" > "${tmpJobFile}";
  getJobAttributes "${tmpJobFile}";

  jobFilePrefix="${jobDetailsDir}/${city,,}.${state,,}.${team}.${jobId}";
  jobFile="${jobFilePrefix}.job.json";
  basicQualificationsFile="${jobFilePrefix}.basic_qualifications.json";

  echo "  Creating file ${jobFile}";
  mv "${tmpJobFile}" "${jobFile}";
  echo "  Creating file ${basicQualificationsFile}";
  jq ".jobs[${i}].basic_qualifications" "${jobsFile}" > "${basicQualificationsFile}";
}
