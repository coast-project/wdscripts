clear

MYNAME=`basename $0`

function showhelp
{
	echo ''
	echo 'usage: '$MYNAME' [options]'
	echo 'where options are:'
	echo ' -f : set frontdoor specific variables too'
	echo ' -c : clear variables before setting new values'
	echo ''
	exit 4;
}

dofull=0;
OPTIND=
OPTARG=

# process command line options
while getopts ":fc" opt; do
	case $opt in
		f)
			dofull=1;
		;;
		c)
			unset WD_OUTDIR WD_PATH WD_LIBDIR WD_ROOT LD_LIBRARY_PATH;
		;;
		\?)
			showhelp;
		;;
	esac
done
shift $(($OPTIND - 1))

# load common os wrapper funcs
. /home/scripts/sysfuncs.sh

setDevelopmentEnv
if [ $? -eq 0 ]; then
	echo "something went wrong setting Dev-Env, aborting...";
	exit 3;
fi

if [ $dofull -eq 1 ]; then
	echo "now setting frontdoor specific variables..."
	echo ""
	export WWW_DIR=$DEV_HOME/WWW
	export WD_DIR=$WWW_DIR/webdisplay2
	export IDP_DIR=$WWW_DIR/idp2
	export PDNE_DIR=$WWW_DIR/pdne
	export HTTPD_DIR=$WWW_DIR/httpd
	export TESTFW_DIR=$DEV_HOME/testfw
	export FULL_BUILD_HOME=/home/chw/DEVTEST

	export WD_ROOT=$WWW_DIR/fds
	export WD_PATH_PRV=fds_config
	export WD_PATH=$WD_PATH_PRV
	export WD_PATH=$WD_PATH:$WD_PATH_PRV/pages
	export WD_PATH=$WD_PATH:$WD_PATH_PRV/config_userdata
	export WD_PATH=$WD_PATH:$WD_PATH_PRV/environment
	export WD_PATH=$WD_PATH:$WD_PATH_PRV/config_parts
	export WD_PATH=$WD_PATH:$WD_PATH_PRV/config_ssl
	export WD_PATH=$WD_PATH:$WD_PATH_PRV/config_routing
	export WD_PATH=$WD_PATH:$WD_PATH_PRV/HTMLTemplates
	export WD_PATH=$WD_PATH:$WD_PATH_PRV/admin
	export WD_PATH=$WD_PATH:$WD_PATH_PRV:fds_accTest

	alias cde='cd $WD_ROOT'
	alias cdd='cd $DEV_HOME'
	alias cdw='cd $WWW_DIR'
fi
