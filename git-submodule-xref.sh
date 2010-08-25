#!/bin/sh
#
# adjust submodule commit references based on corresponding tags both in submodule and referencing repository
#

_refrepo=`basename \`pwd -P\``
_xrefprefix="xref"
_tagsep="_"
_outsep=","
_dryrun=0

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

EOF
echo "Continue (*y|n)?"
read yesno
if [ "$yesno" = "n" -o "$yesno" = "N" ]; then
  exit 3;
fi

tagnum=0
for parhash in `git rev-list --no-abbrev --all --reverse -- ${_subdir}`; do
	oldsubhash=`git ls-tree -d --no-abbrev ${parhash} | grep ${_subdir} | awk '{print $3}'`
	if [ -n "${parhash}" -a -n "${oldsubhash}" ]; then
		tagname=${_xrefprefix}${_tagsep}${_refrepo}${_tagsep}${_subdir}${_tagsep}${tagnum}
		if [ ${doDbg:-0} -eq 1 ]; then
			echo "creating tag with name: ${tagname}"
			echo "current refrepo hash:   ${parhash}"
			echo "old subrepo hash:       ${oldsubhash}"
		fi
		if [ ${tagnum} -eq 0 ]; then
			echo "#tagname${_outsep}ref repo hash${_outsep}old submodule hash${_outsep}new submodule hash"
		fi
		echo "${tagname}${_outsep}${parhash}${_outsep}${oldsubhash}"
		if [ ${_dryrun} -eq 0 ]; then
			git tag -f ${tagname} ${parhash} 2>/dev/null && ( cd ${_subdir} && git tag -f ${tagname} ${oldsubhash} 2>/dev/null )
		fi
		tagnum=$(( $tagnum + 1 ))
	fi
done
