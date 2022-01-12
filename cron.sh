#!/bin/bash

set -euo pipefail

TOP=$(dirname "$0")

cd "$TOP"


function pulling_data {
    # assume we are in the folder
    GH_TOKEN="$(cat .secretes/gh.token)"
    export GH_TOKEN

    # download latest data
    bash repo_ops.sh -d -f tmp/repo

    # truncate history
    # bash repo_ops.sh -t -f tmp/repo

    # fetch yahoo finance data
    source env/bin/activate
    python yfin_data.py

    # upload changes
    bash repo_ops.sh -u -f tmp/repo
}

function trucate_history {
    rm -rf tmp/repo
    # download latest data
    bash repo_ops.sh -d -f tmp/repo

    # truncate history
    bash repo_ops.sh -t -f tmp/repo || true

    if [ -z "$(git status --porcelain)" ]; then
        echo "Rebase successful, uploading"
        bash repo_ops.sh -u -f tmp/repo
    else 
        echo "Rebase failed, clean up"
    fi

    # reset repo, avoid local repo exposion
    rm -rf tmp/repo
}

# truncate history at 3AM, pulling data otherwise
if [ "$(date +%H)" -eq 3 ]; then
    echo '3AM, truncate history'
    trucate_history
else
    echo 'pulling data'
    pulling_data
fi
