#! /bin/bash

################################################################################
# tf_env.sh
#
# Set up Anaconda virtualenvs for TensorFlow development. Creates an
# environment called "env" for building and a second environment called
# "testenv" for testing compiled artifacts.
#
# To use, run from the root directory of your TF source tree with no
# arguments.
#
# Requires that conda be installed and set up for calling from bash scripts.
#
# Also requires that you set the environment variable CONDA_HOME to the
# location of the root of your anaconda/miniconda distribution.
################################################################################

PYTHON_VERSION=3.6

############################
# HACK ALERT *** HACK ALERT 
# The friendly folks at Anaconda thought it would be a good idea to make the
# "conda" command a shell function. 
# See https://github.com/conda/conda/issues/7126
# The following workaround will probably be fragile.
if [ -z "$CONDA_HOME" ]
then 
    echo "Error: CONDA_HOME not set"
    exit
fi
. ${CONDA_HOME}/etc/profile.d/conda.sh
# END HACK
############################

################################################################################
# env

# Create initial env with official prereqs for running tests
conda create -y --prefix ./env \
    python=${PYTHON_VERSION} \
    numpy wheel \
    -c conda-forge

conda activate ./env

# Install unofficial requirements, i.e. not mentioned in the docs, but tests
# will fail without them.
# TODO: Revisit these periodically
conda install -y portpicker grpcio scipy \
    keras-applications keras-preprocessing 
    #-c conda-forge

# Some prereqs are only available from conda-forge
conda install -y autograd \
    -c conda-forge

# Additional requirements for running the tests under contrib
conda install -y scikit-learn

# Requirements that must be installed from pip because the conda version is
# not kept sufficiently up to date. TODO: Revisit this list and move things to
# conda install.
#pip install tensorflow-estimator

# Install TensorFlow and keras-applications, both of which are also unofficial
# requirements. We install them from pip because the version in conda-forge is
# sometimes too old to work with the master build of TF.
#pip install tensorflow tensorflow-estimator keras-applications

conda deactivate
    
################################################################################
# testenv
conda create -y --prefix ./testenv \
    python=${PYTHON_VERSION} \
    numpy pandas jupyterlab 
    #-c conda-forge

        
echo << EOM
Anaconda virtualenv installed in ./env.
Run \"conda activate ./env\" before running ./configure
EOM

