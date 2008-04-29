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

# retrieve value of variable by sourcing a file and checking for its value
#
# param $1 path to start from
# param $2 directory from where to source the file containing variables, either relative to $1 or absolute
# param $3 name of the file containing variables
# param $4 name of variable to get value from
# param $5 name of output variable getting the retrieved value
#
# output exporting value into given variable name ($5)
getConfigVar()
{
	loc_prjPath=${1};
	loc_scDir=${2:-.}; # set appropriate default
	loc_scName=${3:-scriptNameNotGiven};
	loc_name=${4};
	ret_var=${5};
	loc_name=`/bin/ksh -c "cd ${loc_prjPath}; mypath=${loc_scDir}; . ${loc_scDir}/${loc_scName} >/dev/null 2>&1; eval \"echo $\"$loc_name"`
	eval ${ret_var}="$loc_name";
}

# retrieve the glibc version number from /lib/libc.so.6 or /lib/ld-linux.so.2
#
# param $1 is the name of the 'version'-variable
# param $2 is the versionnumber separator
#
# output exporting version into given name ($1)
getGLIBCVersion()
{
	local versionname=${1};
	local versep=${2};
	glibcstr=`strings /lib/libc.so.6 | grep GLIBC_[0-9]\.`;
	if [ $? -eq 0 ]; then
		glibcstr=`strings /lib/libc.so.6 | grep GLIBC_[0-9]\. | sort -r`;
		# versions found, the highest number should be the first string because of the reverse sort
		# get the first string and cut away GLIBC_ part
		local verbase=`echo $glibcstr | cut -d' ' -f 1 | cut -b 7-`;
	else
		# no version in libc - seems to be quite old and we have to use another method
		# we know that ld-linux.so.2 is linked to ld-V.V.V.so where V stands for a version number
		# we simply take this number and use it as the glibc version
		ldfilename=`ls -l /lib/ld-linux.so.2`;
		# just need the real file name of the link and cut away ld- part
		local verbase=`echo ${ldfilename##* } | cut -b 4-`;
	fi;
	# lets get the numbers
	V1=`echo $verbase | cut -d'.' -f 1`;
	V2=`echo $verbase | cut -d'.' -f 2`;
	V3=`echo $verbase | cut -d'.' -f 3`;
	local ptmp=$V1$versep$V2;
	if [ -n "$V3" ]; then
		ptmp=$ptmp$versep$V3;
	fi;
	export ${versionname}="${ptmp}";
}

# set a variable to either a GNU-like tool or the apropriate std-tool
#
# param $1 is the name of the 'Tool'-variable, ex FINDEXE
# param $2 is the name of the boolean 'Tool'-variable, ex IS_GNUFIND
# param $3 is the gnu tools name, ex gfind
# param $4 is the std tools name, ex find
#
# output exporting tool name into given name ($1)
testSetGnuTool()
{
	local toolvarname=${1};
	local boolvarname=${2};
	local gnutoolname="${3}";
	local stdtoolname="${4}";
	local testTool="${stdtoolname}";
	hasVersionReturn "${testTool}";
	local localBool=$?;
	if [ $localBool -eq 0 ]; then
		testTool="${gnutoolname}";
		hasVersionReturn "${testTool}";
		localBool=$?;
		if [ $localBool -eq 0 ]; then
			# reset tool to std-tool if no gnu tool found
			testTool="${stdtoolname}";
		fi
	fi
	export ${boolvarname}="${localBool}";
	export ${toolvarname}="${testTool}";
}

hasVersionReturn()
{
	echo "{}" | ${1} --version 2>/dev/null | awk '/.*GNU.*/ { exit 1; }'
	if [ $? -eq 1 ]; then
		# we found a gnu tool
		return 1;
	fi
	return 0;
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
	local tmppath="";
	local varname=${2};
	tmppath=`cygpath -w -t mixed $1`;
	if [ -z "${tmppath}" ]; then
		return 0;
	else
		export ${varname}="${tmppath}";
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
	local tmppath="";
	local varname=${2};
	tmppath=`cygpath -u $1`;
	if [ -z "${tmppath}" ]; then
		return 0;
	else
		export ${varname}="${tmppath}";
		return 1;
	fi
}

