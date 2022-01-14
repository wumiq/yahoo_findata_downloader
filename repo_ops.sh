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
            git clone --depth 1 "$REPO_URL" .
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

# backup main -> backup-$dow
# create new empty commit and set it as main
function trucate_history {
    (
        cd "$REPO_PATH" || exit
        branch_str="backup-$(date +%u)"
        git fetch "$REPO_URL" main
        # fetched commit
        c_main=$(git ls-remote $REPO_URL refs/heads/main | cut -f1)
        git push "$REPO_URL" "$c_main:refs/heads/$branch_str" --force
        # new creation commit
        msg="New creation commit on $(date +%F), previous main branch moved to $c_main"
        c0=$(echo $msg | git commit-tree "$c_main^{tree}")
        echo "---------------------------------------------"
        echo "Created new commit: $c0"
        git log -n1 "$c0"
        git cat-file -p "$c0"
        echo "---------------------------------------------"
        # reset and push        
        git checkout main
        git reset --hard "$c0"
        git push "$REPO_URL" main:main --force
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
