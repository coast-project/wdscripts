# file: envForTests.sh
# Set environment for (daily) builds - ksh mode

# load global configuration
. `dirname $0`/config.sh $1

# system independant project to build
DO_CHECKOUT="WDCore WWW/helloworld WWW/loggingProxy"
DO_PROJECTS="WWW/webdisplay2/wdtest WWW/helloworld WWW/loggingProxy"
 
# be somewhat of nice and define host specific settings
#################
case "${CURSYSTEM}" in
	SunOS)
		export DATE_EXEC=/usr/bin/date
		export MAIL_PRG=/usr/ucb/mail
		export GREP_PRG=/usr/bin/grep

		export SENDER_EMAIL="-r dailybuild@itopia.ch"

		if [ "${USER}" = "wdtester" ]; then
			export WE_PATTERN="Solaris.*shared-dbg"
		fi

		if [ -z "${SSL_DIR}" ]; then
			export SSL_DIR=/usr/local/ssl
		fi
		if [ -z "${LDAP_DIR}" ]; then
			export LDAP_DIR=/home/ldap/ldap41
		fi
		DO_CHECKOUT=${DO_CHECKOUT}" WWW/fds WWW/ftpFrontdoor"
		DO_PROJECTS=${DO_PROJECTS}" WWW/fds WWW/ftpFrontdoor"
	;;
	Linux)
		export DATE_EXEC=date
		export MAIL_PRG=mail
		export GREP_PRG=grep

		export SENDER_EMAIL=""

		if [ "${USER}" = "wdtester" ]; then
			export WE_PATTERN="Linux.*shared-opt"
		fi

		if [ -z "${SSL_DIR}" ]; then
			export SSL_DIR=/usr
		fi
		if [ -z "${LDAP_DIR}" ]; then
			export LDAP_DIR=/usr/local/ldap41
		fi
		# WWW/webdisplay2 is the wrapper project to generate the documentation
		DO_CHECKOUT=${DO_CHECKOUT}" WWW/eSportFoundation"
		DO_PROJECTS=${DO_PROJECTS}" WWW/eSportFoundation WWW/webdisplay2"
	;;
esac

export DO_CHECKOUT DO_PROJECTS

if [ -z "${CVSROOT}" ]; then
	export CVSROOT=/home/cvs       # useful for cvs
fi
export CVSREAD=1
if [ -z "${SNIFF_DIR}" ]; then
	export SNIFF_DIR=/home/sniff+
fi
export SNIFF_ITOPIA_TEMPLATES=${SNIFF_DIR}/itopiaTemplates

# only define the time stamp the first time this script gets called
if [ -z "${TIME_STAMP}" ]; then
	export TIME_STAMP=`${DATE_EXEC} +%Y%m%d%H%M`
fi

if [ "${USER}" = "wdtester" ]; then
	export BUILD_OUTPUT_DIR=/home/wdtester/DailyBuildOutput
	export LOCK_FILE=${SCRIPTDIR}/Build.${HOSTNAME}.lock
else
	export BUILD_OUTPUT_DIR=${DEV_HOME}/DailyBuildOutput
	export LOCK_FILE=${DEV_HOME}/Build.${HOSTNAME}.lock
fi
# test if logfile directory already exists
if [ ! -d "${BUILD_OUTPUT_DIR}" ]; then
	mkdir -p ${BUILD_OUTPUT_DIR};
fi

export LOGFILENAME=wdtestmake.${HOSTNAME}
export FAILUREFILENAME=TodaysFailures.${HOSTNAME}
export RESULTFILENAME=DailyBuildResult.${HOSTNAME}
export LOGFILE=${LOGFILE:-${BUILD_OUTPUT_DIR}/${LOGFILENAME}.${TIME_STAMP}}
export FAILURE_FILE=${BUILD_OUTPUT_DIR}/${FAILUREFILENAME}.${TIME_STAMP}
export RESULTFILE=${BUILD_OUTPUT_DIR}/${RESULTFILENAME}.${TIME_STAMP}
export ATRAXISLOGFILE=${LOGFILE:-${BUILD_OUTPUT_DIR}/wdtestmake.Atraxis.${HOSTNAME}.${TIME_STAMP}}

export WDTEST_ERRFILE=${BUILD_OUTPUT_DIR}/wdtests.${HOSTNAME}.${TIME_STAMP}.cerr
export WDTEST_OUTFILE=${BUILD_OUTPUT_DIR}/wdtests.${HOSTNAME}.${TIME_STAMP}.cout

prependPath "LD_LIBRARY_PATH" ":" "${LDAP_DIR}/lib"
prependPath "LD_LIBRARY_PATH" ":" "${WD_LIBDIR}"
