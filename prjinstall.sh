###########################################################################
# Copyright (c) 1999-2000 itopia
# All Rights Reserved
#
# $Id$
#
# project specific installation, loaded from within install.sh
#
############################################################################

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
