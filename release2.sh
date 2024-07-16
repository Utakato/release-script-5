#!/bin/bash

clear

LIVE_BRANCH="main"
# Define log file path
LOG_FILE="$(pwd)/$LOG_FILE"

# Check for debug flag
DEBUG=false
if [[ "$1" == "debug" ]]; then
    DEBUG=true
fi

# Source the helper functions
source ./helper_functions.sh

# Ensure the logs directory exists
mkdir -p "$(pwd)/logs"

# Check if gh CLI is installed and user is logged in
check_gh_installed
check_gh_logged_in

# Source the release version from the file
if [ -f release_version.env ]; then
    source release_version.env
else
    handle_error "Release version file not found. Please run the first script to set the release version."
fi

# Check if the release version is set in the environment variable
if [ -z "$RELEASE_VERSION" ]; then
    handle_error "Please set the release version environment variable (RELEASE_VERSION)."
fi

# Validate the release version format
if [[ ! "$RELEASE_VERSION" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    handle_error "Invalid release version format. RELEASE_VERSION should be in the format vX.X.X (e.g., v1.0.0)."
fi

echo -e "${GREEN}Release version is valid: $RELEASE_VERSION${NC}"

# # Log the release version
echo -e "\n||||||||||||||||||||||||||||||" >> $LOG_FILE
echo -e "Starting second phase of release process for version: $RELEASE_VERSION" >> $LOG_FILE
echo -e "||||||||||||||||||||||||||||||\n" >> $LOG_FILE

# Create a new release tag
echo -e "${BLUE}Creating a new release tag...${NC}"
run_command git tag -a $RELEASE_VERSION -m "Release $RELEASE_VERSION"
echo -e "${GREEN}Created new release tag${NC}"

# Push the release tag
echo -e "${BLUE}Pushing the $RELEASE_VERSION release tag to the remote repository...${NC}"
run_command git push origin $RELEASE_VERSION
echo -e "${GREEN}Pushed the $RELEASE_VERSION release tag to the remote repository${NC}"

# Create a new release with auto-generated release notes
echo -e "${BLUE}Creating a new release with auto-generated release notes...${NC}"
run_command gh release create $RELEASE_VERSION --generate-notes
echo -e "${GREEN}Created a new release with auto-generated release notes${NC}"

# Sync live and dev branches
echo -e "${BLUE}Syncing live and dev branches...${NC}"
run_command git checkout dev
run_command git pull origin dev
run_command git pull origin $LIVE_BRANCH
run_command git merge $LIVE_BRANCH
run_command git push origin dev

run_command git checkout $LIVE_BRANCH
run_command git pull origin $LIVE_BRANCH
run_command git merge dev
run_command git push origin $LIVE_BRANCH
echo -e "${GREEN}Synced live and dev branches${NC}"

# Get the latest commit hash
LATEST_COMMIT_HASH=$(git rev-parse HEAD)
if [ $? -ne 0 ]; then
    handle_error "Failed to get the latest commit hash."
fi
echo "Saved latest commit for live branch to update kubernetes deployment.yaml"

# Find kubernetes manifests
kubernetes=~/mock-kubernetes-manifests
if [ -z "$kubernetes" ]; then
    handle_error "Kubernetes manifests directory not found."
fi
echo "Found kubernetes manifests at $kubernetes"
cd $kubernetes

# kubernetes=$(find ~ -type d -name 'kubernetes-manifests' -print -quit)
# if [ -z "$kubernetes" ]; then
#     handle_error "Kubernetes manifests directory not found."
# fi
# echo "Found kubernetes manifests at $kubernetes"
# cd $kubernetes

run_command git checkout master
run_command git pull
run_command git checkout -b cms-release-$RELEASE_VERSION
echo -e "${GREEN}Created a new release branch${NC}"

# Update deployment.yaml with the latest commit hash
sed_command="s|image: registry.uw.systems/uwcouk-cms/uw.co.uk-cms-v2:[0-9a-f]+|image: registry.uw.systems/uwcouk-cms/uw.co.uk-cms-v2:$LATEST_COMMIT_HASH|g"
run_command sed -i '' -e "$sed_command" prod-aws/uwcouk-cms/cms-v2/deployment.yaml
echo "Updated deployment.yaml with latest commit hash: $LATEST_COMMIT_HASH"

# Create PR
run_command gh pr create --title "Release CMS $RELEASE_VERSION" --body "Automated release notes for $RELEASE_VERSION" --base "master" --head "cms-release-$RELEASE_VERSION"
echo -e "${GREEN}Created PR for release CMS $RELEASE_VERSION${NC}"
echo -e "${YELLOW}Once it is approved, the new release will be deployed to production"
echo -e "${YELLOW}Hopefully it's not Friday, good luck!${NC}"