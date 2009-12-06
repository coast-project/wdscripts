#!/bin/bash

USAGE="\"srch_path_sedArg1\" \"repl_path_sedArg2\" [more s/r tuples]"
LONG_USAGE="bla"

OPTIONS_SPEC=
. "$(git --exec-path)/git-sh-setup"
require_work_tree

##exec >`basename $0`.out

testeven() {
if [ $1 -eq 1 ]; then
	echo "uneven number of arguments given, exiting!"
	usage;
fi
}

testeven $#
# remove all paths passed as arguments from the history of the repo
sed_expression=""

while [ $# -ge 2 ]; do
	srch="${1}"
	repl="${2}"
	sed_expression="${sed_expression} -e \"s-\t${srch}-\t${repl}-\""
	shift 2
	testeven $#
done

index_filter=$(cat <<- EOF
git ls-files -s | sed ${sed_expression} | \
	GIT_INDEX_FILE=\${GIT_INDEX_FILE}.new \
	git update-index --index-info &&
	mv \${GIT_INDEX_FILE}.new \${GIT_INDEX_FILE}
EOF
)
cmd="git filter-branch --tag-name-filter 'cat -- --all' --index-filter '${index_filter}' -- HEAD"
echo ${cmd}
echo "Continue (*y|n)?"
read yesno
if [ "$yesno" = "n" -o "$yesno" = "N" ]; then
  exit 3;
fi
eval ${cmd}

# remove the temporary history git-filter-branch otherwise leaves behind for a long time
git for-each-ref --format="%(refname)" refs/original/ | xargs -n 1 git update-ref -d
git reflog expire --expire=now --all &&  git repack -ad && git gc --aggressive --prune=now

