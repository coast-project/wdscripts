#-----------------------------------------------------------------------------------------------------
# Copyright (c) 2005, Peter Sommerlad and IFS Institute for Software at HSR Rapperswil, Switzerland
# All rights reserved.
#
# This library/application is free software; you can redistribute and/or modify it under the terms of
# the license that is included with this library/application in the file license.txt.
#-----------------------------------------------------------------------------------------------------
#
# functions and preparations to encapsulate os specific items
#

PRINT_DBG=${PRINT_DBG:-0};

# unset all functions to remove potential definitions
# generated using $> cat sysfuncs.sh | sed -n 's/^\([a-zA-Z][^(]*\)(.*$/unset -f \1/p'
unset -f getGLIBCVersionFallback
unset -f getGLIBCVersion
unset -f makeAbsPath
unset -f ensureTrailingSlash
unset -f removeTrailingSlash
unset -f removeFromHead
unset -f myWhich
unset -f getFirstValidTool
unset -f getHead
unset -f getTail
unset -f deleteFromPathEx
unset -f hasVersionReturn
unset -f printEnvVar
unset -f isAbsPath
unset -f getCSVValue
unset -f isFunction
unset -f getUid
unset -f getPIDFromFile
unset -f checkProcessId
unset -f removeFiles
unset -f SearchJoinedDir
unset -f relpath
unset -f getdomain
unset -f existInPath
unset -f appendPathEx
unset -f cleanPathEx
unset -f prependPathEx
unset -f insertInPathSorted
unset -f getNumberedEntry
unset -f selectInMenu
unset -f findValidGnuToolCommand
unset -f appendPath
unset -f deleteFromPath
unset -f cleanPath
unset -f prependPath
unset -f getDosDir
unset -f getUnixDir
unset -f selectDevelopDir
unset -f findExecutableWithPath
unset -f selectGnuCompilers
unset -f setDevelopmentEnv
unset -f cleanDevelopmentEnv
unset -f appendTokens
unset -f generateGdbCommandFile
unset -f resolvePath
unset -f deref_links

########## non-function-dependency functions ##########

# retrieve the glibc version number from /lib/libc.so.6 or /lib/ld-linux.so.2
#
# param 1: is the versionnumber separator
#
# output exporting version into given name ($1)
getGLIBCVersionFallback()
{
	versep=${1:-.};
	ggvLsBinary=`unalias ls 2>/dev/null; type -fP ls`;
	glibcstr=`strings \`find /lib* -follow -mount -name 'libc.so*' 2>/dev/null | head -1\` | grep GLIBC_[0-9]\.`;
	verbase=""
	if [ $? -eq 0 ]; then
		# versions found, the highest number should be the first string because of the reverse sort
		verbase=`strings \`find /lib* -follow -mount -name 'libc.so*' 2>/dev/null | head -1\` | sed -n 's|.*GLIBC_\([0-9]\)\.\([0-9][0-9]*\)\.*\([0-9][0-9]*\)*|\1.\2.\3|p' | sort -t. -n -k1,1 -k2,2 -k3,3 | tail -1`;
	else
		# no version in libc - seems to be quite old and we have to use another method
		# we know that ld-linux.so.2 is linked to ld-V.V.V.so where V stands for a version number
		# we simply take this number and use it as the glibc version
		ldfilename=`${ggvLsBinary} -l \`find /lib* -follow -mount -name 'ld-[0-9]*.so*' 2>/dev/null | head -1\``;
		# just need the real file name of the link and cut away ld- part
		verbase=`echo ${ldfilename} | sed -e 's|.*ld-||' -e 's|.so||'`;
	fi;
	# lets get the numbers
	V1=$(cut -d'.' -f1 <<<$verbase);
	V2=$(cut -d'.' -f2 <<<$verbase);
	V3=$(cut -d'.' -f3 <<<$verbase);
	ptmp=$V1$versep$V2;
	if [ -n "$V3" ]; then
		ptmp=$ptmp$versep$V3;
	fi;
	echo "${ptmp}";
}

getGLIBCVersion()
{
	versep=${1:-.};
	glibcstr="$(ldd --version 2>/dev/null | sed -rn '/libc/I { s|^[^0-9.]*([0-9]+\.[0-9]+[0-9.]*).*$|\1|p }' 2>/dev/null)"
	ptmp="";
	if [ -n "$glibcstr" ]; then
		# lets get the numbers
		V1=$(cut -d'.' -f1 <<<$glibcstr);
		V2=$(cut -d'.' -f2 <<<$glibcstr);
		V3=$(cut -d'.' -f3 <<<$glibcstr);
		ptmp=$V1$versep$V2;
		if [ -n "$V3" ]; then
			ptmp=$ptmp$versep$V3;
		fi;
		echo "$ptmp";
	else
		getGLIBCVersionFallback
	fi;
}

# extend given directory name into absolute path
#
# param $1 is the path to make absolute
# param $2 optional argument to pwd command, eg. '-P' to follow links
#
# output: echo absolute path if ${1} is a directory
makeAbsPath()
{
	relativeDir=${1};
	pwdOption=${2};
	lRetVal="";
	if [ -d "${relativeDir}" ]; then
		lRetVal=`cd ${relativeDir} >/dev/null 2>&1 && pwd ${pwdOption} 2>/dev/null`;
	fi;
	echo "${lRetVal}";
}

# param $1: value to clean
# param $2: character to remove, optional, default '/'
ensureTrailingSlash()
{
	etsCharToRemove="${2:-/}";
	echo "`echo ${1} | sed \"s|.*[^${etsCharToRemove}]\$|&/|\"`";
}

# param $1: value to clean
# param $2: character to remove, optional, default '/'
removeTrailingSlash()
{
	rtsCharToRemove="${2:-/}";
	echo "`echo ${1} | sed \"s|^\(.*\)${rtsCharToRemove}\$|\1|\"`";
}

