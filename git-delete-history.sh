#!/bin/bash

USAGE="file_or_dir [another_file_or_dir...]"
LONG_USAGE=""

OPTIONS_SPEC=
. "$(git --exec-path)/git-sh-setup"
require_work_tree

revs="--all "
##exec >`basename $0`.out # disabled due to using git rm -q

# remove all paths passed as arguments from the history of the repo
args="$@"
index_filter=""
if [ -n "${args}" ]; then
index_filter=$(cat <<- EOF
git rm -q -rf --cached --ignore-unmatch $@
EOF
)
fi

commit_filter=$(cat <<- EOF
git_commit_non_empty_tree "\$@"
EOF
)
tmpdir=`mktemp -d`
cmd="git filter-branch -f -d ${tmpdir} --tag-name-filter cat"
if [ -n "${index_filter}" ]; then
  cmd="${cmd} --index-filter '${index_filter}'"
fi
cmd="${cmd} --commit-filter '${commit_filter}'"
cmd="${cmd} -- ${revs}"

echo ${cmd}
echo "Continue (*y|n)?"
read yesno
if [ "$yesno" = "n" -o "$yesno" = "N" ]; then
  test -d ${tmpdir} && rmdir ${tmpdir};
  exit 3;
fi
eval ${cmd}
cmdCode=$?
test -d ${tmpdir} && rm -rf ${tmpdir};
echo "retcode of command ${cmdCode}, 128 can be ignored when using temp directory for filter-branch"

if [ ${cmdCode} -eq 0 -o ${cmdCode} -eq 128 ]; then
  # remove the temporary history git-filter-branch otherwise leaves behind for a long time
  git reset --hard;
  git for-each-ref --format="%(refname)" refs/original/ | xargs -n 1 git update-ref -d 2>/dev/null || exit 0
  git reflog expire --expire=now --all &&  git repack -ad && git gc --aggressive --prune=now
fi

