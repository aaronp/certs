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
export CRT_CSR_FILE=${CRT_CSR_FILE:-"$CRT_DIR/$CRT_NAME.csr"}
export CRT_CERT_FILE=${CRT_CERT_FILE:-"$CRT_DIR/$CRT_NAME.crt"}
export CRT_DETAILS_FILE=${CRT_DETAILS_FILE:-"$CRT_DIR/${CRT_NAME}-subject.conf"}
export CRT_CSR_DETAILS_FILE=${CRT_CSR_DETAILS_FILE:-"$CRT_DIR/${CRT_NAME}-csr.conf"}


CRT_CREATED_PW_FILE=false
INFO=">>> "
# ensure ther is a $PWFILE
cleanCrt () {
	if [[ $CRT_CREATED_PW_FILE = "true" ]];then
	  echo "removing $CRT_PWFILE"
	  rm $CRT_PWFILE
	else
	  echo "no need to cleanup CRT "
	fi
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
  		ensureCRTPassword
  		openssl genrsa -passout file:$CRT_PWFILE  -out ${CRT_KEY_FILE} 2048	
  	else
  		echo "$INFO CRT_KEY_FILE $CRT_KEY_FILE exists, skipping"
  	fi
}


ensureCRTSubject () {
    if [ ! -f $CRT_DETAILS_FILE ];then
		echo "$INFO CRT details '$CRT_DETAILS_FILE' doesn't exist, creating"

    		cat > ${CRT_DETAILS_FILE} <<-EOF
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
CN = www.$CRT_NAME.com

[ req_ext ]
subjectAltName = @alt_names

[ alt_names ]
DNS.1 = $CRT_NAME
DNS.2 = www.$CRT_NAME
EOF
	else
        echo "$INFO CRT_DETAILS_FILE ${CRT_DETAILS_FILE} already exists"
	fi
}

# Creates a new CSR file using the 'CRT Subject' provided by ensureCRTSubject and 
# encrypted using our CRT_KEY_FILE file
ensureCrtCR () {
	echo "+ + + + + + + + + + + + + + + Ensuring Cert CRT file $CRT_CSR_FILE + + + + + + + + + + + + + + + "
	if [ ! -f $CRT_CSR_FILE ]; then
  		echo "$INFO creating CRT_CSR_FILE $CRT_CSR_FILE"
  		ensureCrtKey
  		ensureCRTSubject
  		openssl req -new -key ${CRT_KEY_FILE} -out ${CRT_CSR_FILE} -config <( cat $CRT_DETAILS_FILE )
  	else
  		echo "$INFO CRT_CSR_FILE $CRT_CSR_FILE exists, skipping"
  	fi
}

# Once we have our cert signing request, we can sign it with our CA based on the 
ensureCrtCSRConfFile () {

	echo "+ + + + + + + + + + + + + + + Ensuring Cert CSR config file $CRT_CSR_DETAILS_FILE + + + + + + + + + + + + + + + "
	if [ ! -f $CRT_CSR_DETAILS_FILE ]; then
  		echo "$INFO creating CRT config file CRT_CSR_DETAILS_FILE $CRT_CSR_DETAILS_FILE"

    		cat > ${CRT_CSR_DETAILS_FILE} <<-EOF
authorityKeyIdentifier=keyid,issuer
basicConstraints=CA:FALSE
keyUsage = digitalSignature, nonRepudiation, keyEncipherment, dataEncipherment
subjectAltName = @alt_names

[alt_names]
DNS.1 = $CRT_NAME
DNS.2 = $CRT_NAME.192.168.1.19.xip.io
EOF
  	else
  		echo "$INFO  CRT config file CRT_CSR_DETAILS_FILE $CRT_CSR_DETAILS_FILE exists, skipping"
  	fi

}

ensureSignedCrt () {
	echo "+ + + + + + + + + + + + + + + Ensuring Signed Cert $CRT_CERT_FILE + + + + + + + + + + + + + + + "
	if [ ! -f $CRT_CERT_FILE ]; then
  		echo "$INFO creating CRT_CERT_FILE $CRT_CERT_FILE"

        # we need to sign our crert w/ the CA private key 
	    ensureCA

	    # we need the cert signing request
        ensureCrtCR

        # we need to reference an 'extfile' for the config of this CSR
        ensureCrtCSRConfFile

        echo "Invoking openssl x509 -req -in ${CRT_CSR_FILE} -CA ${CA_FILE} -CAkey ${CA_PRIVATE_KEY_FILE} -CAcreateserial -out $CRT_CERT_FILE -days 1825 -sha256 -extfile $CRT_CSR_DETAILS_FILE"
  		openssl x509 -req -in ${CRT_CSR_FILE} -CA ${CA_FILE} -CAkey ${CA_PRIVATE_KEY_FILE} -CAcreateserial -out $CRT_CERT_FILE -days 1825 -sha256 -extfile $CRT_CSR_DETAILS_FILE
  	else
  		echo "$INFO Signed certificate CRT_CERT_FILE $CRT_CERT_FILE exists, skipping"
  	fi
}