# search for a joined directory name beginning from given directory
# the search is only done in the given directory, no recursion
#
# param $1 is the name of the output variable
# param $2 is the path where we search
# param $3 is the name of the beginning segment
# param $4 is the name of the ending segment
# param $5, optional, is the field separator when all segments found are required
#
# returning 1 if it the path was found, 0 otherwise
#
# example:
# want to have a dirname in variable FOOBAR like TestPrj_config
# SearchJoinedDir "FOOBAR" "." "TestPrj" "config"
# the result can be either TestPrj_config if found or just config
#
SearchJoinedDir()
{
	local varname=${1};
	local testpath=${2};
	local firstseg=${3};
	local lastseg=${4};
	local showalldirs=0;
	if [ -n "$5" ]; then
		showalldirs=1;
	fi;
	local pathsep=${5:-:};
	local tmppath="";
	# check if we got a searchable directory first
	if [ -d "$testpath" -a -r "$testpath" -a -x "$testpath" ]; then
		# search for a 'compound' directory name in the given directory
		tmppath=`cd $testpath && $FINDEXE . -name "${firstseg}*${lastseg}*" -follow -type d ${FINDOPT} 2>/dev/null`;
		# check if we have found a directory yet
		if [ -z "$tmppath" ]; then
			# directory not yet found, only search with last segment specifier
			cd $testpath;
			for dname in *${lastseg}*; do
				# take the first we find
				if [ -n "$tmppath" ]; then
					tmppath="${tmppath}${pathsep}";
				fi;
				# strip trailing slash
				tmppath="${tmppath}${dname##*/}";
				if [ $showalldirs -eq 0 ]; then
					break;
				fi;
			done;
			cd -;
		fi
	fi
	export ${varname}="${tmppath}"
	if [ -z "${tmppath}" ]; then
		return 0;
	else
		return 1;
	fi
}

