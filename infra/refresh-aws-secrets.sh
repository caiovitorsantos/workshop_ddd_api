#!/usr/bin/env bash
# AWS Academy credentials expire with each lab session. After pasting the new
# ones into ~/.aws/credentials (Learner Lab → AWS Details → AWS CLI: Show),
# run this to copy them into the GitHub `production` environment used by the
# CD and destroy workflows. Values travel through stdin, never the terminal.
set -euo pipefail

repo="${1:-caiovitorsantos/workshop_ddd_api}"

aws sts get-caller-identity --query Arn --output text

for key in aws_access_key_id aws_secret_access_key aws_session_token; do
  name=$(echo "$key" | tr '[:lower:]' '[:upper:]')
  aws configure get "$key" | gh secret set "$name" --env production --repo "$repo"
  echo "$name updated"
done
