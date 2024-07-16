# helper_functions.sh

LOG_FILE="$(pwd)/logs/release.log"

# Define color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Error handling function
handle_error() {
    echo -e "${RED}Error occurred: $1${NC}"
    echo -e "Error occurred: $1" >> $LOG_FILE
    exit 1
}

# Spinner function
spinner() {
    local pid=$!
    local delay=0.1
    local spinstr='|/-\'
    while [ "$(ps a | awk '{print $1}' | grep $pid)" ]; do
        local temp=${spinstr#?}
        printf " [%c]  " "$spinstr"
        local spinstr=$temp${spinstr%"$temp"}
        sleep $delay
        printf "\b\b\b\b\b\b"
    done
    printf "    \b\b\b\b"
}

# Function to run commands with optional output redirection and spinner
run_command() {
    echo -e "\n------------------------------" >> $LOG_FILE
    echo "Running command: $@" >> $LOG_FILE
    echo -e "------------------------------\n" >> $LOG_FILE
    if [ "$DEBUG" = true ]; then
        "$@"
    else
        "$@" >> $LOG_FILE 2>&1 &
        spinner
        wait $!
        if [ $? -ne 0 ]; then
            handle_error "Command failed: $@"
        fi
    fi
}

# Check if gh CLI is installed
check_gh_installed() {
    if ! command -v gh &> /dev/null; then
        handle_error "gh CLI tool is not installed. Please install it from https://cli.github.com/ and try again."
    fi
}

# Check if user is logged into gh
check_gh_logged_in() {
    if ! gh auth status &> /dev/null; then
        handle_error "You are not logged into GitHub CLI. Please run 'gh auth login' to authenticate."
    fi
}
