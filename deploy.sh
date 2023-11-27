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
#ACCOUNT=$3

# Allow User to Specify Remote Account for destination path
#if [ -z "$ACCOUNT" ]; then
#	ACCOUNT=$USER
#fi

ACCOUNT=ec2-user

# Paths
LOCAL=~/aws-chef
REMOTE=/etc/chef
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
ENVIRONMENTS=$REMOTE/environments
ROLES=$REMOTE/roles
DATABAGS=$REMOTE/data_bags
COOKBOOKS=$REMOTE/cookbooks
/usr/bin/ssh $HOST "sudo mkdir -p \"$ENVIRONMENTS\" \"$ROLES\" \"$DATABAGS\" \"$COOKBOOKS\"; sudo sudo chown -R ec2-user \"$ENVIRONMENTS\" \"$ROLES\" \"$DATABAGS\" \"$COOKBOOKS\""

# Upload files
echo "Uploading files from $FILES to $REMOTE"
#/usr/bin/ssh $HOST "if [ -d \"$REMOTE/tools/.git\" ]; then cd $REMOTE/tools; git pull; else git clone https://github.com/vanoden/porkchop-tools $REMOTE/tools; fi"
/usr/bin/rsync -ave ssh tools/chef_tool.sh $HOST:/home/ec2-user/
/usr/bin/rsync -ave ssh $FILES/ $HOST:$REMOTE/
