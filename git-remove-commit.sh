#!/bin/bash

USAGE="sha1 [revisions]"
LONG_USAGE="Default revision is --all, use something like HEAD~10..HEAD to only work on last 10 commits"

OPTIONS_SPEC=
. "$(git --exec-path)/git-sh-setup"
require_work_tree

if [ $# -lt 1 ]; then
	echo "must specify sha1 hash, exiting!"
	usage;
fi

commit_id=$1
revs=${2:-"--all"}

commit_filter=$(cat <<- EOF
if [ ! \$GIT_COMMIT = "$commit_id" ]; then
	# default case, commit if not empty tree
	git_commit_non_empty_tree "\$@";
else
	# remove commit including pending changes
	git reset --hard;
fi;
EOF
)

cmd="git filter-branch --tag-name-filter cat"
if [ -n "${index_filter}" ]; then
	cmd="${cmd} --index-filter '${index_filter}'"
fi
cmd="${cmd} --commit-filter '${commit_filter}'"
cmd="${cmd} -- ${revs}"

echo ${cmd}
echo "Continue (*y|n)?"
read yesno
if [ "$yesno" = "n" -o "$yesno" = "N" ]; then
  exit 3;
fi
eval ${cmd}

cmdCode=$?
echo "retcode of command ${cmdCode}"

if [ ${cmdCode} -eq 0 ]; then
	# remove the temporary history git-filter-branch otherwise leaves behind for a long time
	git for-each-ref --format="%(refname)" refs/original/ | xargs -n 1 git update-ref -d 2>/dev/null
	git reflog expire --expire=now --all &&  git repack -ad && git gc --aggressive --prune=now
else
	git reset --hard
fi

