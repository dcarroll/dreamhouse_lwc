#!/bin/bash

set -e
set -o pipefail

function deployToScratchOrg {
    sfdx force:org:delete -p -u alertme --json
    sfdx force:org:create -s -f config/project-scratch-def.json -a alertme
    pushoutcome=$(sfdx force:source:push --json 2>&1 | jq . )
    status=$(echo $pushoutcome | jq .status -r)
    if [ "$status" == "1" ]; then
        sfdx alerter:slack:sendalert -m ':thumbsdown: Push failed with the following errors ```'"$(echo $pushoutcome | jq .result[0:2] | jq .[].error -r)"'```' -c '#random' -e ':thumbsdown:'
        exit 1
    fi
    sfdx force:user:permset:assign -n dreamhouse
    sfdx force:data:tree:import -p data/sample-data.json
    orgurl=$(sfdx force:org:open -r --json | jq .result.url -r)
    sfdx alerter:twilio:sendalert -m 'Dreamhouse app finished installing in scratch org '$orgurl -p 6507430794
    sfdx alerter:slack:sendalert -m 'Dreamhouse app finished install in scratch org :smile: <'$orgurl'|Scratch Org>' -c '#random' -e ':lol:'
    testresult=$(sfdx force:apex:test:run -w 10 --json)
    testoutcome=$(echo $testresult | jq .result.summary.outcome -r)
    testurl=$(sfdx force:org:open -r -p lightning/setup/ApexTestHistory/home --json | jq .result.url -r)
    if [ "$testoutcome" == "Failed" ]; then
        sfdx alerter:slack:sendalert -m ':thumbsdown: Tests have completed, with a failure. <'$testurl'|Test Results>' -c '#random' -e ':thumbsdown:'   
    else
        sfdx alerter:slack:sendalert -m ':thumbsup: Tests have completed with no failures. <'$testurl'|Test Results>' -c '#random' -e ':thumbsup:'
    fi
    return 0
}

function exitHandler {
    errormsg=$(cat error | jq .message -r)
    sfdx alerter:slack:sendalert -m "$errormsg"; exit
}

trap exitHandler INT TERM EXIT
deployToScratchOrg 2>error
trap - INT TERM EXIT