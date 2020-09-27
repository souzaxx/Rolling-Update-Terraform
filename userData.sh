#!/bin/bash

echo "Checking that agent is running"
until $(curl --output /dev/null --silent --head --fail http://localhost); do
  printf '.'
  sleep 1
done
exit_code=$?
printf "\nDone\n"
echo "Checking that agent is running"
exit_code=$?
# Can't signal back if the stack is in UPDATE_COMPLETE state, so ignore failures to do so.
# CFN will roll back if it expects the signal but doesn't get it anyway.
echo "Reporting $exit_code exit code to Cloudformation"
/opt/aws/bin/cfn-signal \
  --exit-code "$exit_code" \
  --stack "${CFN_STACK}" \
  --resource ASG \
  --region "${REGION}" || true
