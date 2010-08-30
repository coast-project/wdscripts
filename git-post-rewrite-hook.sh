#!/bin/sh

. "$(git --exec-path)/git-sh-setup"

# $1 is equal to "rebase"
mywhat=$1
shift
echo "first arg of script [$mywhat]"

# $1 oldrev
# $2 newrev
checkCreateTags()
{
	oldrev=$1
	newrev=$2
	test -n "$oldrev" -a -n "$newrev" || die "wrong number of arguments given"
	# test if there is a tag associated with the old commit
	for tname in `git ls-remote --tags . | grep $oldrev | cut -d'/' -f3`; do
		echo "moving tag [$tname] from $oldrev $newrev"
		git tag -f $tname $newrev
	done
}

# --- Main loop
# Allow dual mode: run from the command line just like the update hook, or
# if no arguments are given then run as a hook script
if [ -n "$1" -a -n "$2" ]; then
	echo "command line arguments given"
	echo $1 $2
else
	echo "stdin mode"
	while read oldrev newrev; do
		checkCreateTags $oldrev $newrev
	done
fi

