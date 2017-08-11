#!/usr/bin/env bash

################################################################################
# tf_pylint.sh
#
# Run TensorFlow pylint. Ripped out of the TensorFlow CI script 
# tensorflow/tools/ci_build/ci_sanity.sh
#
# Run this script from the root of your TensorFlow source code tree.
# If you haven't copied the TensorFlow pylintrc to the same directory as this
# script, will download it for you.
#
# Usage:
# ~/scripts/tf_pylint [--incremental]
# Options:
#   --incremental  Performs check on only the python files changed in the
#                  last non-merge git commit.

################################################################################
# CONSTANTS

# You may need to modify these to work on your local machine.

_TF_PYLINT_RC_URL="https://raw.githubusercontent.com/tensorflow/tensorflow/master/tensorflow/tools/ci_build/pylintrc"

# Number of CPUs; hard-coded on a Mac
if [[ -f /proc/cpuinfo ]]; then
  _N_CPUS=$(grep -c ^processor /proc/cpuinfo)
else
  _N_CPUS=8
fi

# Location of this script. May need to be modified if the path has funky stuff
# like symlinks.
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Directory where we stash auxiliary files
AUX_FILES_DIR="${SCRIPT_DIR}/pylint_files"

PYTHON2_VERSION="2.7"
PYTHON3_VERSION="3.6"


# Run pylint from virtualenv because it tends not to be working on my Mac
PYTHON2_VIRTUALENV="${AUX_FILES_DIR}/py2_virtualenv"
PYTHON3_VIRTUALENV="${AUX_FILES_DIR}/py3_virtualenv"

PYLINTRC_FILE="${AUX_FILES_DIR}/pylintrc"

PYTHON2_PACKAGES="${PYTHON2_VIRTUALENV}/lib/python${PYTHON2_VERSION}/site-packages"
PYTHON3_PACKAGES="${PYTHON3_VIRTUALENV}/lib/python${PYTHON3_VERSION}/site-packages"

PYTHON2_EXEC="${PYTHON2_VIRTUALENV}/bin/python"
PYTHON3_EXEC="${PYTHON3_VIRTUALENV}/bin/python"

################################################################################
# DOWNLOAD AUXILIARY FILES
#
# These steps should only happen once


# Don't recreate the virtualenv every time
if [[ ! -d ${PYTHON2_VIRTUALENV} ]]; then
  echo "Creating ${PYTHON2_VIRTUALENV}"
  virtualenv --python=python${PYTHON2_VERSION} ${PYTHON2_VIRTUALENV}
  ${PYTHON2_VIRTUALENV}/bin/pip install pylint
fi
if [[ ! -d ${PYTHON3_VIRTUALENV} ]]; then
  echo "Creating ${PYTHON3_VIRTUALENV}"
  virtualenv --python=python${PYTHON3_VERSION} ${PYTHON3_VIRTUALENV}
  ${PYTHON3_VIRTUALENV}/bin/pip install pylint
fi

# Download the TensorFlow pylintrc file if needed
if [[ ! -f "${PYLINTRC_FILE}" ]]; then
  wget -O ${PYLINTRC_FILE} ${_TF_PYLINT_RC_URL}
fi


################################################################################
# FUNCTIONS


# Helper functions from the original TensorFlow CI script.
die() {
  echo $@
  exit 1
}


