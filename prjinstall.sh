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

cd $INSTALLDIRABS

# creating log directories
if [ -d log/rotate ]; then
	echo "log/rotate dir exists"
else
	printf "creating log/rotate directory... "
	mkdir -p log/rotate
	if [ $? -ne 0 ]; then
		printf "failed\n"
		exit 1
	else
		printf "done\n"
	fi
fi

echo "changing owner to nobody for log directory"
chown -R nobody:other log
