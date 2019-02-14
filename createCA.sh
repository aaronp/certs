#!/usr/bin/env bash


trap "cleanupCA" EXIT

# some lovely shared variables
export CA_DIR=${CA_DIR:-target/ca}
mkdir -p $CA_DIR

export CA_PWFILE=${CA_PWFILE:-"$CA_DIR/capass.txt"}
export CA_PRIVATE_KEY_FILE=${CA_PRIVATE_KEY_FILE:-"$CA_DIR/secret.key"}
export CA_PUBLIC_KEY_FILE=${CA_PUBLIC_KEY_FILE:-"$CA_DIR/secret.pub"}
export CA_DETAILS=${CA_DETAILS:-$CA_DIR/ca-options.conf}
export CA_FILE=${CA_FILE:-"$CA_DIR/myCA.pem"}

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
        echo "Invoking:"
        echo "openssl req -x509 -new -nodes -key ${CA_PRIVATE_KEY_FILE} -passin file:$CA_PWFILE -sha256 -days 1825 -out ${CA_FILE} -config <( cat $CA_DETAILS )"
	    openssl req -x509 -new -nodes -key ${CA_PRIVATE_KEY_FILE} -passin file:$CA_PWFILE -sha256 -days 1825 -out ${CA_FILE} -config <( cat $CA_DETAILS )
	else
		echo "$INFO CA_FILE '${CA_FILE}'' exists, skipping"
	fi
}



