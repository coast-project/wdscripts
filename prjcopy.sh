###########################################################################
# Copyright (c) 1999-2000 itopia
# All Rights Reserved
#
# $Id$
#
# project specific copying and setting of permissions for directories
# loaded from within cpall.sh
#
# check the file config.sh to have an overview of the predefined variables
# you can use for defined directories etc
#
############################################################################

# NOTE: $TMPDIR/bin already created and generic parts copied (wdserver, wdapp)
# NOTE: $TMPDIR/config already created and generic parts copied (any, sh)
# NOTE: $TMPDIR/lib already created and generic parts copied (so)
# NOTE: $TMPDIR/scripts already created and generic parts copied (sh, awk)

# NOTE: try not to use recursive copying because of possible CVS directories

# NOTE: please adjust permissions of directories for security reason

# you can modify the following parts, these are here as example

#mkdir $TMPDIR/config/HTMLTemplates
#mkdir $TMPDIR/config/HTMLTemplates/Localized_D
#mkdir $TMPDIR/config/images

#mkdir $TMPDIR/perftest
#mkdir $TMPDIR/perftest/config

#mkdir $TMPDIR/doc
#mkdir $TMPDIR/log
#mkdir $TMPDIR/log/rotate

#cp $SSL_DIR/bin/openssl $TMPDIR/bin

# copy everything now
#cp $CONFIGDIR/images/*  $TMPDIR/config/images
#cp $CONFIGDIR/HTMLTemplates/*.html $TMPDIR/config/HTMLTemplates
#cp $CONFIGDIR/HTMLTemplates/Localized_D/*.html $TMPDIR/config/HTMLTemplates/Localized_D
#cp $PROJECTDIR/ftp_perftest/*.sh $TMPDIR/perftest #perftest stuff
#cp $PROJECTDIR/ftp_perftest/config/*.sh $TMPDIR/perftest/config #perftest stuff
#cp $PROJECTDIR/ftp_perftest/config/*.any $TMPDIR/perftest/config #perftest stuff

#chmod 664 $TMPDIR/config/HTMLTemplates/*.html
#chmod 444 $TMPDIR/config/images/*gif
#chmod 444 $TMPDIR/config/images/*jpg

#copy doc
#cp $PROJECTDIR/doc/*.txt $TMPDIR/doc
#chmod 664 $TMPDIR/doc/*txt

# cp lib entries
#cp $LDAP_LIBDIR/*${DLLEXT} $TMPDIR/lib
