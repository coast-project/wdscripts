#-----------------------------------------------------------------------------------------------------
# Copyright (c) 2005, Peter Sommerlad and IFS Institute for Software at HSR Rapperswil, Switzerland
# All rights reserved.
#
# This library/application is free software; you can redistribute and/or modify it under the terms of
# the license that is included with this library/application in the file license.txt.
#-----------------------------------------------------------------------------------------------------
#
# project specific variables and directories, loaded from within config.sh
#

############################################################################
#
# In this ection you should only adjust but NOT remove any of the given variables
# because these are used from within other scripts
#

# overwrite this one ONLY if the LOGDIR variable points to the wrong place
#LOGDIR=log

SERVERNAME="wdscripts"
PRJ_DESCRIPTION="Coast scripts"
#PID_FILE=$PROJECTDIR/$LOGDIR/$SERVERNAME.PID

# RUN_USER variable will be used by bootScript.sh to start the server as a different user at boot time or later
# -> this setting is needed to control the server (start|stop|restart...) by a user different than root
#RUN_USER=notRootUser

# RUN_ATTACHED_TO_GDB variable will be used by startwds.sh to start the server under gdb control
# if you want to use either keepwds.sh or bootScript.sh to start the server, this flag should be set here
# -> this is useful to get out more information in case the server terminates unexpectedly
#RUN_ATTACHED_TO_GDB=1

# the following section can be used to control server start/stop behavior using s special file which contains these flags
# if the RUN_SERVICE flag is left off or set to 1, the server will always be controllable using any of the bootScript.sh, startwd[as].sh, startprf.sh or stopwds.sh scripts
# if RUN_SERVICE is set to 0, the server will not be started/stopped except the -F option is given to override the variable
#RUN_SERVICE_CFGFILE=${DEV_HOME}/my_services.sh
#RUN_SERVICE=`/bin/sh -c ". ${RUN_SERVICE_CFGFILE} >/dev/null 2>&1; eval \"echo $\"RUN_SERVICE_${SERVERNAME}"`

# overwrite this one ONLY if the COAST_PATH variable points to the wrong place
#COAST_PATH=config

# The flag COAST_USE_MMAP_STREAMS controls the usage of memory mapped files. Default is to use mmap streams
#  because for most operations and conditions this seems to be fast.
# When setting this variable to 0, fstreams will be used instead
# note: Memory mapped files will always increase the file size by an internally managed blocksize,
#  on SunOS_5.8, this blocksize seems to be 8192 bytes. If you intend to use a tail -f on these files
#  you will probably not get what you expect. tail can not handle the reserved - and still unused - space.
#export COAST_USE_MMAP_STREAMS=0

# The flag TRACE_STORAGE defines the logging level of memory statistics
#  0: No pool statistic tracing, except when excess memory was used
#  1: Trace overall statistics
#  2: Trace detailed statistics
#  3: Trace unfreed blocks
#export TRACE_STORAGE=0
