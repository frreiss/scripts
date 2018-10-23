#! /usr/bin/env python3
"""Creates or checks out a new local branch for a TensorFlow issue.

Also sets up an Anaconda virtualenv in the local copy of the branch with all the 
necessary packages for building TensorFlow and running the tests.

Requires Anaconda for virtualenv creation.

Does NOT commit any changes to Github, but DOES set things up so that "git
push" will commit those changes.

Usage:
    ~/scripts/tf_branch.py [-c] <issue #>

Where:
    -c means create branch before checking it out
    <issue #> is the ID of the Github issue to work on
"""

################################################################################
# IMPORTS

import os
import sys
from subprocess import run

################################################################################
# CONSTANTS

# Github URLs go here
_TF_REPO_URL = "https://github.com/tensorflow/tensorflow.git"
_MY_TF_REPO_URL = "https://github.com/frreiss/tensorflow-fred.git"

_PYTHON_VERSION=3

_USAGE = "Usage: {} [-c] <issue #>".format(sys.argv[0])

################################################################################
# BEGIN SCRIPT

def print_usage_and_exit():
    print(_USAGE)
    sys.exit()

def main():
    if len(sys.argv) != 2 and len(sys.argv) != 3:
        print_usage_and_exit()

    if 2 == len(sys.argv):
        issue_num = sys.argv[1]
        create_branch = False
    elif 3 == len(sys.argv): 
        if ("-c" != sys.argv[1]):
            print_usage_and_exit()
        issue_num = sys.argv[2]
        create_branch = True
        
    dir_name = "tf-" + issue_num
    branch_name = "issue-" + issue_num

    # Create and check out a branch
    run(["git", "clone", _MY_TF_REPO_URL, dir_name])
    os.chdir(dir_name)
    run(["git", "remote", "add", "upstream", _TF_REPO_URL])

    if create_branch:
        run(["git", "branch", branch_name])

    run(["git", "checkout", branch_name])

    # Set up virtualenv for building this source tree
    run(["conda", "create", "-y", "--prefix", "./env", 
        "python={}".format(_PYTHON_VERSION),
        "numpy", "wheel",
        # Install additional undocumented dependencies required to run tests.
        "autograd", "portpicker", "grpcio", "scipy",
        "-c", "conda-forge"], shell=True)
    # Note the shell=True; conda cmd only works from a shell on Linux.
    
    # TensorFlow is built against the latest version of TensorFlow in PyPI, 
    # not conda-forge.
    run(["conda", "activate", "./env"], shell=True)
    run(["pip", "install", "tensorflow", 
        "tensorflow-estimator", # Temporary until TF 1.12 is in PyPI
        "keras-applications"]) # See issue 21518
    run(["conda deactivate"], shell=True)

    # Set up second virtualenv for testing our pip artifacts
    run(["conda", "create", "-y", "--prefix", "./testenv", 
        "python={}".format(_PYTHON_VERSION),
        "numpy", "scipy", "jupyterlab",
        "-c", "conda-forge"], shell=True)

    # Install additional dependencies only available on pypi
    
    # Install required deps; see https://www.tensorflow.org/install/install_sources,
    # under "Install TensorFlow Python dependencies"
    #run(["env/bin/pip", "install", "numpy", "dev", "wheel"])
    
    #run(["env/bin/pip", "install", "keras_applications"])
    
    # Install additional undocumented dependencies required to run tests.
    #run(["env/bin/pip", "install", "autograd", "portpicker", "grpcio", "scipy"])

    print("Anaconda virtualenv installed in ./env.\n"
          "Run \"conda activate ./env\" before running ./configure")
    

if __name__ == '__main__':
    main()

