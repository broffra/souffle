#!/bin/bash

DOOP_HOME=~/usyd/ssp/doop ~/usyd/ssp/souffle-analysis.sh -r -v -i /home/brody/usyd/ssp/doop-benchmarks/demos/jre1.7/hello/Reachable.jar -a context-insensitive --platform java_8 --id souffle-reachable --unique-facts
