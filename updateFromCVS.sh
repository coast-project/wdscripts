#!/bin/ksh
###########################################################################
# Copyright (c) 1999-2000 itopia
# All Rights Reserved
#
# $Id$
#
# update script to automatically update your DEVELOP environment
#
############################################################################

# go to the home directory
cd

# source in the users setup defining UPDATEDIRS CVSFLAGS WDCORE and WDPROJS
if [[ -a .updateDirsFromCVS ]]; then
  . .updateDirsFromCVS
fi

# defines the root directories for updating usually set as DEV_HOME
UPDATEDIRS=${UPDATEDIRS:-"DEVELOP"}:

# defines the relative path to a DEV_HOME
dir=${UPDATEDIRS%%:*}

# define CVSFLAGS for update default resets sticky tags and adds directories
CVSFLAGS=${CVSFLAGS:-"-A -d"}

# the webdisplay2 core directories
WDCORE=${WDCORE:-"WWW/webdisplay2 WWW/wdserver WWW/wdapp testfw scripts WWW/perfTest"}

# any additional project directories
WDPROJS=${WDPROJS:-""}

# output file generated
RESLOG=${RESLOG:-"update.log"}

let DOUPDATE=${1:-"0"}

if [[ DOUPDATE -eq 0 ]]; then
  date +'---- [%a %b %e %T %Z %Y] ----' > $RESLOG;
  printf "updating ${WDCORE} on ${WDPROJS} in ${UPDATEDIRS}\n" >> $RESLOG;

  while [[ -n $UPDATEDIRS ]];
  do
	if [[ -x $dir ]]; then
	  echo "updating [" $dir "]" >> $RESLOG;
	  cd $dir; 
	  cvs update $CVSFLAGS $WDCORE $WDPROJS >> $RESLOG 2>&1;
	  cd;
	fi

	UPDATEDIRS=${UPDATEDIRS#*:}
	dir=${UPDATEDIRS%%:*}
  done
  date +'---- [%a %b %e %T %Z %Y] done ----' >> $RESLOG;
fi;
