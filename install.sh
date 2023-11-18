#!/bin/bash
###########################################
### install.sh							###
### Move uploaded files from deploy.sh	###
### to their working locations.			###
### A. Caravello 11/18/2023				###
###########################################

# Paths
SOURCE=~/.deploy
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

# Install Chef Client Config
sudo cp -f $SOURCE/chef/client.rb /etc/chef/

# Install Chef Keys
sudo cp $SOURCE/keys/id_* $TARGET/.ssh/

# Install Chef Files
for folder in tools cookbooks environments roles data_bags
do
	if [ -d "$TARGET/$folder" ]; then
		sudo mkdir -p $TARGET/$folder

		sudo /usr/bin/rsync -av $SOURCE/$folder/ $TARGET/$folder/
	fi
done
