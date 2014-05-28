#!/usr/bin/env bash

# Check for bash (and that we haven't already been sourced).
[ -z "$BASH_VERSION" -o -n "$MAVEN_COLOR_SCRIPT_SOURCED" ] && return

# Formatting constants
export BRIGHT=`tput bold`
export UNDERLINE_ON=`tput smul`
export UNDERLINE_OFF=`tput rmul`
export TEXT_BLACK=`tput setaf 0`
export TEXT_RED=`tput setaf 1`
export TEXT_GREEN=`tput setaf 2`
export TEXT_YELLOW=`tput setaf 3`
export TEXT_BLUE=`tput setaf 4`
export TEXT_MAGENTA=`tput setaf 5`
export TEXT_CYAN=`tput setaf 6`
export TEXT_WHITE=`tput setaf 7`
export BACKGROUND_BLACK=`tput setab 0`
export BACKGROUND_RED=`tput setab 1`
export BACKGROUND_GREEN=`tput setab 2`
export BACKGROUND_YELLOW=`tput setab 3`
export BACKGROUND_BLUE=`tput setab 4`
export BACKGROUND_MAGENTA=`tput setab 5`
export BACKGROUND_CYAN=`tput setab 6`
export BACKGROUND_WHITE=`tput setab 7`
export RESET_FORMATTING=`tput sgr0`

# Variables for output colors
export GENERIC_COLOR=${BRIGHT}${TEXT_BLACK}
export HEADER_COLOR=${TEXT_BLUE}
export BASIC_INFO_COLOR=${BRIGHT}${TEXT_BLACK}

export SUCCESS_COLOR=${BRIGHT}${TEXT_GREEN}
export WARN_COLOR=${BRIGHT}${TEXT_YELLOW}
export FAIL_COLOR=${BRIGHT}${TEXT_RED}
export ERROR_COLOR=${BRIGHT}${TEXT_RED}

export TEST_RUN_COLOR=${BRIGHT}${TEXT_GREEN}
export TEST_SKIP_COLOR=${BRIGHT}${TEXT_YELLOW}
export TEST_FAIL_COLOR=${BRIGHT}${TEXT_RED}
export TEST_ERROR_COLOR=${BRIGHT}${TEXT_RED}

# Wrapper function for Maven's mvn command.
mvn-color()
{
  # echo " WARN " | perl -n -e "print if s/(.*\ warn\ .*)/\1/gi" looser matching
  # Filter mvn output using sed
  mvn $@ | sed -e "s/\(\[INFO\]\ -------.*\)/${HEADER_COLOR}\1${RESET_FORMATTING}/g" \
               -e "s/\(\[INFO\]\ Building\ .*\)/${HEADER_COLOR}\1${RESET_FORMATTING}/g" \
               -e "s/\(^---.*\)/${HEADER_COLOR}\1${RESET_FORMATTING}/g" \
               -e "s/\(^\ T\ E\ S\ T\ S\)/${HEADER_COLOR}\1${RESET_FORMATTING}/g" \
               -e "s/\(^Running .*\)/${BASIC_INFO_COLOR}\1${RESET_FORMATTING}/g" \
               -e "s/\(.*Test.*:.*\.\..*\)/${TEST_FAIL_COLOR}\1${RESET_FORMATTING}/g" \
               -e "s/\(.* test.*:.*\.\..*\)/${TEST_FAIL_COLOR}\1${RESET_FORMATTING}/g" \
               -e "s/\(\[INFO\]\ ---\ .*\)/${BASIC_INFO_COLOR}\1${RESET_FORMATTING}/g" \
               -e "s/\(\[INFO\]\ BUILD\ SUCCESS\)/${SUCCESS_COLOR}\1${RESET_FORMATTING}/g" \
               -e "s/\(\[INFO\]\ BUILD\ FAILURE\)/${FAIL_COLOR}\1${RESET_FORMATTING}/g" \
               -e "s/\(\[INFO\]\ Total\ time:\ .*\)/${HEADER_COLOR}\1${RESET_FORMATTING}/g" \
               -e "s/\(\[INFO\]\ Finished\ at:\ .*\)/${HEADER_COLOR}\1${RESET_FORMATTING}/g" \
               -e "s/\(\[INFO\]\ Final\ Memory:\ .*\)/${HEADER_COLOR}\1${RESET_FORMATTING}/g" \
               -e "s/\(\[WARNING\].*\)/${WARN_COLOR}\1${RESET_FORMATTING}/g" \
               -e "s/\(.*\ WARN\ .*\)/${WARN_COLOR}\1${RESET_FORMATTING}/g" \
               -e "s/\(.*\ warn\ .*\)/${WARN_COLOR}\1${RESET_FORMATTING}/g" \
               -e "s/\(.*\ Warn\ .*\)/${WARN_COLOR}\1${RESET_FORMATTING}/g" \
               -e "s/\(\[ERROR\].*\)/${ERROR_COLOR}\1${RESET_FORMATTING}/g" \
               -e "s/\(.*\ ERROR\ .*\)/${ERROR_COLOR}\1${RESET_FORMATTING}/g" \
               -e "s/\(.*\ error\ .*\)/${ERROR_COLOR}\1${RESET_FORMATTING}/g" \
               -e "s/\(.*\ Error\ .*\)/${ERROR_COLOR}\1${RESET_FORMATTING}/g" \
               -e "s/Tests run: \([^,]*\), Failures: \([^,]*\), Errors: \([^,]*\), Skipped: \([^,]*\), Time elapsed: \([^,]*\)/${GENERIC_COLOR}Tests run: ${RESET_FORMATTING}${TEST_RUN_COLOR}\1${RESET_FORMATTING}${GENERIC_COLOR}, Failures: ${RESET_FORMATTING}${TEST_FAIL_COLOR}\2${RESET_FORMATTING}${GENERIC_COLOR}, Errors: ${RESET_FORMATTING}${TEST_ERROR_COLOR}\3${RESET_FORMATTING}${GENERIC_COLOR}, Skipped: ${RESET_FORMATTING}${TEST_SKIP_COLOR}\4${RESET_FORMATTING}${GENERIC_COLOR}, Time elapsed: \5${RESET_FORMATTING}/g" \
               -e "s/\(.*\)/${GENERIC_COLOR}\1${RESET_FORMATTING}/g"

  # Make sure formatting is reset
  echo -ne ${RESET_FORMATTING}
}

