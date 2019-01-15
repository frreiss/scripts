#! /usr/bin/env python3
"""Creates or checks out a new local branch for GraphDef Editor development.

Also sets up an Anaconda virtualenv in the local copy of the branch with all the 
necessary packages for building TensorFlow and running the tests.

Requires Anaconda for virtualenv creation.

Does NOT commit any changes to Github, but DOES set things up so that "git
push" will commit those changes.

Usage:
    ~/scripts/gde_branch.py [-c] <issue name>

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
_TF_REPO_URL = "https://github.com/CODAIT/graph_def_editor.git"
_MY_TF_REPO_URL = "https://github.com/frreiss/graph_def_editor.git"

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
        
    dir_name = "gde-" + issue_num
    branch_name = "issue-" + issue_num

    # Create and check out a branch
    run(["git", "clone", _MY_TF_REPO_URL, dir_name])
    os.chdir(dir_name)
    run(["git", "remote", "add", "upstream", _TF_REPO_URL])

    if create_branch:
        run(["git", "branch", branch_name])

    run(["git", "checkout", branch_name])

    # Set up virtualenv.
    run("./scripts/env.sh", shell=True)

   

if __name__ == '__main__':
    main()

