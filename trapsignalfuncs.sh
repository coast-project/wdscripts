#!/bin/sh
#-----------------------------------------------------------------------------------------------------
# Copyright (c) 2006, Peter Sommerlad and IFS Institute for Software at HSR Rapperswil, Switzerland
# All rights reserved.
#
# This library/application is free software; you can redistribute and/or modify it under the terms of
# the license that is included with this library/application in the file license.txt.
#-----------------------------------------------------------------------------------------------------
#
# trap common signals and redirect to exitproc function which must be defined in outer script
#

# unset all functions to remove potential definitions
# generated using $> cat trapsignalfuncs.sh | sed -n 's/^\([a-zA-Z][^(]*\)(.*$/unset -f \1/p'
unset -f exitprocINT
unset -f exitprocHUP
unset -f exitprocTERM
unset -f exitproc

exitprocINT()
{
	exitproc "INT"
}
exitprocHUP()
{
	exitproc "HUP"
}
exitprocTERM()
{
	exitproc "TERM"
}

# default func
exitproc()
{
	locSigName=${1:-4};
	printf "%s %s: got SIG%s but exitproc not overridden!" "$(date +%Y%m%d%H%M%S)" "${MYNAME}" "${locSigName}"
	exit 0;
}

trap exitprocINT INT
trap exitprocHUP HUP
trap exitprocTERM TERM
