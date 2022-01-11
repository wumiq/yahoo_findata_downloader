#!/bin/bash

set -euo pipefail

TOP=$(dirname "$0")

cd "$TOP"

# assume we are in the folder
GH_TOKEN="$(cat .secretes/gh.token)"
export GH_TOKEN

# download latest data
bash repo_ops.sh -d -f tmp/repo

# truncate history
bash repo_ops.sh -t -f tmp/repo

# fetch yahoo finance data
source env/bin/activate
python yfin_data.py

# upload changes
bash repo_ops.sh -u -f tmp/repo
