#!/bin/bash

clear

nvim --headless -c "PlenaryBustedDirectory tests { minimal_init = './tests/minimal_init.lua' }"