# Function from original TensorFlow build script, modified a bit so it
# actually runs outside the CI server.
do_pylint() {
  # Usage: do_pylint (PYTHON2 | PYTHON3) [--incremental]
  #
  # Options:
  #   --incremental  Performs check on only the python files changed in the
  #                  last non-merge git commit.

  # Use this list to whitelist pylint errors
  ERROR_WHITELIST="^tensorflow/python/framework/function_test\.py.*\[E1123.*noinline "\
"^tensorflow/python/platform/default/_gfile\.py.*\[E0301.*non-iterator "\
"^tensorflow/python/platform/default/_googletest\.py.*\[E0102.*function\salready\sdefined "\
"^tensorflow/python/feature_column/feature_column_test\.py.*\[E0110.*abstract-class-instantiated "\
"^tensorflow/contrib/layers/python/layers/feature_column\.py.*\[E0110.*abstract-class-instantiated "\
"^tensorflow/python/platform/gfile\.py.*\[E0301.*non-iterator"

  echo "ERROR_WHITELIST=\"${ERROR_WHITELIST}\""

  if [[ $# != "1" ]] && [[ $# != "2" ]]; then
    echo "Invalid syntax when invoking do_pylint"
    echo "Usage: do_pylint (PYTHON2 | PYTHON3) [--incremental]"
    return 1
  fi

  if [[ $1 == "PYTHON2" ]]; then
    PYLINT_BIN="${PYTHON2_EXEC} ${PYTHON2_PACKAGES}/pylint/lint.py"
  elif [[ $1 == "PYTHON3" ]]; then
    PYLINT_BIN="${PYTHON3_EXEC} ${PYTHON3_PACKAGES}/pylint/lint.py"
  else
    echo "Unrecognized python version (PYTHON2 | PYTHON3): $1"
    return 1
  fi

  if [[ "$2" == "--incremental" ]]; then
    PYTHON_SRC_FILES=$(get_py_files_to_check --incremental)

    if [[ -z "${PYTHON_SRC_FILES}" ]]; then
      echo "do_pylint will NOT run due to --incremental flag and due to the "\
"absence of Python code changes in the last commit."
      return 0
    else
      # For incremental builds, we still check all Python files in cases there
      # are function signature changes that affect unchanged Python files.
      PYTHON_SRC_FILES=$(get_py_files_to_check)
    fi
  elif [[ -z "$2" ]]; then
    PYTHON_SRC_FILES=$(get_py_files_to_check)
  else
    echo "Invalid syntax for invoking do_pylint"
    echo "Usage: do_pylint (PYTHON2 | PYTHON3) [--incremental]"
    return 1
  fi

  if [[ -z ${PYTHON_SRC_FILES} ]]; then
    echo "do_pylint found no Python files to check. Returning."
    return 0
  fi

  if [[ ! -f "${PYLINTRC_FILE}" ]]; then
    die "ERROR: Cannot find pylint rc file at ${PYLINTRC_FILE}"
  fi

  NUM_SRC_FILES=$(echo ${PYTHON_SRC_FILES} | wc -w)
  NUM_CPUS=${_N_CPUS}

  echo "Running pylint on ${NUM_SRC_FILES} files with ${NUM_CPUS} "\
"parallel jobs..."
  echo ""

  PYLINT_START_TIME=$(date +'%s')
  OUTPUT_FILE="$(mktemp)_pylint_output.log"
  ERRORS_FILE="$(mktemp)_pylint_errors.log"
  NONWL_ERRORS_FILE="$(mktemp)_pylint_nonwl_errors.log"

  echo "(Output file is ${OUTPUT_FILE})"

  rm -rf ${OUTPUT_FILE}
  rm -rf ${ERRORS_FILE}
  rm -rf ${NONWL_ERRORS_FILE}
  touch ${NONWL_ERRORS_FILE}

  ${PYLINT_BIN} --rcfile="${PYLINTRC_FILE}" --output-format=parseable \
      --jobs=${NUM_CPUS} ${PYTHON_SRC_FILES} > ${OUTPUT_FILE} 2>&1
  PYLINT_END_TIME=$(date +'%s')

  echo ""
  echo "pylint took $((PYLINT_END_TIME - PYLINT_START_TIME)) s"
  echo ""

  grep -E '(\[E|\[W0311|\[W0312)' ${OUTPUT_FILE} > ${ERRORS_FILE}

  N_ERRORS=0
  while read -r LINE; do
    IS_WHITELISTED=0
    for WL_REGEX in ${ERROR_WHITELIST}; do
      if echo ${LINE} | grep -q "${WL_REGEX}"; then
        echo "Found a whitelisted error:"
        echo "  ${LINE}"
        IS_WHITELISTED=1
      fi
    done

    if [[ ${IS_WHITELISTED} == "0" ]]; then
      echo "${LINE}" >> ${NONWL_ERRORS_FILE}
      echo "" >> ${NONWL_ERRORS_FILE}
      ((N_ERRORS++))
    fi
  done <${ERRORS_FILE}

  echo ""
  if [[ ${N_ERRORS} != 0 ]]; then
    echo "FAIL: Found ${N_ERRORS} non-whitelited pylint errors:"
    cat "${NONWL_ERRORS_FILE}"
    return 1
  else
    echo "PASS: No non-whitelisted pylint errors were found."
    return 0
  fi
}

# Another function from the original TensorFlow CI script.
# List Python files changed in the last non-merge git commit that still exist,
# i.e., not removed.
# Usage: get_py_files_to_check [--incremental]
get_py_files_to_check() {
  if [[ "$1" == "--incremental" ]]; then
    CHANGED_PY_FILES=$(get_changed_files_in_last_non_merge_git_commit | \
                       grep '.*\.py$')

    # Do not include files removed in the last non-merge commit.
    PY_FILES=""
    for PY_FILE in ${CHANGED_PY_FILES}; do
      if [[ -f "${PY_FILE}" ]]; then
        PY_FILES="${PY_FILES} ${PY_FILE}"
      fi
    done

    echo "${PY_FILES}"
  else
    find tensorflow -name '*.py'
  fi
}


# Keep the skeleton of the top-level driver program around for its
# pretty-printing of results.
SANITY_STEPS=("do_pylint PYTHON2" "do_pylint PYTHON3")
SANITY_STEPS_DESC=("Python 2 pylint" "Python 3 pylint")

INCREMENTAL_FLAG=""

# Parse command-line arguments
for arg in "$@"; do
  if [[ "${arg}" == "--incremental" ]]; then
    INCREMENTAL_FLAG="--incremental"
  else
    echo "ERROR: Unrecognized command-line flag: $1"
    exit 1
  fi
done


FAIL_COUNTER=0
PASS_COUNTER=0
STEP_EXIT_CODES=()

# Execute all the sanity build steps
COUNTER=0
while [[ ${COUNTER} -lt "${#SANITY_STEPS[@]}" ]]; do
  INDEX=COUNTER
  ((INDEX++))

  echo ""
  echo "=== Sanity check step ${INDEX} of ${#SANITY_STEPS[@]}: "\
"${SANITY_STEPS[COUNTER]} (${SANITY_STEPS_DESC[COUNTER]}) ==="
  echo ""

  ${SANITY_STEPS[COUNTER]} ${INCREMENTAL_FLAG}
  RESULT=$?

  if [[ ${RESULT} != "0" ]]; then
    ((FAIL_COUNTER++))
  else
    ((PASS_COUNTER++))
  fi

  STEP_EXIT_CODES+=(${RESULT})

  echo ""
  ((COUNTER++))
done

# Print summary of build results
COUNTER=0
echo "==== Summary of sanity check results ===="
while [[ ${COUNTER} -lt "${#SANITY_STEPS[@]}" ]]; do
  INDEX=COUNTER
  ((INDEX++))

  echo "${INDEX}. ${SANITY_STEPS[COUNTER]}: ${SANITY_STEPS_DESC[COUNTER]}"
  if [[ ${STEP_EXIT_CODES[COUNTER]} == "0" ]]; then
    printf "  ${COLOR_GREEN}PASS${COLOR_NC}\n"
  else
    printf "  ${COLOR_RED}FAIL${COLOR_NC}\n"
  fi

  ((COUNTER++))
done

echo
echo "${FAIL_COUNTER} failed; ${PASS_COUNTER} passed."

echo
if [[ ${FAIL_COUNTER} == "0" ]]; then
  printf "Sanity checks ${COLOR_GREEN}PASSED${COLOR_NC}\n"
else
  printf "Sanity checks ${COLOR_RED}FAILED${COLOR_NC}\n"
  exit 1
fi
