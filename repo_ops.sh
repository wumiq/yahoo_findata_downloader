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
            cd "$REPO_PATH"
            config_clone
        )
    else
        echo "$REPO_PATH does not exist, making new clone"
        mkdir -p "$REPO_PATH"
        (
            cd "$REPO_PATH"
            git clone "$REPO_URL" .
            config_clone
        )
    fi
}


function push_changes {
    # assume we are at service root
    (
        cd "$REPO_PATH"
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



# reset sys var
OPTIND=1

# Initialize our own variables:
output_file=""
download=0
upload=0

while getopts "h?vduf:" opt; do
  case "$opt" in
    h|\?)
      echo
      echo "-h show help; -d to download; -u to push local changes; -f <folder> to set folder"
      echo
      exit 0
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
echo "download='$download'"
echo "upload='$upload'"
echo "Leftovers: $*"
echo "REPO_PATH: $REPO_PATH"

if (( $download )); then
    make_clone
fi

if (( $upload )); then
    push_changes
fi
