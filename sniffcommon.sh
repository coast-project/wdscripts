export SNIFF_ITOPIA_TEMPLATES=${SNIFF_DIR}/itopiaTemplates

appendPath "PATH" ":" "${SNIFF_BIN_DIR}"

clear
if [ ! -x "${SNIFF_BIN_DIR}/sniff" ]; then
	echo SNiFF+ exe not found! exiting...
	exit 4;
fi

# setup development settings
setDevelopmentEnv
if [ $? -eq 0 ]; then
	echo "something went wrong, aborting...";
	exit 3;
fi
echo "SNIFF_DIR         : ["${SNIFF_DIR}"]"

cat <<EOT

starting in [$DEV_HOME] environment

EOT

sniff &