# param $1: value to clean
# param $2: character to remove, optional, default '/'
removeFromHead()
{
	rfhCharsToRemove="${2:-/}";
	echo "`echo ${1} | sed \"s|^${rfhCharsToRemove}\(.*\)\$|\1|\"`";
}

myWhich()
{
	echo "`unalias -a 2>/dev/null; type $1 2>/dev/null | sed -n \"s|^.* is[^(/]*(*\([^)]*\))*\$|\1|p\" 2>/dev/null`";
}

# params tool names to test for
getFirstValidTool()
{
	gfvtSearchPath="${1}";
	shift 1;
	gfvtListSep=":";
	for name in "$@"; do
		gfvtToolname="`myWhich $name 2>/dev/null`";
		test -n "${gfvtToolname}" && echo "${gfvtToolname}" && return 0;
		gfvtToolname="`findExecutableWithPath \"${gfvtSearchPath}\" \"${name}\" \"-*\" \"${gfvtListSep}\" 2>/dev/null`";
		gfvtToolname="`getHead \"${gfvtToolname}\" \"${gfvtListSep}\"`";
		test -n "${gfvtToolname}" || continue;
		echo "${gfvtToolname}";
		return 0;
	done
}

getHead()
{
	ghPath="${1}";
	ghSegsep="${2:-:}";
	echo "`echo ${ghPath} | cut -d\"$ghSegsep\" -f1`";
}

getTail()
{
	gtPath="${1}";
	gtSegsep="${2:-:}";
	gtTailOfPath="`echo ${gtPath} | cut -d\"$gtSegsep\" -f2-`";
	test "${gtTailOfPath}" = "${gtPath}" || echo "${gtTailOfPath}";
}

# test if given path-segment exists in given path and remove it
#
# param $1 value to delete from
# param $2 is the path-segment separator
# param $3 is the path-segment to test and delete
#
# output new path
deleteFromPathEx()
{
	dfpePath="${1}";
	dfpeSegsep="${2}";
	dfpeSeg="${3}";
	echo "`echo ${dfpePath} | sed \"s|${dfpeSegsep}*${dfpeSeg}${dfpeSegsep}*||\"`"
}

# param 1: path/name of GNU tool to test
#
# output version line to caller if any
# return 0 on success, the exit status of the tool call otherwise
hasVersionReturn()
{
	hvrToolname=$1;
	hvrVersionline="`eval ${1} --version 2>/dev/null </dev/null`";
	hvrReturnCode=$?;
	test $hvrReturnCode -eq 0 || return ${hvrReturnCode};
	hvrVersionline="`echo \"${hvrVersionline}\" | sed -n \"1 s|.*GNU|&|p\"`"
	echo "${hvrVersionline}"
	test -n "$hvrVersionline"
}

# print formatted name and value of environment variable
#
# param $1 is the name of the environment variable to print
#
# output formatted name and value of environment variable
printEnvVar()
{
	varname=${1};
	locVar="echo $"$varname;
	printf "%-16s: [%s]\n" $varname "`eval $locVar`"
}

# test if given directory name is an absolute path (starts with /)
#
# param $1 is the path to test
#
# output return 0 in case it starts with /, 1 otherwise
isAbsPath()
{
	test "/" = "`echo ${1} | cut -c1`"
}

# param 1: csv-variable
# param 2: entry number, 1-n
# param 3: separator, default ':'
getCSVValue()
{
	gcvValue="${1}";
	gcvEntry="${2}";
	gcvSep="${3:-:}";
	echo "`echo ${gcvValue} | cut -d\"${gcvSep}\" -f${gcvEntry}`";
}

isFunction()
{
	test -n "`type $1 2>/dev/null | sed -n \"s|^\($1\).*function.*\$|\1|p\" 2>/dev/null`";
}

# param 1: optional username to get id for
getUid()
{
	echo "`id ${1} | cut -d '(' -f1 | cut -d '=' -f2`";
}

# param 1: pidfilename
# output: echoe the pid if any, empty otherwise
getPIDFromFile()
{
	gpffFile="${1}";
	test -n "${gpffFile}" || return 0;
	test -f "${gpffFile}" || return 0;
	echo "`echo \"\`cat ${gpffFile} 2>/dev/null\`\" | sed -n 's/\([0-9][0-9]*\)/\1/p'`";
}

# check if a given process id still appears in process list
# note on WIN32(cygwin): it is assumed that a WDS_BIN is looked up in the process list
#
# param $1 is the process id to check for
#
# returning 1 if process still exists, 0 if the process is not listed anymore
# check if a given process id still appears in process list
#
# param $1 is the process id to check for
#
# returning 0 if process still exists, 1 if the process is not listed anymore
checkProcessId()
{
	cpiPid="${1}";
	cpiSuccess=0;
	cpiFailure=1;
	if [ -n "$cpiPid" ]; then
		# check if pid still exists
		if [ $isWindows -eq 1 ]; then
			# use -q to suppress output and exit with 0 when matched
			ps -ef | grep -q "${cpiPid}.*${WDS_BIN}" && return ${cpiSuccess}
		else
			ps -p ${cpiPid} >/dev/null && return ${cpiSuccess}
		fi
		printf "process with pid:${cpiPid} has gone!\n" >&2;
	fi
	return ${cpiFailure};
}

# params: files to remove
removeFiles()
{
	filesToRemove="$@";
	for f in ${filesToRemove}; do
		test -f "${f}" && rm -f -- "${f}";
	done
}

########## functions with dependencies ##########

