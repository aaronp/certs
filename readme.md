https://deliciousbrains.com/ssl-certificate-authority-for-local-https-development/

and these guys did the same as me and created scripts:
https://github.com/kingkool68/generate-ssl-certs-for-local-development

https://gist.github.com/dobesv/13d4cb3cbd0fc4710fa55f89d1ef69be
# I like this:

[ -f $HOST_KEY ] || openssl genrsa -out $HOST_KEY 2048



use a command=line passphrase:
https://serverfault.com/questions/366372/is-it-possible-to-generate-rsa-key-without-pass-phrase



-------------------------------------------------------------------- createCA.sh --------------------------------------------------------------------------------------------
#!/usr/bin/env bash


trap "cleanupCA" EXIT

# some lovely shared variables
export CA_DIR=${CA_DIR:-target/ca}
mkdir -p $CA_DIR

export CA_DOMAIN=${CA_DOMAIN:-`hostname`}

export CA_PWFILE=${CA_PWFILE:-"$CA_DIR/capass.txt"}
export CA_PRIVATE_KEY_FILE=${CA_PRIVATE_KEY_FILE:-"$CA_DIR/secret.key"}
export CA_PUBLIC_KEY_FILE=${CA_PUBLIC_KEY_FILE:-"$CA_DIR/secret.pub"}
export CA_DETAILS_FILE=${CA_DETAILS_FILE:-$CA_DIR/ca-options.conf}
export CA_FILE=${CA_FILE:-"$CA_DIR/${CA_DOMAIN}-ca.crt"}

# these are used to create the default 'CA_DETAILS_FILE' if it's not specified
export CA_DETAILS_C=${CA_DETAILS_C:-GB}
export CA_DETAILS_ST=${CA_DETAILS_ST:-London}
export CA_DETAILS_L=${CA_DETAILS_L:-London}
export CA_DETAILS_O=${CA_DETAILS_O:-End Point}
export CA_DETAILS_OU=${CA_DETAILS_OU:-Testing Domain}
export CA_DETAILS_emailAddress=${CA_DETAILS_emailAddress:-your-administrative-address@your-awesome-existing-domain.com}


CA_CREATED_PW_FILE=false
INFO=">>> "
# ensure ther is a $CA_PWFILE
ensureCAPassword () {
	CA_CREATED_PW_FILE=false
	if [ ! -f $CA_PWFILE ]; then
	  CA_CREATED_PW_FILE=true
	  echo "$CA_PWFILE doesn't exist, creating default password..."
	  echo password > ${CA_PWFILE}
	else
	  echo "Using pw file $CA_PWFILE"
	fi
}

# remove the password if it was created
cleanupCA () {
	if [[ $CA_CREATED_PW_FILE="true" ]];then
	  echo "removing $CA_PWFILE"
	  rm $CA_PWFILE
	else
		echo done
	fi
}


# create privagte/public keys
ensureCAKeys () {

	echo "+ + + + + + + + + + + + + + + Ensuring CA key pair + + + + + + + + + + + + + + + "

    if [ ! -f $CA_PRIVATE_KEY_FILE ];then
		echo "$INFO Private key '$CA_PRIVATE_KEY_FILE' doesn't exist, creating"

    	ensureCAPassword
		openssl genrsa -aes128 -passout file:$CA_PWFILE  -out $CA_PRIVATE_KEY_FILE 3072
	else
        echo "$INFO Private key '$CA_PRIVATE_KEY_FILE' already exists"
	fi

    if [ ! -f $CA_PUBLIC_KEY_FILE ];then
		echo "$INFO public key '$CA_PUBLIC_KEY_FILE' doesn't exist, creating"

    	ensureCAPassword
		openssl rsa -in $CA_PRIVATE_KEY_FILE -passin file:$CA_PWFILE -pubout -out $CA_PUBLIC_KEY_FILE
	else
		echo "$INFO public key $CA_PUBLIC_KEY_FILE already exists"
	fi
}

