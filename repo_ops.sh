#!/bin/bash

# set -euo pipefail

REPO_PATH="tmp/repo2"
# assume GH_TOKEN is in env
# GH_TOKEN="..."
REPO_URL="https://$GH_TOKEN@github.com/wumiq/us_stock_eod.git"


function config_clone {
    # assume cwd is set
    git config user.name wumiq
    git config user.email wumiq@yahoo.com
    # checkout main optimistically
    git checkout -b main || true
    # clean untracked files and folders
    git clean -f -d -x
    # reset HEAD to remote
    git fetch "$REPO_URL" main
    git reset --hard  FETCH_HEAD
}

function make_clone {
    echo "Making new clone or setting existing clone"
    if [[ -d "$REPO_PATH" ]]; then
        echo "$REPO_PATH exists"
        (
            cd "$REPO_PATH" || exist
            config_clone
        )
    else
        echo "$REPO_PATH does not exist, making new clone"
        mkdir -p "$REPO_PATH"
        (
            cd "$REPO_PATH" || exist
            git clone "$REPO_URL" .
            config_clone
        )
    fi
}


function push_changes {
    # assume we are at service root
    (
        cd "$REPO_PATH" || exit
        if [ -z "$(git status --porcelain)" ]; then 
            echo "Working directory clean, skip commit"
        else
            echo "Working directory not clean, create commit"
            git add .
            git commit -a -m "Update data, $(date '+%FT%H:%M:%S')"
        fi
        git push "$REPO_URL" main:main --force
    )    
}

function trucate_history {
    (
        cd "$REPO_PATH" || exit
        c10=$(git rev-parse "main~10")
        echo "commit of main~10 is $c10"
        c10p=$(echo "New initial commit, older history has been truncated" | git commit-tree "$c10^{tree}")
        echo "new parent of c10 is $c10p, replacing $c10 with $c10p"
        git rebase --onto "$c10p" "$c10"
        git gc
        git repack -Adf     # kills in-pack garbage
        git prune           # kills loose garbage
    )
}



# reset sys var
OPTIND=1

# Initialize our own variables:
output_file=""
download=0
upload=0
truncate=0

while getopts "h?tvduf:" opt; do
  case "$opt" in
    h|\?)
      echo
      echo "./repo_ops.sh"
      echo "  -h show help"
      echo "  -t truncate history"
      echo "  -d to download"
      echo "  -u to push local changes"
      echo "  -f <folder> to set folder"
      echo
      exit 0
      ;;
    t)
      truncate=1
      ;;
    v)
      set -x
      ;;
    d)
      download=1
      ;;
    u)
      upload=1
      ;;
    f)
      output_file=$OPTARG
      ;;
  esac
done

shift $((OPTIND-1))

[ "${1:-}" = "--" ] && shift

REPO_PATH=${output_file:-tmp/repo2}

echo "########## Parse Variables ##########"
echo "output_file='$output_file'"
echo "truncate='$truncate'"
echo "download='$download'"
echo "upload='$upload'"
echo "Leftovers: $*"
echo "REPO_PATH: $REPO_PATH"

if (( download )); then
    echo "cloning or pulling changes"
    make_clone
elif (( upload )); then
    echo "pushing changes"
    push_changes
elif (( truncate )); then
    echo "truncating hisotry"
    trucate_history
fi
