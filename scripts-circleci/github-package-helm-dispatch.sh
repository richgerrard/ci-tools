#!/usr/bin/env bash

VERSION_FILE=${VERSION_FILE:="/workspace/version.txt"}
GITHUB_WORKFLOW=${GITHUB_WORKFLOW:="qr_package-helm-chart.yaml"}

if [ -z "${VERSION}" ]; then
  VERSION=$(cat "$VERSION_FILE")
fi

# Final check that version is set
if [ -z "${VERSION}" ]; then
  echo "ERROR: VERSION could not be determined"
  echo "If version file is in different location than ${VERSION_FILE}"
  echo "before running github_workflow_dispatch.sh script, set a variable:"
  echo "export VERSION_FILE=/path/version.txt"
  echo "or set VERSION variable directly'"
  echo 'export VERSION="$(node|cat ...)"'
  exit 1
fi

# If VERSION is SEMVER set TAG_REF for workflow_dispatch
if echo "${VERSION#v}" | grep -E '^[0-9]+\.[0-9]+\.[0-9]+$'; then
    echo "TAG_REF=v${VERSION#v}"
    TAG_REF="v${VERSION#v}"
fi

if [ -z "${CIRCLE_TAG}" ]; then
  if [ -z "${CIRCLE_BRANCH##*released*}" ]; then
    echo "Skipping ${GITHUB_WORKFLOW} on release branches: ${CIRCLE_BRANCH}"
    exit 0
  fi
fi

if [ "${CIRCLE_BRANCH}" == "update_depConfig_yaml" ]; then
  echo "Skipping ${GITHUB_WORKFLOW} on branch 'update_depConfig_yaml'"
  exit 0
fi

if [ -n "${CIRCLE_TAG}" ]; then
  REF=${CIRCLE_TAG}
elif [ -n "${TAG_REF}" ]; then
  REF=${TAG_REF}
else
  REF=${CIRCLE_BRANCH}
fi

# TODO: Remove this function when package-helm.yaml is no longer used in any component repository
generate_post_data_old()
{
  cat <<EOF
{
  "ref": "${REF}",
  "inputs": {
    "version": "${VERSION}",
    "commitsha": "${CIRCLE_SHA1}"
  }
}
EOF
}

generate_post_data()
{
  cat <<EOF
{
  "ref": "${REF}",
  "inputs": {
    "version": "${VERSION}",
    "commit_sha": "${CIRCLE_SHA1}"
  }
}
EOF
}

echo "Data:"
if [ "${GITHUB_WORKFLOW}" == "qr_package-helm-chart.yaml" ]; then
  generate_post_data
  curl -i --fail --location --request POST "https://api.github.com/repos/${CIRCLE_PROJECT_USERNAME}/${CIRCLE_PROJECT_REPONAME}/actions/workflows/${GITHUB_WORKFLOW}/dispatches" \
    --header "Authorization: token ${GH_ACCESS_TOKEN}" \
    --header "Content-Type: application/json" \
    --header "Accept: application/vnd.github.v3+json" \
    --data "$(generate_post_data)"
else
  generate_post_data_old
  curl -i --fail --location --request POST "https://api.github.com/repos/${CIRCLE_PROJECT_USERNAME}/${CIRCLE_PROJECT_REPONAME}/actions/workflows/${GITHUB_WORKFLOW}/dispatches" \
    --header "Authorization: token ${GH_ACCESS_TOKEN}" \
    --header "Content-Type: application/json" \
    --header "Accept: application/vnd.github.v3+json" \
    --data "$(generate_post_data_old)"
fi
