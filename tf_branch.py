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

################################################################################
# BEGIN SCRIPT

def main():
    if len(sys.argv) != 2:
        print ("Usage: {} <issue #>".format(sys.argv[0]))
        sys.exit()

    issue_num = sys.argv[1]
    dir_name = "tf-" + issue_num
    branch_name = "issue-" + issue_num

    run(["git", "clone", _MY_TF_REPO_URL, dir_name])
    os.chdir(dir_name)
    run(["git", "remote", "add", "upstream", _TF_REPO_URL])
    run(["git", "branch", branch_name])
    run(["git", "checkout", branch_name])
    

if __name__ == '__main__':
    main()

