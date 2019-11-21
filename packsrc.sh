#!/bin/sh
#-----------------------------------------------------------------------------------------------------
# Copyright (c) 2005, Peter Sommerlad and IFS Institute for Software at HSR Rapperswil, Switzerland
# All rights reserved.
#
# This library/application is free software; you can redistribute and/or modify it under the terms of
# the license that is included with this library/application in the file license.txt.
#-----------------------------------------------------------------------------------------------------

script_name=$(basename "$0")

mypath=$(dirname "$0")
test "/" = "$(echo "${mypath}" | cut -c1)" || mypath="$(cd "${mypath}" 2>/dev/null && pwd)"

showhelp()
{
	echo ""
	echo "usage: $script_name [options] <directories...>"
	echo "where options are:"
	echo " -c <zip|tar|tgz|tbz> : compression method, one of:"
	echo "    zip : use zip compressor"
	echo "    tgz : use tar archiver and gzip compressor"
	echo "    tar : use tar archiver and no compressor"
	echo "    tbz : use tar archiver and bzip2 compressor, default"
	echo " -m <0|1|2> : mode for sorting files before adding, one of:"
	echo "    0 : files sorted by directory and extension"
	echo "    1 : files sorted by extension"
	echo "    2 : files sorted by extension, default, the filename will be taken as extension for files without extension"
	echo " -n <archivename> : specify another archive name, default is first directory name"
	echo " -f <filename> : use only files newer than given file"
	echo " -t [[CC]YY]MMDDhhmm[.ss] : use only files newer than timestamp given"
	echo " -x <files...> : additional files to be excluded from packing"
	echo " -X <dir...> : additional directories to be excluded from packing"
	echo " -D : print debugging information of scripts, sets PRINT_DBG variable to 1"
	echo ""
	exit 4;
}

fileexcl=""
pathexcl=""
newerfile="";
newertime="";
# default compressor settings
cmprs='tar cf - -v -T ${locPackFiles} | bzip2 --repetitive-best > $outfile'
cmprsext=.tar.bz2
PRINT_DBG=0;

# process command line options
while getopts ":c:f:m:n:t:x:X:D" opt; do
	case $opt in
		c)
			# set compressor
			if [ "${OPTARG}" = "zip" ]; then
				cmprs='cat ${locPackFiles} | zip $outfile -@'
				cmprsext=.zip
			elif [ "${OPTARG}" = "tgz" ]; then
				cmprs='tar cf - -v -T ${locPackFiles} | gzip > $outfile'
				cmprsext=.tgz
			elif [ "${OPTARG}" = "tar" ]; then
				cmprs='tar cf $outfile -v -T ${locPackFiles}'
				cmprsext=.tar
			fi
		;;
		f)
			newerfile="${OPTARG}";
		;;
		m)
			_mode="${OPTARG}";
		;;
		n)
			prjname="${OPTARG}";
		;;
		t)
			newertime="${OPTARG}";
		;;
		x)
			fileexcl="${fileexcl} -o -name ${OPTARG}";
		;;
		X)
			pathexcl="${pathexcl} -o -path '${OPTARG}'";
		;;
		D)
			PRINT_DBG=1;
		;;
		\?)
			showhelp;
		;;
	esac
done
shift $((OPTIND - 1))

dopath="$@"
# if no project name is given take the first argument as name
if [ -z "$prjname" ]; then
	prjname=$1
fi

