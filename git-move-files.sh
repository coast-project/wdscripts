#!/bin/bash

USAGE=""
LONG_USAGE=""

OPTIONS_SPEC="\
$(basename "$0") [options] \"search\" \"replace\"...

The search/replace tuples will be used within --index-filter to rename filenames
in the index. For every commit, the content of the index will be piped to sed using
git ls-files -s . Specified search and replace tokens will be used to form sed
expressions of the form 's-\t\${search}-\t\${replace}-'.
You can use any sed expression and replacement tokens (like \1) but keep in mind
to escape special characters like ()+?
--
h,help show the help
dorevs= revisions to work on, default is --all, use something like HEAD~10..HEAD to only work on last 10 commits
"

. "$(git --exec-path)/git-sh-setup"
require_work_tree

revs="--all "
while true; do
	case "$1" in
		--dorevs) revs="${revs} $2"; shift 2;;
		--)	shift; break;;
		*) break;;
	esac
done

testeven() {
if [ $1 -eq 1 ]; then
	echo "uneven number of search/replace arguments given, exiting!"
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

cmd="git filter-branch --tag-name-filter cat"
cmd="${cmd} --index-filter '${index_filter}'"
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
	git for-each-ref --format="%(refname)" refs/original/ | xargs -n 1 git update-ref -d 2>/dev/null || exit 0
	git reflog expire --expire=now --all &&  git repack -ad && git gc --aggressive --prune=now
fi

