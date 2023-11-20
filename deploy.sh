#/bin/bash
#######################################
### deploy.sh						###
### Upload files to server for		###
### installation and configuration.	###
### A. Caravello 11/18/2023			###
#######################################

# Command Line Params
HOST=$1
ENVIRONMENT=$2
ACCOUNT=$3

# Allow User to Specify Remote Account for destination path
if [ -z "$ACCOUNT" ]; then
	ACCOUNT=$USER
fi

# Paths
LOCAL=~/aws-chef
REMOTE=/export/deploy
FILES=$LOCAL/$ENVIRONMENT

# Validate Environment
if [ -z "$HOST" ]; then
	echo "Valid hostname required as first param"
	exit 1
fi

if [ -z "$ENVIRONMENT" ]; then
	echo "Valid environment required as second param"
	exit 1
fi

if [ ! -d $LOCAL ]; then
	echo "Files Home $LOCAL not found"
	exit 1
fi

if [ ! -d $FILES ]; then
	echo "Environment not found"
	exit 1
fi

# Create TMP dir on Remote Server
echo "Creating remote directory $REMOTE on $HOST"
/usr/bin/ssh $HOST "if [ ! -d \"$REMOTE\" ]; then mkdir -p \"$REMOTE\"; fi;"

# Upload files
echo "Uploading files from $FILES to $REMOTE"
/usr/bin/ssh $HOST "if [ -d \"$REMOTE/tools/.git\" ]; then cd $REMOTE/tools; git pull; else git clone https://github.com/vanoden/porkchop-tools $REMOTE/tools; fi"
/usr/bin/rsync -ave ssh $FILES/ $HOST:$REMOTE/