# Wrapper function for Maven's mvn command to reduce verbose output
mvn-color-compact()
{
  # Filter mvn output using sed
  mvn $@ | sed -n -e "s/\(\[INFO\]\ -------.*\)/${HEADER_COLOR}\1${RESET_FORMATTING}/gp" \
               -n -e "s/\(\[INFO\]\ Building\ .*\)/${HEADER_COLOR}\1${RESET_FORMATTING}/gp" \
               -n -e "s/\(^---.*\)/${HEADER_COLOR}\1${RESET_FORMATTING}/gp" \
               -n -e "s/\(^\ T\ E\ S\ T\ S\)/${HEADER_COLOR}\1${RESET_FORMATTING}/gp" \
               -n -e "s/\(^Running .*\)/${BASIC_INFO_COLOR}\1${RESET_FORMATTING}/gp" \
               -n -e "s/\(.*Test.*:.*\.\..*\)/${TEST_FAIL_COLOR}\1${RESET_FORMATTING}/gp" \
               -n -e "s/\(.* test.*:.*\.\..*\)/${TEST_FAIL_COLOR}\1${RESET_FORMATTING}/gp" \
               -n -e "s/\(\[INFO\]\ ---\ .*\)/${BASIC_INFO_COLOR}\1${RESET_FORMATTING}/gp" \
               -n -e "s/\(\[INFO\]\ BUILD\ SUCCESS\)/${SUCCESS_COLOR}\1${RESET_FORMATTING}/gp" \
               -n -e "s/\(\[INFO\]\ BUILD\ FAILURE\)/${FAIL_COLOR}\1${RESET_FORMATTING}/gp" \
               -n -e "s/\(\[INFO\]\ Total\ time:\ .*\)/${HEADER_COLOR}\1${RESET_FORMATTING}/gp" \
               -n -e "s/\(\[INFO\]\ Finished\ at:\ .*\)/${HEADER_COLOR}\1${RESET_FORMATTING}/gp" \
               -n -e "s/\(\[INFO\]\ Final\ Memory:\ .*\)/${HEADER_COLOR}\1${RESET_FORMATTING}/gp" \
               -n -e "s/\(\[WARNING\].*\)/${WARN_COLOR}\1${RESET_FORMATTING}/gp" \
               -n -e "s/\(.*\ WARN\ .*\)/${WARN_COLOR}\1${RESET_FORMATTING}/gp" \
               -n -e "s/\(.*\ warn\ .*\)/${WARN_COLOR}\1${RESET_FORMATTING}/gp" \
               -n -e "s/\(.*\ Warn\ .*\)/${WARN_COLOR}\1${RESET_FORMATTING}/gp" \
               -n -e "s/\(\[ERROR\].*\)/${ERROR_COLOR}\1${RESET_FORMATTING}/gp" \
               -n -e "s/\(.*\ ERROR\ .*\)/${ERROR_COLOR}\1${RESET_FORMATTING}/gp" \
               -n -e "s/\(.*\ error\ .*\)/${ERROR_COLOR}\1${RESET_FORMATTING}/gp" \
               -n -e "s/\(.*\ Error\ .*\)/${ERROR_COLOR}\1${RESET_FORMATTING}/gp" \
               -n -e "s/Tests run: \([^,]*\), Failures: \([^,]*\), Errors: \([^,]*\), Skipped: \([^,]*\), Time elapsed: \([^,]*\)/${GENERIC_COLOR}Tests run: ${RESET_FORMATTING}${TEST_RUN_COLOR}\1${RESET_FORMATTING}${GENERIC_COLOR}, Failures: ${RESET_FORMATTING}${TEST_FAIL_COLOR}\2${RESET_FORMATTING}${GENERIC_COLOR}, Errors: ${RESET_FORMATTING}${TEST_ERROR_COLOR}\3${RESET_FORMATTING}${GENERIC_COLOR}, Skipped: ${RESET_FORMATTING}${TEST_SKIP_COLOR}\4${RESET_FORMATTING}${GENERIC_COLOR}, Time elapsed: \5${RESET_FORMATTING}/gp"

  # Make sure formatting is reset
  echo -ne ${RESET_FORMATTING}
}

