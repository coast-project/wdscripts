#!/bin/ksh
# Datei: swconfig
# wechseln zwischen verschiedenen Konfigs

cd $HOME/DEVELOP/WWW/FKIS

echo Konfig wird auf $1 gewechselt
rm FKIS_config

case $1 in
'39')
		ln -s config FKIS_config
	;;
'40')
		ln -s config40 FKIS_config
	;;
esac

echo Aktuelle Konfig $1 
