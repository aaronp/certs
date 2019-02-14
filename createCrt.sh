#!/usr/bin/env bash

source ./createCA.sh

#ensureCA

trap "cleanCrt" EXIT

# some lovely shared variables
export CRT_DIR=${CRT_DIR:-target/crt}
mkdir -p $CRT_DIR


export CRT_PWFILE=${PWFILE:-"$CRT_DIR/crtpass.txt"}
export CRT_KEY_FILE=${CRT_KEY_FILE:-"$CRT_DIR/dev.mergebot.com.key.pem"}


CRT_CREATED_PW_FILE=false
INFO=">>> "
# ensure ther is a $PWFILE
cleanCrt () {
	if [[ $CRT_CREATED_PW_FILE="true" ]];then
	  echo "removing $CRT_PWFILE"
	  rm $CA_PWFILE
	fi

	echo "createCrt done"
}

ensureCRTPassword () {
	CRT_CREATED_PW_FILE=false
	if [ ! -f $CRT_PWFILE ]; then
	  CRT_CREATED_PW_FILE=true
	  echo "$INFO CRT_PWFILE $CRT_PWFILE doesn't exist, creating default password..."
	  echo password > ${CRT_PWFILE}
	else
	  echo "$INFO Using pw file $CRT_PWFILE"
	fi
}

ensureCrtKey () {
	if [ ! -f $CRT_KEY_FILE ]; then
  		echo "$INFO creating CRT_KEY_FILE $CRT_KEY_FILE"
  		openssl genrsa -out ${CRT_KEY_FILE} 2048	
  	else
  		echo "$INFO CRT_KEY_FILE $CRT_KEY_FILE exists, skipping"
  	fi
}
