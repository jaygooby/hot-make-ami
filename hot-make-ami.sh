#!/bin/sh
#
# Author: Jay Caines-Gooby, jay@gooby.org 
#
# Bundle the running machine into an AMI and upload to S3
# Stick this in cron.weekly or cron.monthly depending on how often you noodle
# with your server and forget to manually image it.
#
# Note that if you want to safely backup a mysql server with its data you'll need to
# lock the tables, flush the filesystem, etc to get a safe static state from which
# to make the image
# Read http://developer.amazonwebservices.com/connect/entry.jspa?externalID=1663
# for more detail

# Assumptions:
# 1. You have the latest ec2-ami-tools from Amazon
# http://developer.amazonwebservices.com/connect/entry.jspa?externalID=368
#
# 2. That when you first set up your EC2 account you remembered to save the x509 key
# http://docs.amazonwebservices.com/AWSEC2/2008-02-01/GettingStartedGuide/index.html?account.html 
#
# 3. That you have Java installed

# Where stuff lives
export EC2_AMI_DIR = /ebs/resource_library/ec2-ami-tools-1.3-26357
export EC2_KEY_DIR = /ebs/resource_library

# Account identifiers
export EC2_ACCNO=xxxxxxxxxxx
export EC2_PRIVATE_KEY=$EC2_KEY_DIR/pk-XXXXXXXX.pem
export EC2_CERT=$EC2_KEY_DIR/cert-XXXXXXX.pem

# Your account details for the running AMI - find them on 
# http://aws-portal.amazon.com/gp/aws/developer/account/index.html?action=access-key
export ACCESS_KEY=XXXXXXXXXXXX
export SECRET_KEY=XXXXXXXXXXXX

# et tu Java?
export JAVA_HOME=/usr

# Directories that you don't want imaged
export EXCLUDED_DIRS=/ebs/resource_library,/ebs/www,/tmp,/proc,/mnt,/sys/,/dev/shm,/dev/pts,/lib/init/rw,/dev

# What you want your AMI to be saved as
# The date (YYYY-MM-DD) is automatically appended, so
# export AMI_NAME_PREFIX=my-sweet-ami
# would result in an AMI of my-sweet-ami-2009-03-17
export AMI_NAME_PREFIX=ec2-rails

# CHANGE NOTHING BELOW HERE #################################################
export EC2_HOME=$EC2_AMI_DIR
export PATH=$PATH:$EC2_AMI_DIR/bin

# Set the date of this bundle
TODAY=`date +%Y-%m-%d`
export AMI_NAME=$AMI_NAME_PREFIX-$TODAY

function upload_to_s3() {  
  # upload to S3, check return value is 0, otherwise it failed, so try again
  ec2-upload-bundle -b $AMI_NAME -m /mnt/$AMI_NAME.manifest.xml -a $ACCESS_KEY -s $SECRET_KEY

  # keep trying until OK
  if [ $? -ne 0 ]; then
    upload_to_s3
  else
    # tidy up
    rm -rf /mnt/$AMI_NAME*
  fi
}

# make the bundle
ec2-bundle-vol -c $EC2_CERT -k $EC2_PRIVATE_KEY -u $EC2_ACCNO -e $EXCLUDED_DIRS -d /mnt -p $AMI_NAME

# The S3 upload process can be subject to errors, so we need to be certain that it all uploaded OK
upload_to_s3