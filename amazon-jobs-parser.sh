#!/bin/bash

# Fail on errors (-e). Make accessing undeclared variables an error (-u).
# See `man bash` or `man bash-builtins` for more details (search for 'set')
set -eu;

# Get current desired job ads. This should also set the global 'jobsFile' property.
function getJobs() {
  # Declare base URL resource.
  local urlResource="https://jobs-us-east.amazon.com/en/search.json";
  # Setup the URL parameters.
  local urlParameters="?";
  urlParameters+="category[]=software-development&";
  urlParameters+="schedule_type_id[]=Full-Time&";
  urlParameters+="normalized_location[]=Arlington%2C%20Virginia%2C%20USA&";
  urlParameters+="normalized_location[]=Herndon%2C%20Virginia%2C%20USA&";
  urlParameters+="normalized_location[]=Baltimore%2C%20Maryland%2C%20USA&";
  urlParameters+="normalized_location[]=USA&";
  urlParameters+="business_category[]=amazon-web-services&";
  urlParameters+="radius=24km&";
  urlParameters+="facets[]=location&";
  urlParameters+="facets[]=business_category&";
  urlParameters+="facets[]=category&";
  urlParameters+="facets[]=schedule_type_id&";
  urlParameters+="facets[]=employee_class&";
  urlParameters+="facets[]=normalized_location&";
  urlParameters+="facets[]=job_function_id&";
  urlParameters+="offset=0&";
  urlParameters+="result_limit=10000&";
  # Compose the final URL.
  local url="${urlResource}${urlParameters}";
  # Declare the filename to send job ads JSON to. Try to embed a timestamp.
  # This should be a non-local/global property.
  jobsFile="jobs.aws.md-local.software-development.$(date +%F--%Hh%Mm%Ss).json";
  curl -sS "${url}" | jq -M . > ${jobsFile};
}

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

# Get current job ads. This should also set the global 'jobsFile' property.
getJobs;
#jobsFile="jobs.aws.json";
#jobsFile="jobs.aws.md-local.software-development.2021-03-02.json";

# Get number of job advertizements. Exit if none were found.
[ -r "${jobsFile}" ] || { echo "Error: the jobs file '${jobsFile}' does not exist or cannot be read" && exit 3; }
echo "Processing jobs file '${jobsFile}'";
totalNumJobs="`jq '.jobs | length' ${jobsFile}`";
numJobs="${totalNumJobs}";
[ ${numJobs} -gt 0 ] || { echo "Error: could not find any jobs in files '${jobsFile}'" && exit 2; }


# _____________________________________________________
# for testing, use a smaller value of numJobs
testNumJobs=5;
[ ${testNumJobs} -gt 0 ] && [ ${numJobs} -gt ${testNumJobs} ] && numJobs="${testNumJobs}";
# _____________________________________________________


# Get specified JSON attribute from specified file
function getJobAttributes() {
  local jobFile="${1}";
  jobId="`jq '.id_icims'   ${jobFile} | sed -e 's@"@@g' -e 's@ @_@g'`";
  team="` jq '.team.label' ${jobFile} | sed -e 's@"@@g' -e 's@ @_@g'`";
  city="` jq '.city'       ${jobFile} | sed -e 's@"@@g' -e 's@ @_@g'`";
  state="`jq '.state'      ${jobFile} | sed -e 's@"@@g' -e 's@ @_@g'`";
}

# Create files for the selected job index
function createJobFiles() {
  local i="${1}";
  echo;
  printf "Processing job # %04d\n" $((i+1));
  local tmpJobFile="`mktemp`";
  jq ".jobs[${i}]" "${jobsFile}" > "${tmpJobFile}";
  getJobAttributes "${tmpJobFile}";

  local jobFilePrefix="${jobDetailsDir}/${city,,}.${state,,}.${team}.${jobId}";
  local jobFile="${jobFilePrefix}.job.json";
  local basicQualificationsFile="${jobFilePrefix}.basic_qualifications.json";
  nomalizedFilesSuffix="normalized.txt";
  local basicQualificationsFile_normalized="${jobFilePrefix}.basic_qualifications.${nomalizedFilesSuffix}";

  echo "  Creating file ${jobFile}";
  mv "${tmpJobFile}" "${jobFile}";
  echo "  Creating file ${basicQualificationsFile}";
  jq ".jobs[${i}].basic_qualifications" "${jobsFile}" > "${basicQualificationsFile}";

  echo "  Creating normalized version of file '${basicQualificationsFile}'"
  echo "    -> '${basicQualificationsFile_normalized}'";
  cp "${basicQualificationsFile}" "${basicQualificationsFile_normalized}";
  normalizeJobFile "${basicQualificationsFile_normalized}";
}

