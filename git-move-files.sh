#!/bin/bash
set -o errexit

if [ $# -eq 0 ]; then
    exit 0are still
fi

# make sure we're at the root of git repo
if [ ! -d .git ]; then
    echo "Error: must run this script from the root of a git repository"
    exit 1
fi

#exec >`basename $0`.out
# remove all paths passed as arguments from the history of the repo
srch="${1}"
repl="${2:-}"

index_filter=$(cat <<- EOF
git ls-files -s | sed "s-\t${srch}-\t${repl}-" | \
	GIT_INDEX_FILE=\${GIT_INDEX_FILE}.new \
	git update-index --index-info &&
	mv \${GIT_INDEX_FILE}.new \${GIT_INDEX_FILE}
EOF
)
cmd="git filter-branch --tag-name-filter cat --index-filter '${index_filter}' -- HEAD"
echo ${cmd}
eval ${cmd}

# remove the temporary history git-filter-branch otherwise leaves behind for a long time
rm -rf .git/refs/original/ && git reflog expire --expire="now" --all &&  git repack -a -d && git gc --aggressive --prune