# test if given path-segment exists in given path
#
# param $1 is the path to test
# param $2 is the path-segment separator
# param $3 is the path-segment to test
#
# returning 1 if it exists, 0 otherwise
existInPath()
{
	local path=${1};
	local segsep=${2};
	local tstseg=${3};
	local ptmp="";
	local seg="";
	while seg=${path%%${segsep}*}; [ -n "$path" ]; do
		if [ "$seg" = "$tstseg" ]; then
			return 1;
		fi
		ptmp=${path#*${segsep}};
		# the previous command fails if the very last character is not a segment-separator
		# I have to check for this by comparing the last path we had with the new one
		if [ "${ptmp}" = "${path}" ]; then
			ptmp="";
		fi
		path=${ptmp};
	done
	return 0;
}

# append given path-segment if it does not exist in the path
#
# param $1 is the name of the 'path'-variable
# param $2 is the path-segment separator
# param $3 is the path-segment to append
#
# output exporting new path into given name ($1)
appendPath()
{
	local pathname=${1};
	local _path="echo $"${pathname};
	local segsep=${2};
	local addseg=${3};
	if [ -n "$addseg" ]; then
		local path=`eval $_path`;
		existInPath "${path}" "$segsep" "$addseg"
		if [ $? -eq 0 ]; then
			# path-segment does not exist, append it
			if [ -z "${path}" ]; then
				path=${addseg};
			else
				path=${path%:}${segsep}${addseg};
			fi
			export ${pathname}="$path";
		fi
	fi
}

# prepend given path-segment if it does not exist in the path
#
# param $1 is the name of the 'path'-variable
# param $2 is the path-segment separator
# param $3 is the path-segment to prepend
#
# output exporting new path into given name ($1)
prependPath()
{
	local pathname=${1};
	local _path="echo $"${pathname};
	local segsep=${2};
	local addseg=${3};
	if [ -n "$addseg" ]; then
		local path=`eval $_path`;
		existInPath "${path}" "$segsep" "$addseg"
		if [ $? -eq 0 ]; then
			# path-segment does not exist, prepend it
			if [ -z "${path}" ]; then
				path=${addseg};
			else
				path=${addseg}${segsep}${path#:};
			fi
			export ${pathname}="$path";
		fi
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
	local pathname=${1};
	local segsep=${2};
	local tstseg=${3};
	local _path="echo $"${pathname};
	local path=`eval $_path`;
	local ptmp="";
	local seg="";
	while seg=${path%%${segsep}*}; [ -n "$path" ]; do
		if [ "$seg" = "$tstseg" ]; then
			# skip segment to delete
			locDummy=1;
		else
			# append unmatched segment
			appendPath "_PATH" ":" "$seg"
		fi
		ptmp=${path#*${segsep}};
		# the previous command fails if the very last character is not a segment-separator
		# I have to check for this by comparing the last path we had with the new one
		if [ "${ptmp}" = "${path}" ]; then
			ptmp="";
		fi
		path=${ptmp};
	done
	if [ -n "${_PATH}" ]; then
		export ${pathname}="${_PATH}";
	else
		unset ${pathname};
	fi
	unset _PATH;
}

# clean the given path, eg. test for single existance of a path segment
#
# param $1 is the name of the 'path'-variable
# param $2 is the path-segment separator
#
# output exporting new path into given name ($1)
cleanPath()
{
	local pathname=${1};
	local _path="echo $"${pathname};
	local segsep=${2};
	local path=`eval $_path`;
	local ptmp="";
	local seg="";
	while seg=${path%%${segsep}*}; [ -n "$path" ]; do
		appendPath "_PATH" ":" "$seg"
		ptmp=${path#*${segsep}};
		# the previous command fails if the very last character is not a segment-separator
		# i have to check for this with comparing the last path we had with the new one
		if [ "${ptmp}" = "${path}" ]; then
			ptmp="";
		fi
		path=${ptmp};
	done
	export ${pathname}="${_PATH}";
	unset _PATH;
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
	local myDirs="`cd ${HOME} && for name in DEV*; do if [ -d $name -o -h $name ]; then echo $name; fi; done`";
	if [ -n "$3" ]; then
		for myenv in $myDirs; do
			local relSeg=${myenv##*/};
			if [ "$relSeg" = "$3" ]; then
				#echo 'we have a match at ['$relSeg']';
				# use pwd -P to follow links and get 'real' directory
				# especially needed for windows! but shouldn't matter for Unix
				local devpath=`cd && cd $myenv && pwd -P`;
				if [ $isWindows -eq 1 ]; then
					getDosDir "$devpath" "${1}_NT";
				fi
				export ${1}="$devpath";
				# trim path until last segment
				export ${2}="$relSeg";
				break
			fi;
		done
	else
		echo ""
		echo "Where Do you want to develop today?"
		echo ""
		select myenv in $myDirs; do
			# use pwd -P to follow links and get 'real' directory
			# especially needed for windows! but shouldn't matter for Unix
			local devpath=`cd && cd $myenv && pwd -P`;
			if [ $isWindows -eq 1 ]; then
				getDosDir "$devpath" "${1}_NT";
			fi
			export ${1}="$devpath";
			# trim path until last segment
			export ${2}="${myenv##*/}";
			break
		done
	fi;
}

# set-up variables for a selectable development environment
# - display a selection list of current Develop-directories
# - set WD_OUTDIR and WD_LIBDIR
# - adjust PATH and LD_LIBRARY_PATH
#
# param $1 is optional and can be used to specify the directory to select for non-interactive mode
#
# return 1 if successful, 0 otherwise
setDevelopmentEnv()
{
	selectDevelopDir "DEV_HOME" "DEVNAME" $1
	if [ -n "${DEV_HOME}" -a -n "${DEVNAME}" ]; then
		if [ -z "${WD_OUTDIR}" ]; then
			WD_OUTDIR=${SYS_TMP}/objectfiles_${USER}/${DEVNAME};
		else
			WD_OUTDIR=${WD_OUTDIR}/${USER}/${DEVNAME};
		fi
		if [ "$USER" = "whoever" -o "$USER" = "whoeverToo" ]; then
			WD_LIBDIR=${DEV_HOME}/lib
		else
			if [ -z "${WD_LIBDIR}" ]; then
				WD_LIBDIR=${WD_OUTDIR}/lib/${OSREL}
			fi
		fi
		if [ $isWindows -eq 1 ]; then
			getDosDir "$WD_OUTDIR" "WD_OUTDIR_NT"
		fi
		export WD_OUTDIR WD_LIBDIR
	else
		echo "no environment selected, exiting..."
		return 0;
	fi

	if [ $isWindows -eq 1 ]; then
		prependPath "PATH" ":" "${WD_LIBDIR}"
	else
		cleanPath "LD_LIBRARY_PATH" ":"
		prependPath "LD_LIBRARY_PATH" ":" "${WD_LIBDIR}"
	fi
	echo ""
	echo "following variables were set:"
	echo ""
	echo "DEV_HOME          : ["${DEV_HOME}"]"
	if [ $isWindows -eq 1 ]; then
		echo "DEV_HOME_NT       : ["${DEV_HOME_NT}"]"
	fi
	echo "WD_OUTDIR         : ["${WD_OUTDIR}"]"
	if [ $isWindows -eq 1 ]; then
		echo "WD_OUTDIR_NT      : ["${WD_OUTDIR_NT}"]"
	fi
	echo "WD_LIBDIR         : ["${WD_LIBDIR}"]"
	echo "PATH              : ["${PATH}"]"
	if [ $isWindows -eq 0 ]; then
		echo "LD_LIBRARY_PATH   : ["${LD_LIBRARY_PATH}"]"
	fi
	if [ $isWindows -eq 0 -a -n "${LD_RUN_PATH}" ]; then
		echo "LD_RUN_PATH       : ["${LD_RUN_PATH}"]"
	fi
	echo ""
	return 1;
}

#
#	Parameter 1: 	a literal hostname
#	Returns:	the passed in host's full quqlified domain name
#	Function tries host and nslookup commands
getdomain()
{
        $(host $1 >/dev/null 2>&1)
        if [ $? -eq 0 ]
        then
                fullqualified=$(host $1)
                set -- $fullqualified   # re-evaluate positional params
                echo ${1#*.*}           # operate on $1
                return 0
        fi
        $(nslookup $1  >/dev/null 2>&1)
        if [ $? -eq 0 ]
        then
                fullqualified=$(nslookup $1  | grep -i name)
                set -- $fullqualified   # re-evaluate positional params
                echo ${2#*.*}         # operate on $1
                return 0
        fi
        echo "unknown domain"
        return 1
}

# append the given tokens to the given variable name
#
# param $1 is the name of the variable to append the tokens to
# param $2 is the variable containing the tokens to append
# param $3 is the separator, eg. " -a " or " -o "
appendTokens()
{
	local locOutname=${1};
	local locPreOutname="echo $"${locOutname};
	local locOutput=`eval $locPreOutname`;
	local locTokens=${2};
	local locSep="${3}";
	if [ $cfg_dbg -eq 1 ]; then echo 'current token separator is ['$locSep']'; fi
	for cfgtok in $locTokens; do
		if [ $cfg_dbg -eq 1 ]; then echo 'current token is ['$cfgtok']'; fi
		locOutput=$locOutput${locSep}$cfgtok;
	done;
	if [ $cfg_dbg -eq 1 ]; then echo 'appended Output is ['$locOutput']'; fi
	export ${locOutname}="${locOutput}";
}
# generate gnu debugger command file which may be used for batch 
# invocations of the debugger.
#
# param $1 is the name of the generated file 
# param $2 arguments passed to the debugged progam, do not forget to quote them!
# param $3 run executable within script or not, default 1, set to 0 to execute it manually
#
generateGdbCommandFile()
{
	local outputfile=${1};
	local locsrvopts=${2};
	local locRunAsServer=${3:-1};
	# <<-EOF ignore tabs, nice for formatting heredocs
cat > ${outputfile} <<-EOF
	handle SIGSTOP nostop nopass
	handle SIGLWP  nostop pass
	handle SIGTERM nostop pass
	handle SIGINT  nostop pass
	set environment PATH=${PATH}
	set environment WD_ROOT=${WD_ROOT}
	set environment WD_PATH=${WD_PATH}
	set environment LD_LIBRARY_PATH=${LD_LIBRARY_PATH}
	set environment WD_LIBDIR=${WD_LIBDIR}
	set environment LOGDIR=${LOGDIR}
	set environment PID_FILE=${PID_FILE}
	set auto-solib-add 1
	file ${WDS_BIN}
	set args ${locsrvopts}
EOF
	if [ $locRunAsServer -eq 1 ]; then
cat >> ${outputfile} <<-EOF
	run
	where
	continue
	shell rm ${outputfile}
	quit
EOF
	fi;
}

# dereference a file/path - usually a link - and find its real origin
#
# param $1 is the file/path to dereference
# param $2 the name of the variable to put the dereferenced file/path into
#
# output exporting dereferenced file/path into given name ($2)
deref_links()
{
	loc_name=${1};
	ret_var=${2};
	test ! -d $loc_name;
	is_dir=$?
	cur_path=`dirname ${loc_name}`
	while [ -h $loc_name -a `ls -l $loc_name 2>/dev/null | grep -c "^l" ` -eq 1 ]; do
		if [ $cfg_dbg -eq 1 ]; then printf $loc_name; fi
		loc_name=`ls -l $loc_name | grep "^l" | cut -d'>' -f2 -s | sed 's/^ *//'`;
		if [ $is_dir -eq 1 ]; then
			loc_name=${cur_path}/${loc_name}
		fi
		if [ $cfg_dbg -eq 1 ]; then echo ' was linked to ['$loc_name']'; fi
		cur_path=`dirname ${loc_name}`
	done
	eval ${ret_var}="$loc_name";
}

# check if a given process id still appears in process list
# note on WIN32(cygwin): it is assumed that a WDS_BIN is looked up in the process list
#
# param $1 is the process id to check for
#
# returning 1 if process still exists, 0 if the process is not listed anymore
checkProcessId()
{
	loc_pid=${1};
	loc_ret=1;
	if [ -n "$loc_pid" ]; then
		# check if pid still exists
		if [ $isWindows -eq 1 ]; then
			# use -q to suppress output and exit with 0 when matched
			ps -ef | grep -q "${loc_pid}.*${locWDS_BIN}"
		else
			ps -p ${loc_pid} > /dev/null
		fi
		if [ $? -ne 0 ]; then
			if [ $cfg_dbg -eq 1 ]; then echo 'process with pid:'${loc_pid}' has gone!'; fi
			loc_ret=0;
		fi;
	else
		loc_ret=0;
	fi
	return $loc_ret;
}

SYSFUNCSLOADED=${SYSFUNCSLOADED:-0};

if [ ${SYSFUNCSLOADED} -eq 0 ]; then
	# try to find out on which OS we are currently running, eg. SunOS, Linux or Windows
	CURSYSTEM=`(uname -s) 2>/dev/null` || CURSYSTEM="unknown"

	if [ "${CURSYSTEM}" = "Windows" -o "${CURSYSTEM%%-*}" = "CYGWIN_NT" ]; then
		CURSYSTEM="Windows"
		isWindows=1;
		OSREL=Win_i386
		USR_TMP=${HOME}/tmp;
		SYS_TMP=${TEMP:-${TMP:-$USR_TMP}};
	else
		isWindows=0;
		if [ "${CURSYSTEM}" == "Linux" ]; then
			getGLIBCVersion "GLIBCVER" ".";
			OSREL=${CURSYSTEM}_glibc_${GLIBCVER};
		else
			OSREL=${CURSYSTEM}_`uname -r`;
		fi;
		USR_TMP=${HOME}/tmp;
		SYS_TMP=/tmp;
	fi

	export CURSYSTEM isWindows OSREL USR_TMP SYS_TMP;

	# OSTYPE is needed for compilation using makefiles, ensure it is set
	if [ -z "${OSTYPE}" ]; then
		# use bash to get ostype, only bash defines it...
		if [ -x "/bin/bash" ]; then
			export OSTYPE="`bash -c 'echo $OSTYPE'`";
		fi
	fi

	# it seems that some shells do not set the USER variable but the variable LOGNAME
	if [ -z "${USER}" ]; then
		echo 'setting USER variable to ['$LOGNAME']'
		export USER=${LOGNAME}
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
	export APP_SUFFIX LIB_SUFFIX SHAREDLIB_SUFFIX

	testSetGnuTool FINDEXE IS_GNUFIND gfind find

	if [ $IS_GNUFIND -eq 1 ]; then
		FINDOPT="-maxdepth 1 -printf %f"
		FINDOPT1="-maxdepth 1 -printf %f\n"
	else
		FINDOPT="-prune -print"
		FINDOPT1="-prune -print"
	fi

	export FINDOPT FINDOPT1

	testSetGnuTool DIFFEXE IS_GNUDIFF gdiff diff
	testSetGnuTool AWKEXE IS_GNUAWK gawk awk

fi
SYSFUNCSLOADED=1
