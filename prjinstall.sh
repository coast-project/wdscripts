#-----------------------------------------------------------------------------------------------------
# Copyright (c) 2005, Peter Sommerlad and IFS Institute for Software at HSR Rapperswil, Switzerland
# All rights reserved.
#
# This library/application is free software; you can redistribute and/or modify it under the terms of
# the license that is included with this library/application in the file license.txt.
#-----------------------------------------------------------------------------------------------------
#
# project specific installation, loaded from within install.sh
#

# do additional things here
# check install.sh for an overview of pre defined variables

cd $cfg_path

# creating log directories
if [ -d ${LOGDIR}/rotate ]; then
	echo "${LOGDIR}/rotate dir exists"
else
	printf "creating log/rotate directory... "
	mkdir -p ${LOGDIR}/rotate
	if [ $? -ne 0 ]; then
		printf "failed\n"
		exit 1
	else
		printf "done\n"
	fi
fi

echo "changing owner to nobody for log directory"
chown -R nobody:other ${LOGDIR}
