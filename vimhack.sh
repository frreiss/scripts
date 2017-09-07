#!/bin/bash

# Make MacVim look like vim for the benefit of cscope.

echo "Opening $2 at position $1"

# TODO: Skip ahead in the file 
open -a /Applications/MacVim.app $2 