ensureCASubject () {
    if [ ! -f $CA_DETAILS_FILE ];then
		echo "$INFO CA details CA_DETAILS_FILE '$CA_DETAILS_FILE' doesn't exist, creating"

    		cat > ${CA_DETAILS_FILE} <<-EOF
[req]
default_bits = 2048
prompt = no
default_md = sha256
req_extensions = req_ext
distinguished_name = dn

[ dn ]
C=$CA_DETAILS_C
ST=$CA_DETAILS_ST
L=$CA_DETAILS_L
O=$CA_DETAILS_O
OU=$CA_DETAILS_OU
emailAddress=$CA_DETAILS_emailAddress
CN = $CA_DOMAIN

[ req_ext ]
subjectAltName = @alt_names

[ alt_names ]
DNS.1 = $CA_DOMAIN
DNS.2 = www.$CA_DOMAIN
DNS.3 = localhost
EOF
	else
        echo "$INFO CA_DETAILS_FILE ${CA_DETAILS_FILE} already exists"
	fi
}

# ensures the CA_FILE exists or creates one if necessary
ensureCA () {

	echo "+ + + + + + + + + + + + + + + Ensuring root CA file $CA_FILE + + + + + + + + + + + + + + + "
	if [ ! -f $CA_FILE ];then
		echo "$INFO Certificate Authority file '$CA_FILE' doesn't exist, creating with subject $SUBJECT"

	    ensureCAKeys
	    ensureCAPassword
	    ensureCASubject

        #https://deliciousbrains.com/ssl-certificate-authority-for-local-https-development/
        #https://www.endpoint.com/blog/2014/10/30/openssl-csr-with-alternative-names-one
	    openssl req -x509 -new -nodes -key ${CA_PRIVATE_KEY_FILE} -passin file:$CA_PWFILE -sha256 -days 1825 -out ${CA_FILE} -config <( cat $CA_DETAILS_FILE )
	else
		echo "$INFO CA_FILE '${CA_FILE}'' exists, skipping"
	fi
}




-------------------------------------------------------------------- createCrt.sh --------------------------------------------------------------------------------------------
#!/usr/bin/env bash

source ./createCA.sh

#ensureCA

trap "cleanCrt" EXIT

# some lovely shared variables
export CRT_DIR=${CRT_DIR:-target/crt}
mkdir -p $CRT_DIR


export CRT_PWFILE=${PWFILE:-"$CRT_DIR/crtpass.txt"}
export CRT_NAME=${CRT_NAME:-`hostname`}
export CRT_KEY_FILE=${CRT_KEY_FILE:-"$CRT_DIR/$CRT_NAME.pem"}
export CRT_CSR_FILE=${CRT_CSR_FILE:-"$CRT_DIR/$CRT_NAME.csr"}
export CRT_CERT_FILE=${CRT_CERT_FILE:-"$CRT_DIR/$CRT_NAME.crt"}
export CRT_DETAILS_FILE=${CRT_DETAILS_FILE:-"$CRT_DIR/${CRT_NAME}-options.conf"}


# stuff for converting our CRT_CERT_FILE from .crt into a .jks file
export CRT_CERT_FILE_JKS=${CRT_CERT_FILE_JKS:-"$CRT_DIR/$CRT_NAME.jks"}
export CRT_CERT_FILE_JKS_ALIAS=${CRT_CERT_FILE_JKS_ALIAS:-$CRT_NAME}


# stuff for converting our CRT_CERT_FILE from .crt into a .p12 file
export CRT_CERT_FILE_P12=${CRT_CERT_FILE_P12:-"$CRT_DIR/$CRT_NAME.p12"}


#
# CRT Details
#
export CRT_CSR_DETAILS_FILE=${CRT_CSR_DETAILS_FILE:-"$CRT_DIR/${CRT_NAME}-csr.conf"}
# these are used to create the default 'CRT_CSR_DETAILS_FILE' if it's not specified
export CRT_DETAILS_C=${CRT_DETAILS_C:-GB}
export CRT_DETAILS_ST=${CRT_DETAILS_ST:-London}
export CRT_DETAILS_L=${CRT_DETAILS_L:-London}
export CRT_DETAILS_O=${CRT_DETAILS_O:-End Point}
export CRT_DETAILS_OU=${CRT_DETAILS_OU:-Testing Domain}
export CRT_DETAILS_emailAddress=${CRT_DETAILS_emailAddress:-your-administrative-address@your-awesome-existing-domain.com}