# set defaults if nothing specified
if [ -z "$prjname" -o "$prjname" = "." ]; then
	prjname=$(pwd)
	prjname=${prjname##*/}
fi

if [ -z "$dopath" ]; then
	dopath="."
fi

if [ -z "$_mode" ]; then
	_mode=2
	export _mode
fi

if [ "${PRINT_DBG:-0}" -ge 1 ]; then
	echo "directories:  [$dopath]"
	echo "mode:         [$_mode]"
	echo "prjname:      [$prjname]"
	echo "file excludes:[$fileexcl]"
	echo "path excludes:[$pathexcl]"
	echo "compressor    [$cmprs]"
	echo "extension     [$cmprsext]"
	echo "newerfile     [$newerfile]"
	echo "newertime     [$newertime]"
fi

# load os-specific settings and functions
# shellcheck source=./sysfuncs.sh
. "$mypath"/sysfuncs.sh

IS_GNUFIND=0; IS_GNUAWK=0;
FINDEXE="$(getFirstValidTool "/usr/local/bin:/usr/bin:/bin" gfind find)"
hasVersionReturn "$FINDEXE" >/dev/null && IS_GNUFIND=1;
AWKEXE="$(getFirstValidTool "/usr/local/bin:/usr/bin:/bin" gawk awk)"
hasVersionReturn "$AWKEXE" >/dev/null && IS_GNUAWK=1;

if [ $IS_GNUAWK -eq 0 ] || [ $IS_GNUFIND -eq 0 ]; then
	echo ""
	echo "ERROR:"
	echo " could not locate gawk and/or gfind executable!"
	echo ""
	exit 4;
fi

locInfoFileName=_inf_foo_.txt
locInfoFile=${SYS_TMP}/${locInfoFileName}
locTmpFile1=${SYS_TMP}/__.txt
locTmpFile2=${SYS_TMP}/_.txt
locPackFiles=${SYS_TMP}/_f_.txt
locModusFile=${SYS_TMP}/awkmodus.foo
locExtFile=${SYS_TMP}/awkextsort.foo
locFilterFileName=awkfilterlibs.foo
locFilterFile=${SYS_TMP}/${locFilterFileName}
locNewerFile=${SYS_TMP}/_newerfile_

cleanup()
{
	rm ${locInfoFile} ${locTmpFile2} ${locTmpFile1} ${locPackFiles} ${locModusFile} ${locExtFile} ${locFilterFile} ${locNewerFile} >/dev/null 2>&1
}

# install signal handlers
# shellcheck source=./trapsignalfuncs.sh
. "$mypath"/trapsignalfuncs.sh

exitproc()
{
	cleanup;
	exit 4;
}

# lets start
cleanup
awkpar="-v mode=$_mode"
outfile=${prjname}_$(date +%Y%m%d%H%M)${cmprsext}

if [ -n "${newertime}" ]; then
	touch -t "${newertime}" "${locNewerFile}"
	if [ -f "${locNewerFile}" ]; then
		newerparam="-newer ${locNewerFile} "
	fi
elif [ -n "${newerfile}" ]; then
	if [ -f "${newerfile}" ]; then
		newerparam="-newer ${newerfile} "
	fi
fi

echo ""
echo "Using Mode [$_mode] to pack contents of [$dopath] into [$outfile]"
echo ""

cat << EOF > ${locFilterFile}
BEGIN{
  RS="\r?\n";
}
{
	ns=split(\$0,SPATH,"[\\\/]");
	if (ns > 1 && SPATH[ns-1] != ".")
	{
		fname=tolower(SPATH[ns]);
		libstr="lib" tolower(SPATH[ns-1]);
		# only print files which are not libs
		if (!match(fname,libstr))
			print \$0;
	} else {
		print \$0;
	}
}
EOF

${FINDEXE} "$dopath" "(" -path '*/i386_*' -o -path '*/.sniffdir' -o -path '*/.ProjectCache' -o -path '*/.RetrieverIndex' -o -path '*/.sniffdb' -o -path '*/sol_gcc_*' -o -path '*/CVS' $pathexcl ")" -prune -o ! "(" -name "*%" -o -name ".Sniff*" -o -name ".#*" -o -name "*.o"  -o -name "*.so" -o -name "*.pdb" -o -name "*.exp" -o -name "wdtest" -o -name "wdtest.exe" -o -name "*.opt" -o -name "*.plg" -o -name "*.ncb" -o -name "*.aps" -o -name "*.log.*" -o -name "*.bak*" -o -name "${locInfoFileName}" -o -name "${locFilterFileName}" -o -name '_teststderr.tx_' -o -name '_teststdout.tx_' -o -name '*.org[0-9]*' -o -name '*.rpl[0-9]*' ${fileexcl} ")" "${newerparam}" -type f -print | ${AWKEXE} -f ${locFilterFile} > ${locInfoFile}

cat << EOF > ${locModusFile}
BEGIN{
  RS="\r?\n";
  first = 1;
}
{
  nline = \$0;
  oline="";
  if (mode == 1)
  { # files nach extension sortiert egal aus welchem Verzeichnis
    if (match(nline,".*\\\\."))
    {
      oline = oline substr(nline,RLENGTH+1)"\t";
      nline = substr(nline,RSTART,RLENGTH);
    }
    else
      oline = "\t";

    if (match(nline,".*/"))
    {
      oline = oline substr(nline,RLENGTH+1)"\t";
      nline = substr(nline,RSTART,RLENGTH);
    }
    else
      oline = oline "\t";

    print oline nline > "${locTmpFile2}";
  }
  else if (mode == 2)
  { # files nach extension sortiert, wenn keine extension 'entspricht' der Name der extension
    #  Verzeichnis spielt keine Rolle
    if (match(nline,".*/"))
    {
      oline = "\t" substr(nline,RSTART,RLENGTH);
      nline = substr(nline,RLENGTH+1);
    }
    else
      oline = "\t";

    if (match(nline,".*\\\\."))
    {
      oline = "\t" substr(nline,RSTART,RLENGTH) oline;
      nline = substr(nline,RLENGTH+1);
    }
    else
      oline = "\t" oline;

    print nline oline > "${locTmpFile2}";
  }
  else
  { # files nach extension sortiert aber in gleicher Verzeichnisreihenfolge
    if (match(nline,".*\\\\."))
      print substr(nline,RLENGTH+1)"\t"substr(nline,RSTART,RLENGTH) > "${locTmpFile2}";
    else
      print "\t"nline > "${locTmpFile2}";
  }
}
EOF

${AWKEXE} "$awkpar" -f ${locModusFile} ${locInfoFile}
if [ ! -s ${locTmpFile2} ]; then
	cleanup;
	echo "No files found to compress, exiting..."
	exit 1;
fi

sort -f ${locTmpFile2} -o ${locTmpFile1} >/dev/null 2>&1

cat << EOF > ${locExtFile}
BEGIN { ORS="\n"; ntxt=0; nbin=0; }
{
    split(\$0,ARR,"\t");
    # ARR[1] : extension
    # ARR[2] : filename
    # ARR[3] : path
    _path = ARR[3];
    _filename = ARR[2];
    _ext = ARR[1];
    split(_ext,ARR,",");
    _lext = tolower(ARR[1]);
    if (_lext == "any" ||_lext == "asm" || _lext == "awk" || _lext == "bat" || _lext == "bcc" || _lext == "c" || _lext == "cc" || _lext == "cfg" || _lext == "cmd" || _lext == "cpp" || _lext == "css" || _lext == "cxx" || _lext == "def" || _lext == "dsp" || _lext == "dsw" || _lext == "dtd" || _lext == "exp" || _lext == "h" || _lext == "hh" || _lext == "htm" || _lext == "html" || _lext == "hx" || _lext == "ini" || _lext == "js" || _lext == "log" || _lext == "mak" || _lext == "pl" || _lext == "rc" || _lext == "rtf" || _lext == "sh" || _lext == "shared" || _lext == "smt" || _lext == "sql" || _lext == "tx" || _lext == "txt" || _lext == "x" || _lext == "xml" || _lext == "xul" || _filename == "Makefile" || _filename == "Entries" || _filename == "Repository" || _filename == "Root")
      TXTFIL[ntxt++] = _path _filename _ext;
    else
      BINFIL[nbin++] = _path _filename _ext;
}
END {
	for (i=0; i < ntxt; i++)
		print TXTFIL[i] > outname;
	for (i=0; i < nbin; i++)
		print BINFIL[i] > outname;
}
EOF

${AWKEXE} -v outname="${locPackFiles}" -f ${locExtFile} ${locTmpFile1}

eval "$cmprs"
cleanup