# search for a joined directory name beginning from given directory
# the search is only done in the given directory, no recursion
#
# param $1 is the path where we search
# param $2 is the name of the beginning segment
# param $3 is the name of the ending segment
# param $4, optional, is the field separator when all segments found are required
# param $5, optional, if set to 0, do not search for *${4}*
#
# returning 1 if it the path was found, 0 otherwise
#
# example:
# want to have a dirname in variable FOOBAR like TestPrj_config
# FOOBAR=`SearchJoinedDir "." "TestPrj" "config"`
# the result can be either TestPrj_config if found or just config
#
SearchJoinedDir()
{
	testpath=${1};
	firstseg=${2};
	lastseg=${3};
	showalldirs=0;
	if [ -n "$4" ]; then
		showalldirs=1;
	fi;
	pathsep=${4:-:};
	doStarEnding=${5:-1};
	tmppath="";
	# check if we got a searchable directory first
	if [ -d "$testpath" -a -r "$testpath" -a -x "$testpath" ]; then
		# search for a 'compound' directory name in the given directory
		tmppath=`cd $testpath &&
		if [ ${doStarEnding} -eq 1 ]; then
			for dname in ${firstseg}*${lastseg}* *${lastseg}*; do
				if [ -d "${dname}" ]; then
					if [ -n "$tmppath" ]; then
						tmppath="${tmppath}${pathsep}";
					fi;
					# strip trailing slash
					tmppath=\`removeTrailingSlash "${tmppath}${dname}"\`;
					echo $tmppath;
					if [ $showalldirs -eq 0 ]; then
						break;
					fi;
				fi;
			done;
		else
			for dname in ${firstseg}*${lastseg}*; do
				if [ -d "${dname}" ]; then
					if [ -n "$tmppath" ]; then
						tmppath="${tmppath}${pathsep}";
					fi;
					# strip trailing slash
					tmppath=\`removeTrailingSlash "${tmppath}${dname}"\`;
					echo $tmppath;
					if [ $showalldirs -eq 0 ]; then
						break;
					fi;
				fi;
			done;
		fi;
		`
	fi
	echo "${tmppath}"
}

# param $1 path to make relative to $2
# param $2 base path which must be a leading part of $1 to make this function work
# output the relative movement from $2 to $1 if $2 is below $1, $1 otherwise
relpath()
{
	pathtoresolve="`removeTrailingSlash \"${1}\"`";
	basepath="`removeTrailingSlash \"${2}\"`";
	relmove="`echo $pathtoresolve | sed \"s|^${basepath}||\"`";
	moveToReturn=.;
	if [ -n "${relmove}" ]; then
		if [ "${relmove}" != "${pathtoresolve}" ]; then
			moveToReturn="`echo $relmove | sed \"s|^/||\"`";
		else
			moveToReturn="${pathtoresolve}";
		fi;
	fi;
	echo "${moveToReturn}";
}

# param $1: a literal hostname
# output: the passed in host's full quqlified domain name
getdomain()
{
	hostLookupTool="`getFirstValidTool \"/usr/local/bin:/usr/bin:/bin\" host nslookup`";
	if [ -n "${hostLookupTool}" -a -n "${1}" ]; then
		fullqualified="`${hostLookupTool} $1`"
		case ${hostLookupTool} in
			host) fullqualified=`getHead "${fullqualified}" " "`;;
			nslookup) fullqualified=`echo "${fullqualified}" | sed -n 's/^Name://p' | tr -d '\t'`;;
		esac
		domainSuffix=`getTail "${fullqualified}" "."`
		echo "${domainSuffix}"
		return 0
	fi
	echo "unknown domain"
	return 1
}

# test if given path-segment exists in given path
#
# param $1 is the path to test
# param $2 is the path-segment separator
# param $3 is the path-segment to test
#
# returning 0 if it exists, 1 otherwise
existInPath()
{
	eipPath="${1}";
	eipSegsep="${2}";
	eipTstseg="${3}";
	while eipSeg="`getHead \"${eipPath}\" \"$eipSegsep\"`"; [ -n "${eipPath}" ]; do
		eipPath="`getTail \"${eipPath}\" \"${eipSegsep}\"`";
		test -n "${eipSeg}" || continue;
		test "${eipSeg}" = "${eipTstseg}" || continue;
		return 0
	done
	return 1
}

# append given path-segment if it does not exist in the path
#
# param $1 is the value of the 'path'-variable
# param $2 is the path-segment separator
# param $3 is the path-segment(s) to append
# param $4 allow duplicates, default 0, optional
#
# output echo new path
appendPathEx()
{
	apePath="${1}";
	apeSegsep="${2}";
	apeAddseg="${3}";
	apeAllowdups=${4:-0};
	if [ -n "$apeAddseg" ]; then
		while apeSeg="`getHead \"${apeAddseg}\" \"$apeSegsep\"`"; [ -n "${apeAddseg}" ]; do
			apeAddseg="`getTail \"${apeAddseg}\" \"${apeSegsep}\"`";
			existInPath "${apePath}" "${apeSegsep}" "${apeSeg}"
			if [ $? -eq 1 -o ${apeAllowdups} -eq 1 ]; then
				# path-segment does not exist, append it
				apePath="`removeTrailingSlash \"${apePath}\" \"${apeSegsep}\"`";
				test -n "${apePath}" && apePath="${apePath}${apeSegsep}";
				apePath="${apePath}${apeSeg}";
			fi
		done
	fi
	echo "$apePath";
}

# clean the given path, eg. test for single existance of a path segment
#
# param $1 value containing segments to clean
# param $2 is the path-segment separator
#
# output new path
cleanPathEx()
{
	cpePath="${1}";
	cpeSegsep="${2}";
	while cpeSeg="`getHead \"${cpePath}\" \"${cpeSegsep}\"`"; [ -n "${cpePath}" ]; do
		cpePath="`getTail \"${cpePath}\" \"${cpeSegsep}\"`";
		cpeResultPath="`appendPathEx \"${cpeResultPath}\" \"${cpeSegsep}\" \"${cpeSeg}\"`"
	done
	echo "${cpeResultPath}"
}