export CRT_JKS_PW=${CRT_JKS_PW:-changeThisPassword}

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
C=$CRT_DETAILS_C
ST=$CRT_DETAILS_ST
L=$CRT_DETAILS_L
O=$CRT_DETAILS_O
OU=$CRT_DETAILS_OU
emailAddress=$CRT_DETAILS_emailAddress
CN = $CRT_NAME

[ req_ext ]
subjectAltName = @alt_names

[ alt_names ]
DNS.1 = $CRT_NAME
DNS.2 = www.$CRT_NAME
DNS.3 = localhost
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
EOF
  	else
  		echo "$INFO  CRT config file CRT_CSR_DETAILS_FILE $CRT_CSR_DETAILS_FILE exists, skipping"
  	fi

}

# Combines our CA w/ our CSR -- this signs our CRT using our CA_FILE
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

  		openssl x509 -req -in ${CRT_CSR_FILE} -CA ${CA_FILE} -CAkey ${CA_PRIVATE_KEY_FILE} -passin file:$CA_PWFILE -CAcreateserial -out $CRT_CERT_FILE -days 1825 -sha256 -extfile $CRT_CSR_DETAILS_FILE
  	else
  		echo "$INFO Signed certificate CRT_CERT_FILE $CRT_CERT_FILE exists, skipping"
  	fi
}

# Converts the CRT_CERT_FILE into a .jks format
ensureJKSFromSignedCertificate () {
  echo "+ + + + + + + + + + + + + + + Ensuring JKS file $CRT_CERT_FILE_JKS + + + + + + + + + + + + + + + "
  if [ ! -f $CRT_CERT_FILE_JKS ]; then
      echo "$INFO creating CRT_CERT_FILE_JKS $CRT_CERT_FILE_JKS"

      ensureSignedCrt
      ensureCrtJKSPassword

      keytool -noprompt -importcert -alias ${CRT_CERT_FILE_JKS_ALIAS} -file ${CRT_CERT_FILE} -keystore $CRT_CERT_FILE_JKS -storepass ${CRT_JKS_PW}

      #echo "$INFO created jks file $CRT_CERT_FILE_JKS from  $CRT_CERT_FILE with alias $CRT_CERT_FILE_JKS_ALIAS :"
      #keytool -list -v -keystore $CRT_CERT_FILE_JKS -storepass ${CRT_JKS_PW}
    else
      echo "$INFO JKS file CRT_CERT_FILE_JKS $CRT_CERT_FILE_JKS exists, skipping"
    fi
}


# Converts the CRT_CERT_FILE into a .p12 format
ensureP12FromSignedCertificate () {
  echo "+ + + + + + + + + + + + + + + Ensuring .p12 file $CRT_CERT_FILE_P12 + + + + + + + + + + + + + + + "
  if [ ! -f $CRT_CERT_FILE_P12 ]; then
      echo "$INFO creating CRT_CERT_FILE_P12 $CRT_CERT_FILE_P12"


      # ensyre a password for this .p12 file
      ensureCRTPassword

      #ensureCA

      # we need our signed .crt file to convert
      ensureSignedCrt

      # https://www.ssl.com/how-to/create-a-pfx-p12-certificate-file-using-openssl/
      #openssl pkcs12 -export -out $CRT_CERT_FILE_P12 -inkey $CRT_KEY_FILE -in ${CRT_CERT_FILE} -certfile ${CA_FILE}
      openssl pkcs12 -passout file:$CRT_PWFILE -export -out $CRT_CERT_FILE_P12 -inkey $CRT_KEY_FILE -in ${CRT_CERT_FILE}
    else
      echo "$INFO p12 file CRT_CERT_FILE_P12 $CRT_CERT_FILE_P12 exists, skipping"
    fi
}




-------------------------------------------------------------------- build.sh --------------------------------------------------------------------------------------------
#!/usr/bin/env bash
source ./createCrt.sh

# ensureCA


ensureJKSFromSignedCertificate
ensureP12FromSignedCertificate