# Wrapper function for Maven's mvn command to reduce verbose output
mvn-color-super-compact()
{
  # Filter mvn output using sed
  mvn $@ | sed -n -e "s/\(\[INFO\]\ Building\ .*\)/${HEADER_COLOR}\1${RESET_FORMATTING}/gp" \
               -n -e "s/\(^Running .*\)/${BASIC_INFO_COLOR}\1${RESET_FORMATTING}/gp" \
               -n -e "s/\(.*Test.*:.*\.\..*\)/${TEST_FAIL_COLOR}\1${RESET_FORMATTING}/gp" \
               -n -e "s/\(.* test.*:.*\.\..*\)/${TEST_FAIL_COLOR}\1${RESET_FORMATTING}/gp" \
               -n -e "s/\(\[INFO\]\ BUILD\ SUCCESS\)/${SUCCESS_COLOR}\1${RESET_FORMATTING}/gp" \
               -n -e "s/\(\[INFO\]\ BUILD\ FAILURE\)/${FAIL_COLOR}\1${RESET_FORMATTING}/gp" \
               -n -e "s/\(\[WARNING\].*\)/${WARN_COLOR}\1${RESET_FORMATTING}/gp" \
               -n -e "s/\(.*\ WARN\ .*\)/${WARN_COLOR}\1${RESET_FORMATTING}/gp" \
               -n -e "s/\(.*\ warn\ .*\)/${WARN_COLOR}\1${RESET_FORMATTING}/gp" \
               -n -e "s/\(.*\ Warn\ .*\)/${WARN_COLOR}\1${RESET_FORMATTING}/gp" \
               -n -e "s/\(\[ERROR\].*\)/${ERROR_COLOR}\1${RESET_FORMATTING}/gp" \
               -n -e "s/\(.*\ ERROR\ .*\)/${ERROR_COLOR}\1${RESET_FORMATTING}/gp" \
               -n -e "s/\(.*\ error\ .*\)/${ERROR_COLOR}\1${RESET_FORMATTING}/gp" \
               -n -e "s/\(.*\ Error\ .*\)/${ERROR_COLOR}\1${RESET_FORMATTING}/gp" \
               -n -e "s/Tests run: \([^,]*\), Failures: \([^,]*\), Errors: \([^,]*\), Skipped: \([^,]*\), Time elapsed: \([^,]*\)/${GENERIC_COLOR}T: ${RESET_FORMATTING}${TEST_RUN_COLOR}\1${RESET_FORMATTING}${GENERIC_COLOR}, F: ${RESET_FORMATTING}${TEST_FAIL_COLOR}\2${RESET_FORMATTING}${GENERIC_COLOR}, E: ${RESET_FORMATTING}${TEST_ERROR_COLOR}\3${RESET_FORMATTING}${GENERIC_COLOR}, S: ${RESET_FORMATTING}${TEST_SKIP_COLOR}\4${RESET_FORMATTING}/gp"

  # Make sure formatting is reset
  echo -ne ${RESET_FORMATTING}
}

# Override the mvn command with the colorized one.
alias mvn="mvn-color"
# Add a mvnc command to provide less verbose output
alias mvn-c="mvn-color-compact"
alias mvn-sc="mvn-color-super-compact"

export MAVEN_COLOR_SCRIPT_SOURCED=true