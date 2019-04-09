#!/bin/bash

set -e
set -o pipefail

function deployToScratchOrg {
    sfdx force:org:delete -p -u alertme --json
    sfdx force:org:create -s -f config/project-scratch-def.json -a alertme
    sfdx force:source:push
    sfdx force:user:permset:assign -n dreamhouse
    sfdx force:data:tree:import -p data/sample-data.json
    orgurl=$(sfdx force:org:open -r --json | jq .result.url -r)
    sfdx alerter:twilio:sendalert -m 'Dreamhouse app finished installing in scratch org '$orgurl -p 6507430794
    sfdx alerter:slack:sendalert -m 'Dreamhouse app finished install in scratch org :smile: <'$orgurl'|Scratch Org>'
    testresult=$(sfdx force:apex:test:run -w 10)
    testurl=$(sfdx force:org:open -r -p lightning/setup/ApexTestHistory/home --json | jq .result.url -r)
    sfdx alerter:slack:sendalert -m 'Tests have completed. <'$testurl'|Test Results>'
    return 0
}

function exitHandler {
    errormsg=$(cat error | jq .message -r)
    sfdx alerter:slack:sendalert -m "$errormsg"; exit
}

trap exitHandler INT TERM EXIT
deployToScratchOrg 2>error
trap - INT TERM EXIT