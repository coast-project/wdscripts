#!/bin/sh
#-----------------------------------------------------------------------------------------------------
# Copyright (c) 2010, Peter Sommerlad and IFS Institute for Software at HSR Rapperswil, Switzerland
# All rights reserved.
#
# This library/application is free software; you can redistribute and/or modify it under the terms of
# the license that is included with this library/application in the file license.txt.
#-----------------------------------------------------------------------------------------------------
#
# adjust submodule commit references based on corresponding tags both in submodule and referencing repository
#

_refrepo=`basename \`pwd -P\``
_xrefprefix="xref"
_tagsep="_"
_outsep=","
_dryrun=0
_revs="--all "

USAGE="[--xrefprefix xrefTagPrefix] [--tagnamesep tagNameSeparator] [--outputsep outputSeparator] [--refrepo referencingRepositoryName] [--dry-run] submodule_dir"

OPTIONS_SPEC="\
$(basename "$0") $USAGE

This tool is intended to use before applying heavy modifications - rewriting history - to submodules by creating
logical - tag based - references in both repositories.

Filter the referencing repository for submodule commits targeting the specified submodule directory and collect
referencing repository commit ids and the corresponding submodule commit id.
Having this information at hand, create xref-tags in both repositories to be able to fix the references after
submodule rewriting.
--
h,help show the help
xrefprefix= prefix used to create cross reference tag names for both repositories, default [${_xrefprefix}]
tagnamesep= separator used to join parts of the tag name, default [${_tagsep}]
outputsep= separator used when outputting tag name and hashes, default [${_outsep}]
refrepo= name of the referencing repository, default [${_refrepo}]
dry-run= try out what would be done before creating tags
dorevs= revisions to work on, default is ${_revs}, use something like HEAD~10..HEAD to only work on last 10 commits
"

. "$(git --exec-path)/git-sh-setup"
require_work_tree

_subdir=""

# Parse our command-line arguments.
while test $# -ne 0; do
	case "$1" in
	--)
		shift
	;;
	--xrefprefix)
		shift
		test $# -ne 0 || die "Must supply argument to --xrefprefix"
		_xrefprefix="$1"
		shift
	;;
	--tagnamesep)
		shift
		test $# -ne 0 || die "Must supply argument to --tagnamesep"
		_tagsep="$1"
		shift
	;;
	--outputsep)
		shift
		test $# -ne 0 || die "Must supply argument to --outputsep"
		_outsep="$1"
		shift
	;;
	--refrepo)
		shift
		test $# -ne 0 || die "Must supply argument to --refrepo"
		_refrepo="$1"
		shift
	;;
	--dry-run)
		shift
		_dryrun=1
	;;
	--dorevs)
		_revs="${_revs} $2";
		shift 2
	;;
	-*)
		die "Unknown option: $1"
	;;
	*)
		# Use the first specified directory as the subrepository name.
		_subdir="$1"
		shift
		break
	;;
	esac
done

test -n "${_subdir}" || die "Must supply non empty submodule directory as argument"

cat <<- EOF
Collected the following information:
Submodule directory to cross reference: ${_subdir}
Referencing repository name:            ${_refrepo}
Xref tagname prefix:                    ${_xrefprefix}
Tagname separator:                      ${_tagsep}
Output separator:                       ${_outsep}
Dry-run:                                ${_dryrun}
Revisions to process:                   ${_revs}

EOF
echo "Continue (*y|n)?"
read yesno
if [ "$yesno" = "n" -o "$yesno" = "N" ]; then
  exit 3;
fi

tagnum=0
reftagfile=${_refrepo}_tags.tmp
subtagfile=${_subdir}_tags.tmp
joinfile=$HOME/${_refrepo}_${_subdir}_join.tmp
tagnamefilter=${_xrefprefix}${_tagsep}${_refrepo}${_tagsep}${_subdir}${_tagsep}
git ls-remote --tags . | grep ${tagnamefilter} | while read h t; do tagn=`echo $t | cut -d'/' -f3 | cut -d${_tagsep} -f4`; hsh=`git ls-tree -d --no-abbrev ${h} | grep ${_subdir} | awk '{print $3}'`; echo ${tagn} ${h} ${hsh}; done | sort -n >${reftagfile}
git ls-remote --tags ${_subdir} | grep ${tagnamefilter} | while read h t; do tagn=`echo $t | cut -d'/' -f3 | cut -d${_tagsep} -f4`; echo $tagn $h; done | sort -n >${subtagfile}
join ${reftagfile} ${subtagfile} | awk 'BEGIN{delete arr;}{arr[$3]=$4;}END{for (k in arr) { print "s-"k"-"arr[k]"-" }}' | sort | uniq >${joinfile}

sed_expression="-f ${joinfile}"
index_filter=$(cat <<- EOF
git ls-files -s | sed ${sed_expression} | \
	GIT_INDEX_FILE=\${GIT_INDEX_FILE}.new \
	git update-index --index-info &&
	mv \${GIT_INDEX_FILE}.new \${GIT_INDEX_FILE}
EOF
)

commit_filter=$(cat <<- EOF
git_commit_non_empty_tree "\$@"
EOF
)

cmd="git filter-branch"
cmd="${cmd} -d $HOME/gitfilt.tmpfs"
cmd="${cmd} --tag-name-filter cat"
cmd="${cmd} --commit-filter '${commit_filter}'"
cmd="${cmd} --index-filter '${index_filter}'"
cmd="${cmd} -- ${_revs}"

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
