#! /usr/bin/env python3
"""Creates a new local branch for a TensorFlow issue.

Does NOT commit any changes to Github, but DOES set things up so that "git
push" will commit those changes.

Usage:
    ~/scripts/tf_branch.py <issue #>

Where:
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

_PYTHON_VERSION=3.6

################################################################################
# BEGIN SCRIPT

def main():
    if len(sys.argv) != 2:
        print ("Usage: {} <issue #>".format(sys.argv[0]))
        sys.exit()

    issue_num = sys.argv[1]
    dir_name = "tf-" + issue_num
    branch_name = "issue-" + issue_num

    # Create and check out a branch
    run(["git", "clone", _MY_TF_REPO_URL, dir_name])
    os.chdir(dir_name)
    run(["git", "remote", "add", "upstream", _TF_REPO_URL])
    run(["git", "branch", branch_name])
    run(["git", "checkout", branch_name])

    # Set up virtualenv for this source tree
    run(["virtualenv", "env", "--python=python{}".format(_PYTHON_VERSION)])

    # Install required deps; see https://www.tensorflow.org/install/install_sources,
    # under "Install TensorFlow Python dependencies"
    run(["env/bin/pip", "install", "numpy", "dev", "wheel"])
    
    # Install additional undocumented dependencies required to run tests.
    run(["env/bin/pip", "install", "autograd", "portpicker", "grpcio"])

    print("Virtualenv installed in ./env.\n"
          "Run \"source ./env/bin/activate\" before running ./configure")
    

if __name__ == '__main__':
    main()

