# functions and preparations to encapsulate os specific items

# try to find out on which OS we are currently running, eg. SunOS, Linux or Windows
CURSYSTEM=`(uname -s) 2>/dev/null` || CURSYSTEM="unknown"

if [ "${CURSYSTEM}" = "Windows" -o "${CURSYSTEM}" = "CYGWIN_NT-5.0" ]; then
	export CURSYSTEM="Windows"
	export isWindows=1;
	export OSREL=Win_i386
	export USR_TMP=${HOME}/tmp;
	export SYS_TMP=${TEMP:-${TMP:-$USR_TMP}};
else
	export isWindows=0;
	export OSREL=${CURSYSTEM}_`uname -r`
	export USR_TMP=${HOME}/tmp;
	export SYS_TMP=/tmp;
fi

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
EXEEXT=""
DLLEXT=".so"
if [ ${isWindows} -eq 1 ]; then
	EXEEXT=".exe"
	DLLEXT=".dll"
fi

# Test the find version (GNU/std) because of different options
find --version 2>/dev/null 1>/dev/null
if [ $? -eq 0 ]; then
	FINDOPT="-maxdepth 1 -printf %f"
	FINDOPT1="-maxdepth 1 -printf %f\n"
else
#	echo "using std-find";
	FINDOPT="-prune -print"
	FINDOPT1="-prune -print"
fi

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
function getDosDir
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

# search for a joined directory name beginning from given directory
# the search is only done in the given directory, no recursion
#
# param $1 is the name of the output variable
# param $2 is the path where we search
# param $3 is the name of the beginning segment
# param $4 is the name of the ending segment
#
# returning 1 if it the path was found, 0 otherwise
#
# example:
# want to have a dirname in variable FOOBAR like TestPrj_config
# SearchJoinedDir "FOOBAR" "." "TestPrj" "config"
# the result can be either TestPrj_config if found or just config
#
function SearchJoinedDir
{
	local varname=${1};
	local testpath=${2};
	local firstseg=${3};
	local lastseg=${4};
	local tmppath="";
	# directory name of the log directory, may be overwritten in the project specific config.sh
	# for cases where this find does not point to the correct location
	tmppath=`cd $testpath && find . -name "${firstseg}*${lastseg}*" -follow -type d ${FINDOPT}`;

	# check if we have a logdir yet
	if [ -z "$tmppath" ]; then
		# appropriate log directory not yet found
		for dname in `cd $testpath && find . -name "*${lastseg}*" -follow -type d ${FINDOPT1}`; do
			# take the first we find
			tmppath="${dname}";
			break;
		done
	fi
	# strip trailing slash
	tmppath="${tmppath##*/}";
	if [ -z "${tmppath}" ]; then
		return 0;
	else
		export ${varname}="${tmppath}"
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
function existInPath
{
	local path=${1};
	local segsep=${2};
	local tstseg=${3};
	local ptmp="";
	local seg="";
	while seg=${path%%${segsep}*}; [ -n "$path" ]; do
#		echo "current segment ["$seg"]"
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
#		echo "currpath ["$path"]"
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
function appendPath
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
	#		echo "new path ["${path}"]";
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
function prependPath
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
	#		echo "new path ["${path}"]";
			export ${pathname}="$path";
		fi
	fi
}

# clean the given path, eg. test for single existance of a path segment
#
# param $1 is the name of the 'path'-variable 
# param $2 is the path-segment separator
#
# output exporting new path into given name ($1)
function cleanPath
{
	local pathname=${1};
	local _path="echo $"${pathname};
	local segsep=${2};
	local path=`eval $_path`;
	local ptmp="";
	local seg="";
	while seg=${path%%${segsep}*}; [ -n "$path" ]; do
#		echo "current segment ["$seg"]"
		appendPath "_PATH" ":" "$seg"
		ptmp=${path#*${segsep}};
		# the previous command fails if the very last character is not a segment-separator
		# i have to check for this with comparing the last path we had with the new one
		if [ "${ptmp}" = "${path}" ]; then
			ptmp="";
		fi
		path=${ptmp};
	done
#	echo "cleaned path ["${_PATH}"]"
	export ${pathname}="${_PATH}";
	unset _PATH;
}

# display a selection list of current Develop-directories
# - directories must start with DEV to be displayed in the list
# - directories must either be real dirs or links in the HOME-directory
#
# param $1 is name of the output variable for selected path
# param $2 is name of the output variable for last path-segment
#
# output setting variable $1 to value of selected path
# output setting variable $2 to value of last path-segment
function selectDevelopDir
{
	echo ""
	echo "Where Do you want to develop today?"
	echo ""
	select myenv in `cd && find -path "./DEV*" ${FINDOPT1}`
	do
		# use pwd -P to follow links and get 'real' directory
		# especially needed for windows! but shouldn't matter for Unix
		local devpath=`cd && cd $myenv && pwd -P`;
		if [ $isWindows -eq 1 ]; then
			getDosDir "$devpath" "${1}";
		else
			export ${1}="$devpath";
		fi;
		# trim path until last segment
		export ${2}="${myenv##*/}";
		break
	done
}

# set-up variables for a selectable development environment
# - display a selection list of current Develop-directories
# - set WD_OUTDIR and WD_LIBDIR
# - adjust PATH and LD_LIBRARY_PATH
#
# return 1 if successful, 0 otherwise
function setDevelopmentEnv
{
	selectDevelopDir "DEV_HOME" "DEVNAME"
	if [ -n "${DEV_HOME}" -a -n "${DEVNAME}" ]; then
		if [ -z "${WD_OUTDIR}" ]; then
			WD_OUTDIR=${SYS_TMP}/objectfiles;
		fi
		WD_OUTDIR=${WD_OUTDIR}/${USER}/${DEVNAME};
		if [ "$USER" = "whoever" -o "$USER" = "whoeverToo" ]; then
			WD_LIBDIR=${DEV_HOME}/lib
		else
			if [ -z "${WD_LIBDIR}" ]; then
				WD_LIBDIR=${WD_OUTDIR}/lib
#				WD_LIBDIR=${WD_OUTDIR}/${OSREL}/lib
			fi
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
		if [ ! -z "${LDAP_DIR}" -a -d "${LDAP_DIR}/lib" ]; then
			appendPath "LD_LIBRARY_PATH" ":" "${LDAP_DIR}/lib"
		fi
	fi

cat <<EOT

following variables were set:

DEV_HOME          : [${DEV_HOME}]
WD_OUTDIR         : [${WD_OUTDIR}]
WD_LIBDIR         : [${WD_LIBDIR}]
PATH              : [${PATH}]
EOT
	if [ $isWindows -eq 0 ]; then
		echo "LD_LIBRARY_PATH   : ["${LD_LIBRARY_PATH}"]"
	fi
	echo ""
	return 1;
}
