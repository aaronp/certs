#!/usr/bin/env bash

source ./createCA.sh

#ensureCA

trap "cleanCrt" EXIT

# some lovely shared variables
export CRT_DIR=${CRT_DIR:-target/crt}
mkdir -p $CRT_DIR


export CRT_PWFILE=${PWFILE:-"$CRT_DIR/crtpass.txt"}
export CRT_NAME=${CRT_NAME:-dev.mergebot.com}
export CRT_KEY_FILE=${CRT_KEY_FILE:-"$CRT_DIR/$CRT_NAME.pem"}
export CRT_CR_FILE=${CRT_CR_FILE:-"$CRT_DIR/$CRT_NAME.csr"}
export CRT_DETAILS=${CRT_DETAILS:-"$CRT_DIR/${CRT_NAME}-subject.conf"}


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


ensureCRTSubject () {
    if [ ! -f $CRT_DETAILS ];then
		echo "$INFO CRT details '$CRT_DETAILS' doesn't exist, creating"

    		cat > ${CRT_DETAILS} <<-EOF
[req]
default_bits = 2048
prompt = no
default_md = sha256
req_extensions = req_ext
distinguished_name = dn

[ dn ]
C=US
ST=New York
L=Rochester
O=End Point
OU=Testing Domain
emailAddress=your-administrative-address@your-awesome-existing-domain.com
CN = www.your-new-domain.com

[ req_ext ]
subjectAltName = @alt_names

[ alt_names ]
DNS.1 = your-new-domain.com
DNS.2 = www.your-new-domain.com
EOF
	else
        echo "$INFO CRT_DETAILS ${CRT_DETAILS} already exists"
	fi
}

ensureCrtCR () {
	echo "+ + + + + + + + + + + + + + + Ensuring Cert CRT file $CRT_CR_FILE + + + + + + + + + + + + + + + "
	if [ ! -f $CRT_CR_FILE ]; then
  		echo "$INFO creating CRT_CR_FILE $CRT_CR_FILE"
  		ensureCrtKey
  		ensureCRTSubject
  		openssl req -new -key ${CRT_KEY_FILE} -out ${CRT_CR_FILE} -config <( cat $CRT_DETAILS )
  	else
  		echo "$INFO CRT_CR_FILE $CRT_CR_FILE exists, skipping"
  	fi
}
