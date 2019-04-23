#!/bin/bash

verbose=$1
exec 3>&1 4>&2 #save original stdout and stderr in case of redirection
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

tmpfile=$(mktemp)

source $DIR/util.sh

function runApexTests {
    set -o pipefail
    set -e
    exec 1>&3 2>&4 # reset stderr and stdout
    $(sfdx force:apex:test:run -w 10 --json > $tmpfile)
    testurl=$(sfdx force:org:open -r -p lightning/setup/ApexTestHistory/home --json | jq .result.url -r)
    orgurl=$(sfdx force:org:open -r -p lightning/n/Property_Explorer --json | jq .result.url -r)
    sfdx alerter:slack:sendalert -m ':thumbsup: Tests have completed with no failures. <'$testurl'|Test Results> see <'$orgurl'|Dreamhouse App> for installed app.' -c '#hackerzone' -e ':thumbsup:'
    return 0
}

trap exitHandler INT TERM EXIT
  runApexTests 
trap - INT TERM EXIT