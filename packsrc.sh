#!/bin/bash

MYNAME=`basename $0`

function showhelp
{
	echo ''
	echo 'usage: '$MYNAME' [options] <directories...>'
	echo 'where options are:'
	echo ' -c <zip|tar|tgz|tbz> : compression method, one of:'
	echo '    zip : use zip compressor'
	echo '    tgz : use tar archiver and gzip compressor'
	echo '    tar : use tar archiver and no compressor'
	echo '    tbz : use tar archiver and bzip2 compressor, default'
	echo ' -m <0|1|2> : mode for sorting files before adding, one of:'
	echo '    0 : files sorted by directory and extension'
	echo '    1 : files sorted by extension'
	echo '    2 : files sorted by extension, the filename will be taken as extension for files without extension'
	echo ' -n <archivename> : specify another archive name, default is first directory name'
	echo ' -x <files...> : additional files to be excluded from packing'
	echo ' -X <dir...> : additional directories to be excluded from packing'
	echo ' -D : print debugging information of scripts, sets PRINT_DBG variable to 1'
	echo ''
	exit 4;
}

fileexcl=""
pathexcl=""
packfiles=_f_.txt
# default compressor settings
cmprs='tar cf - -v -T $packfiles | bzip2 --repetitive-best > $outfile'
cmprsext=.tar.bz2

# process command line options
while getopts ":c:m:n:x:X:D" opt; do
	case $opt in
		c)
			# set compressor
			if [ "${OPTARG}" = "zip" ]; then
				cmprs='cat $packfiles | zip $outfile -@'
				cmprsext=.zip
			elif [ "${OPTARG}" = "tgz" ]; then
				cmprs='tar cf - -v -T $packfiles | gzip > $outfile'
				cmprsext=.tgz
			elif [ "${OPTARG}" = "tar" ]; then
				cmprs='tar cf $outfile -v -T $packfiles'
				cmprsext=.tar
			fi
		;;
		m)
			_mode="${OPTARG}";
#			echo 'mode is ['$_mode']'
		;;
		n)
			prjname="${OPTARG}";
#			echo 'new project name is ['$prjname']'
		;;
		x)
			fileexcl=${fileexcl}" -o -name '"${OPTARG}"'";
#			echo 'file exclusion is ['$fileexcl']'
		;;
		X)
			pathexcl=${pathexcl}" -o -path '"${OPTARG}"'";
#			echo 'path exclusion is ['$pathexcl']'
		;;
		D)
			# propagating this option to config.sh
			cfg_opt="-D";
		;;
		\?)
			showhelp;
		;;
	esac
done
shift $(($OPTIND - 1))

dopath="$*"
# if no project name is given take the first argument as name
if [ -z "$prjname" ]; then
	prjname=$1
fi

# set defaults if nothing specified
if [ -z "$prjname" -o "$prjname" = "." ]; then
	prjname=`pwd`
	prjname=${prjname##*/}
fi

if [ -z "$dopath" ]; then
	dopath="."
fi

if [ -z "$_mode" ]; then
	export _mode=2
fi

if [ "$cfg_opt" = "-D" ]; then
	echo "directories:  ["$dopath"]"
	echo "mode:         ["$_mode"]"
	echo "prjname:      ["$prjname"]"
	echo "file excludes:["$fileexcl"]"
	echo "path excludes:["$pathexcl"]"
	echo "compressor    ["$cmprs"]"
	echo "extension     ["$cmprsext"]"
fi

# lets start
awkpar="-v mode=$_mode"
outfile=${prjname}_`date +%Y%m%d%H%M`${cmprsext}

echo ""
echo "Using Mode ["$_mode"] to pack contents of ["$dopath"] into ["$outfile"]"
echo ""

if [ -f _inf_foo_.txt ]; then
	rm -f _inf_foo_.txt >nul
fi

cat << EOF > awkfilterlibs.foo
BEGIN{
  RS="\r?\n";
}
{
	ns=split(\$0,SPATH,"[/\\]");
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

find $dopath "(" -path '*/i386_*' -o -path '*/.sniffdir' -o -path '*/.ProjectCache' -o -path '*/.RetrieverIndex' -o -path '*/.sniffdb' -o -path '*/sol_gcc_*' -o -path '*/CVS' $pathexcl ")" -prune -o ! "(" -name "*%" -o -name ".Sniff*" -o -name ".#*" -o -name "*.o"  -o -name "*.so" -o -name "*.pdb" -o -name "*.exp" -o -name "wdtest" -o -name "wdtest.exe" -o -name "*.opt" -o -name "*.plg" -o -name "*.ncb" -o -name "*.aps" -o -name "*.log.*" -o -name "*.bak*" -o -name "_inf_foo_.txt" -o -name "awkfilterlibs.foo" -o -name '_teststderr.tx_' -o -name '_teststdout.tx_' -o -name '*.org[0-9]*' -o -name '*.rpl[0-9]*' $fileexcl ")" -type f -print | awk -f awkfilterlibs.foo > _inf_foo_.txt

cat << EOF > awkmodus.foo
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

    print oline nline > "_.txt";
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

    print nline oline > "_.txt";
  }
  else
  { # files nach extension sortiert aber in gleicher Verzeichnisreihenfolge
    if (match(nline,".*\\\\."))
      print substr(nline,RLENGTH+1)"\t"substr(nline,RSTART,RLENGTH) > "_.txt";
    else
      print "\t"nline > "_.txt";
  }
}
EOF

awk $awkpar -f awkmodus.foo _inf_foo_.txt
sort -f _.txt -o __.txt

cat << EOF > awkextsort.foo
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

awk -v outname="$packfiles" -f awkextsort.foo __.txt

eval $cmprs

rm _inf_foo_.txt
rm _.txt
rm __.txt
rm $packfiles
rm awkmodus.foo
rm awkextsort.foo
rm awkfilterlibs.foo