# Cleanup AWJ Jobs 'basic_qualifications' strings
function normalizeJobFile() {
  # Parse filename and ensure it is readable and writable
  f="${1}";
  [ -e "${f}" ] || { echo "Error: File '${f}' does not exist"                   && exit 4; }
  [ -f "${f}" ] || { echo "Error: File '${f}' exists but is not a regular file" && exit 5; }
  [ -r "${f}" ] || { echo "Error: File '${f}' exists but is not readable"       && exit 6; }
  [ -w "${f}" ] || { echo "Error: File '${f}' exists but is not writable"       && exit 7; }
  echo "  Normalizing job file '${f}'";
  # Get rid of leading/trailing quotes
  sed -i -e 's@\(^"\|"$\)@@g' "${f}";
  # Make everthing lowercase
  sed -i -e "s@\(.*\)@\L\1@" "${f}";
  # Replace non-ASCII apostrophes
  sed -i -e "s@’@'@g" "${f}";
  # Get rid of "bullet point" chars '·'. Ensure the result is of the form ". "
  # but avoid duplicated spaces or periods.
  sed -i -e "s@\.\?· \?@. @g" "${f}";
  # Some major splits in qulifications show up with an "OR" surrounded by HTML breaks.
  # In an attempt to be robust, accomodate some whitespace and HTML break on only one side.
  # Also accomodate a period after a trailing HTML break.
  sed -i -e "s@\(<br/> *OR\>\( *\(<br/>\|\.\)*\)*\|\<OR *\(<br/>\|\.\)*\)@.or @g" "${f}";
  # Replace embedded HTML breaks with periods
  sed -i -e "s@[ \.]*<br/>[ \.]*@.@g" "${f}";
  # Replace periods in some terms (to avoid issue with later splitting on periods)
  sed -i -e "s@\(node\|vue\|knockout\|backbone\|react\|salesforce\)\.\(js\|com\)@\1_\2@g" "${f}";
  sed -i -e "s@\.\(net\)@<dot>\1@g" "${f}";
  sed -i -e "s@\(etc\)\.\()\)@\1\2@g" "${f}";
  sed -i -e "s@e\.g\.@eg@g" "${f}";
  sed -i -e "s@u\.s\.@us@g" "${f}";
  # Get rid of redundant explicit "Basic Qualifications" text
  sed -i -e "s@Basic Qualifications:@@i" "${f}";
  # Get rid of leading ". " text
  sed -i -e 's@^ *\. *@@' "${f}";
  # Normalize references to "related field"
  sed -i -e "s@(\(or \)\?\(related field\)),\?@or \2,@g" "${f}";
  # Normalize references to "bs degree"
  sed -i -e "s@\(bs\|\(bachelor\)'\?s\?\)\( degree\)\?@bs degree@g" "${f}";
  sed -i -e "s@\(\<degree\>\)@\L\1@g" "${f}";
  # Normalize numbers to decimals
  sed -i -e "s@\<zero\>@0@g"  "${f}";
  sed -i -e "s@\<one\>@1@g"   "${f}";
  sed -i -e "s@\<two\>@2@g"   "${f}";
  sed -i -e "s@\<three\>@3@g" "${f}";
  sed -i -e "s@\<four\>@4@g"  "${f}";
  sed -i -e "s@\<five\>@5@g"  "${f}";
  sed -i -e "s@\<six\>@6@g"   "${f}";
  sed -i -e "s@\<seven\>@7@g" "${f}";
  sed -i -e "s@\<eight\>@8@g" "${f}";
  sed -i -e "s@\<nine\>@9@g"  "${f}";
  # Change "+ <n+?> years" and "and <n+?> years" to ". <n+?> years"
  sed -i -e "s@ *\(+\|and\) \([[:digit:]]\++\? year\)@. \2@g" "${f}";
  # Sometimes there is an extra space in between "<n>" and "+" (i.e. "5 + years")
  sed -i -e "s@\([[:digit:]]\) \(+ year\)@\1\2@g" "${f}";
  # Add a period before "with <n>+ years" (splitting lines on period should happen later)
  sed -i -e "s@\(with [[:digit:]]\++ years\)@.\1@g" "${f}";
  # Try to normalize "experience" clauses
  # Using the non-greedy/lazy operator "\{-}" in some
  #   Sed (POSIX?) doesn't have non-greedy search...maybe use (gulp) Perl ...
  #     c.f. https://stackoverflow.com/questions/1103149/non-greedy-reluctant-regex-matching-in-sed
  #          perl -pe 's|(http://.*?/).*|\1|'
  sed -i -e "s@minimum of \([0-9]\+\) years\?@\1+ years@g" "${f}";
  # vim non-greedy regex operator '\{-\}' doesn't work for sed ...
  #sed -i -e "s@\(years\) of \(.*\) \(\(experience\>\)\{-1\}\(\(.*experience\)\+\)\)@\1 \4 \2\5@g" "${f}";
  # Some extra splitting to put clauses on new lines
  sed -i -e "s@\(,\) \(an eye for \|and experience\|including\)@\1\n\2@g" "${f}";
  # Split lines on periods
  sed -i -e "s@ *\. *@.\n@g" "${f}";
  # Get rid of blank lines and lines with only periods
  sed -i -e "/^\.*$/d" "${f}";
}

# Define a pipe function to make frequency distribution tabulation easy.
# Sorry that the name is wonky; it matches convention I use elsewhere :grimmace: :grin:
function mysortcountpipe () {
    sort | uniq -c | sort -n
}

# Print some maybe? useful summary metrics of the processed job ad files.
function logSummaryMetrics() {
  local globPattern="${jobDetailsDir}/*${nomalizedFilesSuffix}";
  echo;
  echo "Some metrics about the files '${globPattern}'";
  # Bin these files by md5sum hash (sort the lines first) and count size of each bin. Tail the output.
  local limit=20;
  echo "  Bin these files by md5sum hash (sort the lines first) and count size of each bin. Tail the output to ${limit} lines.";
  echo "    Number of bins: $(md5sum ${globPattern} | awk '{print $1}' | sort -u | wc -l)";
  sort ${globPattern} | md5sum | awk '{print $1}' | mysortcountpipe | tail -${limit}
  # Bin these files by line length and count size of each bin. Skip the last line (the total).
  echo;
  echo "  Bin these files by line length and count size of each bin.";
  wc -l ${globPattern} | awk '{print $1}' | head -n -1 | mysortcountpipe
}

# Create files for each job ad
echo "Processing ${numJobs} of ${totalNumJobs} jobs:";
for (( i=0; i<numJobs; i++ )) {
  createJobFiles ${i};
}
logSummaryMetrics;
