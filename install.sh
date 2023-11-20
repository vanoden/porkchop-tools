#!/bin/bash
###########################################
### install.sh							###
### Move uploaded files from deploy.sh	###
### to their working locations.			###
### A. Caravello 11/18/2023				###
###########################################

# Paths
SOURCE=/export/deploy
TARGET=/home/chef

# Validation
if [ ! -d "/etc/chef" ]; then
	echo "Chef not installed!"
	exit 1
fi

if [ ! -d "$SOURCE" ]; then 
	echo "Source files not available"
	exit 1
fi

if [ ! -d "$TARGET" ]; then
	echo "Chef account not found"
	exit 1
fi

# Fetch Cookbooks and Roles
for REPO in cookbooks roles
do
	if [ -d "$TARGET/$REPO/.git" ]
then
	cd "$TARGET/$REPO"
	git pull
	cd -
else
	git clone https://github.com/vanoden/porkchop-$REPO $TARGET/$REPO
fi

# Install Chef Client Config
cp -f $SOURCE/client.rb /etc/chef/

# Install Chef Environment
mkdir -p $TARGET/environments
cp -f $SOURCE/environments/environment.rb $TARGET/environments

# Install Chef Data Bags
if [ ! -d "$TARGET/databags" ]; then
	mkdir -p $TARGET/data_bags
fi
/usr/bin/rsync -av $SOURCE/databags/ $TARGET/databags/
