#!/bin/bash

# top `NUM_RULES` rules will be scheduled, according to number of iterations
readonly NUM_RULES=2

# exit with an error message
die() {
    echo "$1"
    exit 1
}

# comments with more than one '#' are displayed in the help text
##
## > souffle-analysis.sh
##
## A doop pipeline for examining souffle auto-scheduler choices.
##
## Options:
## --help:           Display this help text and exit.
## -a, --analysis:   Required. The name of the analysis to run.
## --id:             Required. The identifier of the analysis.
## -r, --gen-report: Log Souffle verbose output to file. Default is off.
## -v, --verify:     Verify that the regression is comparing the correct
##                   iteration counts for each rule. Mainly for testing,
##                   since it creates larger files and may take longer.
##

# command-line options
analysis=""
identifier=""
gen_report=false
verify=false

# command-line arguments passed down to doop
args=()

# parse command-line arguments
while :; do
    if [[ -z "$1" ]]; then
        if [[ -z "${analysis}" ]]; then
            die "ERROR: \"--analysis\" is required."
        elif [[ -z "${identifier}" ]]; then
            die "ERROR: \"--id\" is required."
	fi

        break
    elif [[ "$1" == "--help" ]]; then
        cat "$0" | grep '##' | grep -v "grep" | tr -d '#'
	exit 0
    elif [[ "$1" == "-a" ]] || [[ "$1" == "--analysis" ]]; then
        if [[ "$2" ]]; then
            analysis="$2"
        else
            die "ERROR: \"$1\" requires a non-empty option argument."
        fi
    elif [[ "$1" == "--id" ]]; then
        if [[ "$2" ]]; then
	    identifier="$2"
        else
            die "ERROR: \"--id\" requires a non-empty option argument."
        fi
    elif [[ "$1" == "-r" ]] || [[ "$1" == "--gen-report" ]]; then
        gen_report=true
    elif [[ "$1" == "-v" ]] || [[ "$1" == "--verify" ]]; then
        verify=true
    else
        args+=($1)
    fi

    shift
done

## Requirements:
## - Souffle:        https://github.com/souffle-lang/souffle
if [[ -z "$(command -v souffle)" ]] || [[ -z "$(command -v souffle-profile)" ]]; then
    die "Souffle is not installed"
fi

## - Doop:           https://bitbucket.org/yanniss/doop
##
## Environment variables:
## - DOOP_HOME:      Top-level directory of Doop, containing the `doop` executable.
if [[ -v DOOP_HOME ]]; then
    Doop="${DOOP_HOME}"
else
    die "DOOP_HOME is not defined"
fi

# find the Doop output directory
if [[ -v DOOP_OUT ]]; then
    DoopOut="${DOOP_OUT}"
else
    DoopOut="$Doop/out"
fi

# exit immediately if souffle or doop errors
set -e

souffle_dir="$DoopOut/${analysis}/${identifier}"
souffle_prof="${souffle_dir}/profile-expected.txt"
souffle_file="${souffle_dir}/${analysis}.dl"

# find a directory to place our new schedule
prefix_path="${souffle_dir}/schedule-"
num=1
while [[ -d "${prefix_path}${num}" ]]; do
    num=$((num+1))
done

souffle_dir_opt="${prefix_path}${num}"
souffle_prof_opt="${souffle_dir_opt}/profile-scheduled.txt"

# run the Doop analysis if the Souffle file hasn't already been generated
if [[ ! -f "${souffle_file}" ]]; then
    cd "$Doop"
    $Doop/doop "${args[@]}"
    cd -
fi

# if we don't yet have profile statistics for the Doop analysis, first run the profiler
# without any scheduling to establish expected values
if [[ ! -f "${souffle_prof}" ]]; then
    souffle -F${souffle_dir}/facts -D${souffle_dir} -j4 -p${souffle_prof} -i ${souffle_file}
fi

# create the directory for outputting the new schedule
mkdir "${souffle_dir_opt}" 

# compute top `NUM_RULES` rules based on profiler output
ruls="$(souffle-profile ${souffle_prof} -c iter | head -n $(($NUM_RULES + 3)) | tail -n +4 | rev | sed 's/^ *//' \
        | cut -d ' ' -f 2 | rev | tee "${souffle_dir_opt}/top-${NUM_RULES}-rules.txt" | tr '\n' ',' | head -c -1)"

compress=""
if [[ "$verify" = true ]]; then
    compress="C"
fi

# run the auto-scheduler, either in verbose mode or quietly
if [[ "$gen_report" = true ]]; then
    souffle -F${souffle_dir}/facts -D${souffle_dir} -j4 -a${ruls} -p${souffle_prof_opt} -i${compress} -v ${souffle_file} \
            | tee "${souffle_dir_opt}/auto-schedule-report.txt"
else
    souffle -F${souffle_dir}/facts -D${souffle_dir} -j4 -a${ruls} -p${souffle_prof_opt} -i${compress} ${souffle_file} 
fi

exp_lines=$(grep '@i' "${souffle_prof}" | rev | sort -t ';' -k 2 -s)
opt_lines=$(grep '@i' "${souffle_prof_opt}" | rev | sort -t ';' -k 2 -s)

# verify that there is a one-to-one correspondence between rules in both profiles
# TODO: check why sorting is required. shouldn't rules be executed in the same order every time?
if [[ "$verify" = true ]]; then
    diff --brief <(echo "${exp_lines}" | cut -d ';' -f 2-) <(echo "${opt_lines}" | cut -d ';' -f 2-)
fi

exp_lines=$(echo "${exp_lines}" | cut -d ';' -f 1 | rev)
opt_lines=$(echo "${opt_lines}" | cut -d ';' -f 1 | rev)

paste <(echo "${exp_lines}") <(echo "${opt_lines}") | python regression.py

# ...or use awk
# paste <(echo "${exp_lines}") <(echo "${opt_lines}") | awk '{rss += ($1-$2)^2}; END{print (rss)}'