# prepend given path-segment if it does not exist in the path
#
# param $1 value of the 'path'-variable
# param $2 is the path-segment separator
# param $3 is the path-segment(s) to prepend
#
# output new path
prependPathEx()
{
	ppePath="${1}";
	ppeSegsep="${2}";
	ppeAddseg="${3}";
	ppeAllowdups=${4:-0};
	if [ -n "$ppeAddseg" ]; then
		while ppeSeg="`getHead \"${ppeAddseg}\" \"$ppeSegsep\"`"; [ -n "${ppeAddseg}" ]; do
			ppeAddseg="`getTail \"${ppeAddseg}\" \"${ppeSegsep}\"`";
			existInPath "${ppePath}" "${ppeSegsep}" "${ppeSeg}"
			if [ $? -eq 1 -a -n "${ppeSeg}" ]; then
				# path-segment does not exist, preppend it
				ppePath="`removeFromHead \"${ppePath}\" \"${ppeSegsep}\"`";
				test -n "${ppePath}" && ppePath="${ppeSegsep}${ppePath}";
				ppePath="${ppeSeg}${ppePath}";
			fi
		done
	fi
	echo "$ppePath";
}

# insert sorted
#
# param $1 are current values to insert to
# param $2 is the path-segment separator
# param $3 is the path-segment to insert
#
insertInPathSorted()
{
	iipsPath="${1}";
	iipsSegsep="${2}";
	iipsAddseg="${3}";
	if [ -n "$iipsAddseg" ]; then
		iipsPath="`appendPathEx \"$iipsPath\" \"$iipsSegsep\" \"$iipsAddseg\" 0`";
	fi
	# sort
	iipsPath="`echo $iipsPath | tr \"$iipsSegsep\" '\n' | sort | uniq | tr '\n' \"$iipsSegsep\"`"
	iipsPath="`removeTrailingSlash \"$iipsPath\" \"$iipsSegsep\"`";
	echo "$iipsPath";
}

# param 1: selected number
# param 2: number of values
# param 3: value list separator, default " "
# param 4: separated list of values
# output: selected value
getNumberedEntry()
{
	gneSelected=${1:-0};
	gneMaxNumber=${2};
	gneSeparator="${3:- }";
	gneValues="${4}";
	returnValue="";
	if [ ${gneMaxNumber} -ge 1 ]; then
		menuNumber=0;
		if [ $gneSelected -ge 1 -a $gneSelected -le ${gneMaxNumber} ]; then
			while menuEntry="`getHead \"${gneValues}\" \"${gneSeparator}\"`"; [ -n "${gneValues}" ]; do
				gneValues="`getTail \"${gneValues}\" \"${gneSeparator}\"`";
				menuNumber=`expr $menuNumber + 1`
				returnValue="$menuEntry";
				test $gneSelected -eq $menuNumber && break;
			done
		fi
	fi
	echo "$returnValue";
}

