#!/bin/bash

USAGE="file_or_dir [another_file_or_dir...]"
LONG_USAGE=""

OPTIONS_SPEC=
. `dirname $0`/git-sh-setup
require_work_tree

##exec >`basename $0`.out # disabled due to using git rm -q

# remove all paths passed as arguments from the history of the repo
index_filter=$(cat <<- EOF
git rm -q -rf --cached --ignore-unmatch $@
EOF
)

commit_filter=$(cat <<- EOF
git_commit_non_empty_tree "\$@"
EOF
)

cmd="git filter-branch --tag-name-filter cat --index-filter '${index_filter}' --commit-filter '${commit_filter}' -- HEAD"
echo ${cmd}
echo "Continue (*y|n)?"
read yesno
if [ "$yesno" = "n" -o "$yesno" = "N" ]; then
  exit 3;
fi
eval ${cmd}

# remove the temporary history git-filter-branch otherwise leaves behind for a long time
rm -rf .git/refs/original/ && git reflog expire --expire="now" --all &&  git repack -a -d && git gc --aggressive --prune

