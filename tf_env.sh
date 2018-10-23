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
################################################################################

PYTHON_VERSION=3

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
conda install -y autograd portpicker grpcio scipy 

# Install TensorFlow and keras-applications, both of which are also unofficial
# requirements. We install them from pip because the version in conda-forge is
# sometimes too old to work with the master build of TF.
pip install tensorflow tensorflow-estimator keras-applications

conda deactivate
    
################################################################################
# testenv
conda create -y --prefix ./testenv \
    python=${PYTHON_VERSION}
    numpy wheel \
    autograd portpicker grpcio scipy \
    -c conda-forge

        
echo << EOM
Anaconda virtualenv installed in ./env.
Run \"conda activate ./env\" before running ./configure
EOM

