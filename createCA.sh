#!/usr/bin/env bash

mkdir target

trap "cleanPassword" EXIT

# some lovely shared variables
export PWFILE=${PWFILE:-"target/capass.txt"}
export PRIVATE_KEY_FILE=${PRIVATE_KEY_FILE:-"target/secret.key"}
export PUBLIC_KEY_FILE=${PUBLIC_KEY_FILE:-"target/secret.pub"}
export CA_DETAILS=${CA_DETAILS:-target/caDetails.conf}
export CA_FILE=${CA_FILE:-"target/myCA.pem"}

CREATED_PW_FILE=false
INFO=">>> "
# ensure ther is a $PWFILE
ensurePassword () {
	CREATED_PW_FILE=false
	if [ ! -f $PWFILE ]; then
	  CREATED_PW_FILE=true
	  echo "$PWFILE doesn't exist, creating default password..."
	  echo password > ${PWFILE}
	else
	  echo "Using pw file $PWFILE"
	fi
}

# remove the password if it was created
cleanPassword () {
	if [[ $CREATED_PW_FILE="true" ]];then
	  echo "removing $PWFILE"
	  rm $PWFILE
	else
		echo done
	fi
}


# create privagte/public keys
ensureKeys () {

	echo "+ + + + + + + + + + + + + + + Generating key pair + + + + + + + + + + + + + + + "

    if [ ! -f $PRIVATE_KEY_FILE ];then
		echo "$INFO Private key '$PRIVATE_KEY_FILE' doesn't exist, creating"

    	ensurePassword
		openssl genrsa -aes128 -passout file:$PWFILE  -out $PRIVATE_KEY_FILE 3072
	else
        echo "$INFO Private key '$PRIVATE_KEY_FILE' already exists"
	fi

    if [ ! -f $PUBLIC_KEY_FILE ];then
		echo "$INFO public key '$PUBLIC_KEY_FILE' doesn't exist, creating"

    	ensurePassword
		openssl rsa -in $PRIVATE_KEY_FILE -passin file:$PWFILE -pubout -out $PUBLIC_KEY_FILE
	else
		echo "$INFO public key $PUBLIC_KEY_FILE already exists"
	fi
}

ensureCASubject () {
    if [ ! -f $CA_DETAILS ];then
		echo "$INFO CA details '$CA_DETAILS' doesn't exist, creating"

    		cat > ${CA_DETAILS} <<-EOF
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
        echo "$INFO CA_DETAILS ${CA_DETAILS} already exists"
	fi


}

ensureCA () {

	echo "+ + + + + + + + + + + + + + + Generating root CA file $CA_FILE + + + + + + + + + + + + + + + "
	if [ ! -f $CA_FILE ];then
		echo "$INFO Certificate Authority file '$CA_FILE' doesn't exist, creating with subject $SUBJECT"

	    ensureKeys
	    ensurePassword
	    ensureCASubject

        #https://deliciousbrains.com/ssl-certificate-authority-for-local-https-development/
        #https://www.endpoint.com/blog/2014/10/30/openssl-csr-with-alternative-names-one
        echo "Invoking:"
        echo "openssl req -x509 -new -nodes -key ${PRIVATE_KEY_FILE} -passin file:$PWFILE -sha256 -days 1825 -out ${CA_FILE} -config <( cat $CA_DETAILS )"
	    openssl req -x509 -new -nodes -key ${PRIVATE_KEY_FILE} -passin file:$PWFILE -sha256 -days 1825 -out ${CA_FILE} -config <( cat $CA_DETAILS )
	else
		echo "$INFO CA_FILE '${CA_FILE}'' exists, skipping"
	fi
}

ensureCA


