#!/bin/bash

clear

LIVE_BRANCH="main"

# Check for debug flag
DEBUG=false
if [[ "$1" == "debug" ]]; then
    DEBUG=true
fi

# Source the helper functions
source ./helper_functions.sh

# Ensure the logs directory exists
mkdir -p logs

# Check if gh CLI is installed and user is logged in
check_gh_installed
check_gh_logged_in

# Get the latest release version using gh CLI
LATEST_RELEASE=$(gh release list --limit 1 --json tagName --jq '.[0].tagName' 2>/dev/null)
if [ -z "$LATEST_RELEASE" ]; then
    LATEST_RELEASE="none"
    echo -e "${YELLOW}No previous release version found.${NC}"
else
    echo -e "${YELLOW}Previous release version: ${LATEST_RELEASE}${NC}"
fi
# Accept the release version as a command-line argument

echo -e "\n${BLUE}Checking merges from last release${NC}"
run_command git checkout $LIVE_BRANCH
run_command git pull
run_command git checkout dev
run_command git pull

git --no-pager log --left-right --cherry-pick --oneline --merges $LATEST_RELEASE...dev --not $LIVE_BRANCH
echo -e "${GREEN}Merged PRs found.${NC}"

echo -e "\n${BLUE}Please enter the release version (vX.X.X):${NC}"
read -p "" RELEASE_VERSION

# Check if the release version is provided
if [ -z "$RELEASE_VERSION" ]; then
    handle_error "Please provide the release version as an argument. (vX.X.X)"
fi

# Validate the release version format
if [[ ! "$RELEASE_VERSION" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    handle_error "Invalid release version format. Please provide the release version in the format vX.X.X (e.g., v1.0.0)."
fi

echo -e "${GREEN}Release version is valid: $RELEASE_VERSION${NC}"

# Save the release version to a file
echo "export RELEASE_VERSION=$RELEASE_VERSION" > release_version.env

# Log the release version
echo -e "\n||||||||||||||||||||||||||||||" >> logs/release.log
echo -e "Starting release process for version: $RELEASE_VERSION" >> logs/release.log
echo -e "||||||||||||||||||||||||||||||\n" >> logs/release.log

# Switch to the dev branch
echo -e "\n${BLUE}Switching to dev branch...${NC}"
run_command git checkout dev
echo -e "${GREEN}Switched to dev branch${NC}"

# Pull the latest changes from dev and live branches
echo -e "\n${BLUE}Pulling the latest changes from dev and live branches...${NC}"
run_command git pull origin dev
run_command git pull origin $LIVE_BRANCH
echo -e "${GREEN}Pulled the latest changes from dev and live branches${NC}"

# Create a new release candidate branch
echo -e "\n${BLUE}Creating a new release candidate branch:...${NC}"
run_command git checkout -b release/$RELEASE_VERSION
echo -e "${GREEN}Created a new release candidate branch: release/$RELEASE_VERSION${NC}"

echo -e "\n${BLUE}Pushing the new branch to the remote repository...${NC}"
run_command git push --set-upstream origin release/$RELEASE_VERSION
echo -e "${GREEN}Pushed the new branch to the remote repository${NC}"

# Use gh CLI to create a pull request for the release
echo -e "\n${BLUE}Creating a pull request for the release...${NC}"
run_command gh pr create --title "Release $RELEASE_VERSION" --body "Automated release notes for $RELEASE_VERSION" --base "$LIVE_BRANCH" --head "release/$RELEASE_VERSION"
echo -e "${GREEN}Created PR for release $RELEASE_VERSION${NC}"
echo -e "${YELLOW}After the "release" PR is approved, please run the second script to finish the release and deploy to kubernetes.${NC}"