# param 1: name of variable to export result into
# param 2: value list separator, default " "
# param 3: separated list of values
# output: selected value exported into $1, empty if aborted
selectInMenu()
{
	ret_var="${1}";
	simSeparator="${2:- }";
	simValues="${3}";
	returnValue="";
	if [ $# -ge 2 ]; then
		menuNumber=0;
		loopValues="${simValues}";
		while menuEntry="`getHead \"${loopValues}\" \"${simSeparator}\"`"; [ -n "${loopValues}" ]; do
			loopValues="`getTail \"${loopValues}\" \"${simSeparator}\"`";
			menuNumber=`expr $menuNumber + 1`
			printf "%2d) %s\n" $menuNumber "$menuEntry" >&2
		done
		printf "#? " >&2
		read selectedNumber
		selectedNumber=`expr $selectedNumber - 0 2>/dev/null || echo 0`
		returnValue="`getNumberedEntry $selectedNumber $menuNumber \"${simSeparator}\" \"${simValues}\"`";
	fi
	eval ${ret_var}="\"$returnValue\"";
	export ${ret_var}
}

# check for an existing executable
#
# param 1: optional, too to look for, default gdb
# param 2: optional, path in which to search for tool
#
# output command line to start executable, might include prepended setting of LD_LIBRARY_PATH
# return 0 in case an executable was found, 1 otherwise
findValidGnuToolCommand()
{
	fvgcToolname="${1:-gdb}";
	fvgcDirs="${2:-/usr/local/${fvgcToolname}:/usr/local/bin:/usr/bin:/bin}";
	fvgcListSep=":";
	printf "Searching ${fvgcToolname} in directories [%s]" "${fvgcDirs}" >&2;
	fvgcVariants="`findExecutableWithPath \"${fvgcDirs}\" \"${fvgcToolname}\" \"-*\" \"${fvgcListSep}\"`";
	printf "\n" >&2;
	fvgcVariants="`appendPathEx \"${fvgcVariants}\" \"${fvgcListSep}\" \"\`myWhich ${fvgcToolname}\`\"`";
	while fvgcToUse="`getHead \"${fvgcVariants}\" \"${fvgcListSep}\"`"; [ -n "${fvgcVariants}" ]; do
		fvgcVariants="`getTail \"${fvgcVariants}\" \"${fvgcListSep}\"`";
		# test if we can successfully obtain the version
		fvgcCommandToExec="${fvgcToUse}";
		hasVersionReturn "${fvgcCommandToExec}" >/dev/null && echo "${fvgcCommandToExec}" && return 0;
		# if not, we probably need to add /usr/local/lib to LD_LIBRARY_PATH
		fvgcLDPath=/usr/local/lib:$LD_LIBRARY_PATH;
		fvgcCommandToExec="LD_LIBRARY_PATH=${fvgcLDPath} ${fvgcToUse}";
		hasVersionReturn "${fvgcCommandToExec}" >/dev/null && echo "${fvgcCommandToExec}" && return 0;
	done
	return 1;
}


########## deprecated functions ##########

# append given path-segment if it does not exist in the path
#
# param $1 is the name of the 'path'-variable
# param $2 is the path-segment separator
# param $3 is the path-segment(s) to append
# param $4 allow duplicates, default 0, optional
#
# output exporting new path into given name ($1)
appendPath()
{
	apPathname=${1};
	apPath="echo $"${apPathname};
	apSegsep=${2};
	apAddseg=${3};
	apAllowdups=${4:-0};
	if [ -n "$apAddseg" ]; then
		apPath=`eval $apPath`;
		apPath="`appendPathEx \"$apPath\" \"$apSegsep\" \"$apAddseg\" ${apAllowdups}`"
		eval ${apPathname}="$apPath";
		export ${apPathname};
	fi
}

# test if given path-segment exists in given path and remove it
#
# param $1 is the name of the 'path'-variable
# param $2 is the path-segment separator
# param $3 is the path-segment to test and delete
#
# output exporting new path into given name ($1)
deleteFromPath()
{
	dfpPathname=${1};
	dfpSegsep=${2};
	dfpSeg=${3};
	dfpPath="echo $"${dfpPathname};
	dfpPath=`eval $dfpPath`;
	dfpPath="`deleteFromPathEx \"${dfpPath}\" \"${dfpSegsep}\" \"${dfpSeg}\"`"
	if [ -n "${dfpPath}" ]; then
		eval ${dfpPathname}="${dfpPath}";
		export ${dfpPathname};
	else
		unset ${dfpPathname};
	fi
	unset dfpPath;
}

# clean the given path, eg. test for single existance of a path segment
#
# param $1 is the name of the 'path'-variable
# param $2 is the path-segment separator
#
# output exporting new path into given name ($1)
cleanPath()
{
	cpPathname=${1};
	cpSegsep=${2};
	cpSeg=${3};
	cpPath="echo $"${cpPathname};
	cpPath=`eval $cpPath`;
	cpPath="`cleanPathEx \"${cpPath}\" \"${cpSegsep}\"`"
	if [ -n "${cpPath}" ]; then
		eval ${cpPathname}="${cpPath}";
		export ${cpPathname};
	else
		unset ${cpPathname};
	fi
	unset cpPath;
}

# prepend given path-segment if it does not exist in the path
#
# param $1 is the name of the 'path'-variable
# param $2 is the path-segment separator
# param $3 is the path-segment(s) to prepend
#
# output exporting new path into given name ($1)
prependPath()
{
	ppPathname=${1};
	ppPath="echo $"${ppPathname};
	ppSegsep=${2};
	ppAddseg=${3};
	if [ -n "$ppAddseg" ]; then
		ppPath=`eval $ppPath`;
		ppPath="`prependPathEx \"$ppPath\" \"$ppSegsep\" \"$ppAddseg\"`"
		eval ${ppPathname}="$ppPath";
		export ${ppPathname};
	fi
}

# returns the given path in dos-notation: drive:directory with forward slashes!
# param $1 is the path to be converted
# param $2 is the name of the output variable getting the NT path
#
# returning 1 if it the path could be converted, 0 otherwise
#
# example: $ getDosDir "/home/sniff+" "SNIFF_DIR"
#          $ echo $SNIFF_DIR
#          d:/win32app/sniff
#
getDosDir()
{
	tmppath="";
	varname=${2};
	tmppath=`cygpath -w -t mixed $1`;
	if [ -z "${tmppath}" ]; then
		return 0;
	else
		eval ${varname}="${tmppath}";
		export ${varname};
		return 1;
	fi
}

# returns the given path in unix-notation: directory with forward slashes!
# param $1 is the path to be converted
# param $2 is the name of the output variable getting the unixified path
#
# returning 1 if it the path could be converted, 0 otherwise
#
# example: $ getUnixDir "D:/users/hum/DEVGUGUS" "PROJECTDIR"
#          $ echo $PROJECTDIR
#          /home/hum/DEVGUGUS
#
getUnixDir()
{
	tmppath="";
	varname=${2};
	tmppath=`cygpath -u $1`;
	if [ -z "${tmppath}" ]; then
		return 0;
	else
		eval ${varname}="${tmppath}";
		export ${varname};
		return 1;
	fi
}

# display a selection list of current Develop-directories
# - directories must start with DEV to be displayed in the list
# - directories must either be real dirs or links in the HOME-directory
#
# param $1 is name of the output variable for selected path
# param $2 is name of the output variable for last path-segment
# param $3 is optional and can be used to specify the directory to select for non-interactive mode
#
# output setting variable $1 to value of selected path
# output setting variable $2 to value of last path-segment
selectDevelopDir()
{
	myDirs="`cd ${HOME} && for name in DEV*; do if [ -d $name -o -h $name ]; then echo $name; fi; done`";
	if [ -n "$3" ]; then
		for myenv in $myDirs; do
			relSeg="`basename ${myenv}`";
			if [ "$relSeg" = "$3" ]; then
				#echo 'we have a match at ['$relSeg']';
				# use pwd -P to follow links and get 'real' directory
				# especially needed for windows! but shouldn't matter for Unix
				devpath=`cd && cd $myenv >/dev/null 2>&1 && pwd -P`;
				if [ $isWindows -eq 1 ]; then
					getDosDir "$devpath" "${1}_NT";
				fi
				eval ${1}="$devpath";
				export ${1};
				# trim path until last segment
				eval ${2}="$relSeg";
				export ${2};
				break
			fi;
		done
	else
		echo ""
		echo "Where Do you want to develop today?"
		echo ""
		selectInMenu myenv " " "$myDirs"
		if [ -n "${myenv}" ]; then
			# use pwd -P to follow links and get 'real' directory
			# especially needed for windows! but shouldn't matter for Unix
			devpath=`cd && cd $myenv >/dev/null 2>&1 && pwd -P`;
			if [ $isWindows -eq 1 ]; then
				getDosDir "$devpath" "${1}_NT";
			fi
			eval ${1}="$devpath";
			export ${1};
			# trim path until last segment
			eval ${2}="`basename ${myenv}`";
			export ${2};
		fi
	fi;
}

# look for specified executable within given path
#
# param 1: is the path to check for executable, multiple values separated by ':' supported
# param 2: is the name of the executable to searchs
# param 3: is the version suffix for the executable to search
# param 4: is the separator in the returned list, default ':'
#
# output separated list of matching executables
findExecutableWithPath()
{
	sgidPath="${1}";
	sgidCompname="${2}";
	sgidVersuffix="${3}";
	sgidSegsep="${4:-:}";
	sgidPathsep=":";
	sgidCollectedExecutables="";
	while sgidSeg="`getHead \"${sgidPath}\" \"${sgidPathsep}\"`"; [ -n "${sgidPath}" ]; do
		sgidPath="`getTail \"${sgidPath}\" \"${sgidPathsep}\"`";
		printf "." >&2;
		for f in `find ${sgidSeg} -follow -type f "(" -name "${sgidCompname}" -o -name "${sgidCompname}${sgidVersuffix}" ")" 2>/dev/null`; do
			test -x "${f}" && sgidCollectedExecutables="`appendPathEx \"${sgidCollectedExecutables}\" \"${sgidSegsep}\" \"${f}\"`";
		done
	done
	echo "${sgidCollectedExecutables}";
}

# display a selection list of currently installed gcc/g++ compilers in given list of directories
#
# param $1 is the path to check for gnu compilers
# param $2 is the path-segment separator
# param $3 is optional and can be used to specify default for non-interactive mode
#
# output setting variable $1 to value of selected compilers, separated by ':'
selectGnuCompilers()
{
	sgcReturnName="${1}";
	sgcPath="${2}";
	sgcSegsep="${3:-:}";
	sgcDefaultSelector="${4}";
	sgcAllCompilers="";
	sgcCompilerSeparator=";";
	gppcomp="";
	printf "Searching gcc compiler(s) in directories [%s]" "${sgcPath}" >&2
	sgcAllCompilers="`findExecutableWithPath \"${sgcPath}\" \"gcc\" \"-*\" \":\"`";
	printf "\n" >&2;
	if [ $PRINT_DBG -ge 1 ]; then echo "all compilers [${sgcAllCompilers}]"; fi

	selectvar="";
	printf "Searching matching g++ compiler(s) for  [%s]" "${sgcAllCompilers}" >&2
	while sgcSeg="`getHead \"${sgcAllCompilers}\" \"${sgcSegsep}\"`"; [ -n "${sgcAllCompilers}" ]; do
		sgcAllCompilers="`getTail \"${sgcAllCompilers}\" \"${sgcSegsep}\"`";
		printf "." >&2;
		dname=`dirname ${sgcSeg}`;
		cpname=`basename ${sgcSeg}`;
		vername="`removeFromHead \"${cpname}\" \"gcc\"`";
		gppcomp="`findExecutableWithPath \"${dname}\" \"g++\" \"${vername}\"`";
		if [ -n "${sgcSeg}" -a -n "${gppcomp}" ]; then
			verstrgcc=`${sgcSeg} -v 2>&1 | grep "gcc version"`;
			selectvar="`insertInPathSorted \"$selectvar\" \"${sgcCompilerSeparator}\" \"${verstrgcc}:${sgcSeg}:${gppcomp}\"`";
			if [ $PRINT_DBG -ge 2 ]; then echo "current path [${dname}] and g++ compiler [${gppcomp}] vername [${verstrgcc}]"; fi
		fi;
	done;
	printf "\n" >&2;
	if [ $PRINT_DBG -ge 2 ]; then echo "selectvar is [${selectvar}]"; fi
	linetouse="";
	if [ -n "${sgcDefaultSelector}" ]; then
		if [ $PRINT_DBG -ge 2 ]; then echo "testing for specified default [${sgcDefaultSelector}]"; fi
		oldifs="${IFS}";
		IFS="${sgcCompilerSeparator}";
		for myset in ${selectvar}; do
			IFS=${oldifs};
			curgcc=`echo ${myset} | cut -d':' -f2`;
			if [ "${curgcc}" = "${sgcDefaultSelector}" ]; then
				linetouse="${myset}";
				break
			fi;
		done;
	fi;
	# fallback if given default selection was not successful
	if [ -z "${linetouse}" ]; then
		if [ -n "${selectvar}" ]; then
			echo ""
			echo "Which gcc/g++ compilerset would you like to use?"
			echo ""
			selectInMenu myset "${sgcCompilerSeparator}" "${selectvar}"

			if [ -n "${myset}" ]; then
				if [ $PRINT_DBG -ge 1 ]; then echo "selected set is [${myset}]"; fi
				linetouse="${myset}";
			fi
		fi;
	fi;
	if [ -n "${linetouse}" ]; then
		eval ${sgcReturnName}="`echo ${linetouse} | cut -d':' -f2,3`";
		export ${sgcReturnName};
	fi
}

# set-up variables for a selectable development environment
# - display a selection list of current Develop-directories
# - set WD_OUTDIR and COAST_LIBDIR
# - adjust PATH and LD_LIBRARY_PATH
#
# param $1 used to specify the directory to select for non-interactive mode, optional
# param $2 used to specify the default gcc compiler to use
#
# return 1 if successful, 0 otherwise
setDevelopmentEnv()
{
	GNU_COMPS="";
	prependPath GCC_SEARCH_PATH ":" "/usr/bin:/usr/local/bin:/opt:/usr/sfw/bin:/opt/sfw/bin"
	selectGnuCompilers "GNU_COMPS" "${GCC_SEARCH_PATH}" ":" "${2}"
	if [ $PRINT_DBG -ge 1 ]; then echo "selected compilerset [${GNU_COMPS}]"; fi;
	if [ -n "${GNU_COMPS}" ]; then
		CC="`echo ${GNU_COMPS} | cut -d':' -f1`";
		CXX="`echo ${GNU_COMPS} | cut -d':' -f2`";
		export CC CXX
	fi

	selectDevelopDir "DEV_HOME" "DEVNAME" $1
	if [ -n "${DEV_HOME}" -a -n "${DEVNAME}" ]; then
		if [ -z "${WD_OUTDIR}" ]; then
			WD_OUTDIR=${SYS_TMP}/objectfiles_${USER}/${DEVNAME};
		else
			WD_OUTDIR=${WD_OUTDIR}/${USER}/${DEVNAME};
		fi
		if [ "$USER" = "whoever" -o "$USER" = "whoeverToo" ]; then
			COAST_LIBDIR=${DEV_HOME}/lib
		else
			if [ -z "${COAST_LIBDIR}" ]; then
				COAST_LIBDIR=${WD_OUTDIR}/lib/${OSREL}
			fi
		fi
		if [ $isWindows -eq 1 ]; then
			getDosDir "$WD_OUTDIR" "WD_OUTDIR_NT"
		fi
		export WD_OUTDIR COAST_LIBDIR
	else
		echo "no environment selected, exiting..."
		return 0;
	fi

	if [ $isWindows -eq 1 ]; then
		prependPath "PATH" ":" "${COAST_LIBDIR}"
	else
		eval LD_LIBRARY_PATH_NATIVE=${LD_LIBRARY_PATH};
		export LD_LIBRARY_PATH_NATIVE;
		LD_LIBRARY_PATH="`cleanPathEx \"$LD_LIBRARY_PATH\" \":\"`"
		LD_LIBRARY_PATH="`prependPathEx \"$LD_LIBRARY_PATH\" \":\" \"${COAST_LIBDIR}\"`"
	fi
	echo ""
	echo "following variables were set:"
	echo ""
	if [ -n "${CC}" ]; then
		echo "CC                     : ["${CC:-gcc}"]"
	fi
	if [ -n "${CXX}" ]; then
		echo "CXX                    : ["${CXX:-g++}"]"
	fi
	echo "DEV_HOME               : ["${DEV_HOME}"]"
	if [ $isWindows -eq 1 ]; then
		echo "DEV_HOME_NT            : ["${DEV_HOME_NT}"]"
	fi
	echo "WD_OUTDIR              : ["${WD_OUTDIR}"]"
	if [ $isWindows -eq 1 ]; then
		echo "WD_OUTDIR_NT      : ["${WD_OUTDIR_NT}"]"
	fi
	echo "COAST_LIBDIR              : ["${COAST_LIBDIR}"]"
	echo "PATH                   : ["${PATH}"]"
	if [ $isWindows -eq 0 ]; then
		echo "LD_LIBRARY_PATH        : ["${LD_LIBRARY_PATH}"]"
		echo "LD_LIBRARY_PATH_NATIVE : ["${LD_LIBRARY_PATH_NATIVE}"]"
	fi
	if [ $isWindows -eq 0 -a -n "${LD_RUN_PATH}" ]; then
		echo "LD_RUN_PATH            : ["${LD_RUN_PATH}"]"
	fi
	echo ""
	return 1;
}

# param $1 if set to 1, also unset some variables, optional
cleanDevelopmentEnv()
{
	if [ ${isWindows} -eq 1 ]; then
		PATH="`deleteFromPathEx \"$PATH\" \":\" \"$COAST_LIBDIR\"`";
		if [ ${1:-0} -eq 1 ]; then
			unset WD_OUTDIR_NT DEV_HOME_NT;
		fi;
	else
		LD_LIBRARY_PATH="`deleteFromPathEx \"$LD_LIBRARY_PATH\" \":\" \"$COAST_LIBDIR\"`";
	fi
	if [ ${1:-0} -eq 1 ]; then
		unset WD_OUTDIR COAST_LIBDIR DEV_HOME DEVNAME;
	fi;
}

# append the given tokens to the given variable name
#
# param $1 is the name of the variable to append the tokens to
# param $2 is the variable containing the tokens to append
# param $3 is the separator, eg. " -a " or " -o "
appendTokens()
{
	locOutname=${1};
	locPreOutname="echo $"${locOutname};
	locOutput="`eval $locPreOutname`";
	locTokens="${2}";
	locSep="${3}";
	if [ $cfg_dbg -ge 2 ]; then echo 'current token separator is ['$locSep']'; fi
	for cfgtok in $locTokens; do
		if [ $cfg_dbg -ge 2 ]; then echo 'current token is ['$cfgtok']'; fi
		locOutput="$locOutput${locSep}$cfgtok";
	done;
	if [ $cfg_dbg -ge 2 ]; then echo 'appended Output is ['$locOutput']'; fi
	eval ${locOutname}='${locOutput}';
	export ${locOutname};
}

# generate gnu debugger command file which may be used for batch
# invocations of the debugger.
#
# param 1: is the name of the generated batch file
# param 2: binary to execute
# param 3: run executable in background, default 1, set to 0 to run gdb in foreground
# param 4.. arguments passed to the debugged program
#
generateGdbCommandFile()
{
	ggcfBatchFile="${1}";
	ggcfBinaryToExecute="${2}";
	ggcfRunInBackground=${3};
	test $# -ge 3 || return 1;
	shift 3
	ggcfServerOptions="$@";
	# <<-EOF ignore tabs, nice for formatting heredocs
cat > ${ggcfBatchFile} <<-EOF
	handle SIGSTOP nostop nopass
	handle SIGLWP  nostop pass
	handle SIGTERM nostop pass
	handle SIGINT  nostop pass
	set environment PATH=${PATH}
	set environment COAST_ROOT=${COAST_ROOT}
	set environment COAST_PATH=${COAST_PATH}
	set environment COAST_LIBDIR=${COAST_LIBDIR}
	set environment WD_ROOT=${COAST_ROOT}
	set environment WD_PATH=${COAST_PATH}
	set environment WD_LIBDIR=${COAST_LIBDIR}
	set environment LD_LIBRARY_PATH=${LD_LIBRARY_PATH}
	set environment LOGDIR=${LOGDIR}
	set environment PID_FILE=${PID_FILE}
	set auto-solib-add 1
	file ${ggcfBinaryToExecute}
	set args ${ggcfServerOptions}
EOF
	if [ $ggcfRunInBackground -eq 1 ]; then
cat >> ${ggcfBatchFile} <<-EOF
	set pagination 0
	run
	if \$_isvoid(\$_siginfo)
		shell rm ${ggcfBatchFile}
		if \$_isvoid(\$_exitcode)
			set \$_exitcode=0
		end
		quit \$_exitcode
	else
		! echo "\`date +'%Y%m%d%H%M%S'\`: ========== GDB backtrace =========="
		backtrace full
		info registers
		x/16i \$pc
		thread apply all backtrace
		if !\$_isvoid(\$_siginfo)
			set \$_exitcode=\$_siginfo.si_signo
		end
		if \$_isvoid(\$_exitcode)
			set \$_exitcode=55
		end
		shell rm ${ggcfBatchFile}
		quit \$_exitcode
	end
EOF
	fi;
}

resolvePath()
{
	rpThePath="${1}";
	rpFile="`basename \"${rpThePath}\"`";
	test -d "${rpThePath}" || rpThePath="`dirname \"${rpThePath}\"`";
	rpThePath="`cd ${rpThePath} && pwd`";
	if [ -n "${rpFile}" ]; then
		test -n "${rpThePath}" && rpThePath="${rpThePath}/";
		rpThePath="${rpThePath}${rpFile}";
	fi
	echo "${rpThePath}";
}

# dereference a file/path - usually a link - and find its real origin as absolute path
#
# param $1 is the file/path to dereference
#
# output echo dereferenced file/path
# returning 0 in case the given name was linked, 1 otherwise
deref_links()
{
	loc_name=${1};
	is_link=1;
	cur_path=`pwd`
	dlLsBinary=`unalias ls 2>/dev/null; type -fP ls`;
	while [ -h "$loc_name" ]; do
		if [ $PRINT_DBG -ge 2 ]; then printf $loc_name >&2; fi
		loc_name=`${dlLsBinary} -l $loc_name | cut -d'>' -f2- | cut -d' ' -f2- | sed 's|/$||'`;
		isAbsPath "${loc_name}" || loc_name="`resolvePath \"${cur_path}/${loc_name}\"`";
		if [ $PRINT_DBG -ge 2 ]; then echo ' ['${1}'] was linked to ['$loc_name']' >&2; fi
		cur_path=`dirname ${loc_name}`
		is_link=0;
	done
	echo "$loc_name";
	return $is_link;
}

########## setup some values ##########

SYSFUNCSLOADED=${SYSFUNCSLOADED:-0};
sysfuncsExportvars=""

if [ ${SYSFUNCSLOADED} -eq 0 ]; then
	# try to find out on which OS we are currently running, eg. SunOS, Linux or Windows
	CURSYSTEM=`uname -s 2>/dev/null` || CURSYSTEM="unknown"

	if [ "${CURSYSTEM}" = "Windows" -o "`echo ${CURSYSTEM} | cut -d'-' -f1`" = "CYGWIN_NT" ]; then
		CURSYSTEM="Windows"
		isWindows=1;
		OSREL=Win_i386
		OSREL_MAJOR=0
		OSREL_MINOR=0
		USR_TMP=${HOME}/tmp;
		SYS_TMP=${TEMP:-${TMP:-$USR_TMP}};
	else
		isWindows=0;
		OSREL=${CURSYSTEM}_;
		if [ "${CURSYSTEM}" = "Linux" ]; then
			OSREL=${OSREL}glibc_;
			foundVersion=`getGLIBCVersion "."`;
			GLIBCVER=$foundVersion
		else
			foundVersion=`uname -r`;
		fi;
		OSREL=${OSREL}${foundVersion};
		OSREL_MAJOR=`echo ${foundVersion} | cut -d'.' -f1`;
		OSREL_MINOR=`echo ${foundVersion} | cut -d'.' -f2`;
		USR_TMP=${HOME}/tmp;
		SYS_TMP=/tmp;
	fi

	sysfuncsExportvars="CURSYSTEM isWindows OSREL OSREL_MAJOR OSREL_MINOR USR_TMP SYS_TMP";

	# OSTYPE is needed for compilation using makefiles, ensure it is set
	if [ -z "${OSTYPE}" ]; then
		# use bash to get ostype, only bash defines it...
		if [ -x "/bin/bash" ]; then
			OSTYPE="`bash -c 'echo $OSTYPE'`";
			sysfuncsExportvars="$sysfuncsExportvars OSTYPE"
		fi
	fi

	# it seems that some shells do not set the USER variable but the variable LOGNAME
	if [ -z "${USER}" ]; then
		echo 'setting USER variable to ['$LOGNAME']'
		USER=${LOGNAME}
		sysfuncsExportvars="$sysfuncsExportvars USER"
	fi

	# system specific settings
	APP_SUFFIX=""
	LIB_SUFFIX=".a"
	SHAREDLIB_SUFFIX=".so"
	if [ ${isWindows} -eq 1 ]; then
		APP_SUFFIX=".exe"
		LIB_SUFFIX=".lib"
		SHAREDLIB_SUFFIX=".dll"
	fi
	sysfuncsExportvars="$sysfuncsExportvars APP_SUFFIX LIB_SUFFIX SHAREDLIB_SUFFIX";
	export $sysfuncsExportvars
fi

SYSFUNCSLOADED=1
export SYSFUNCSLOADED
