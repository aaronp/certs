echo password > capass.txt

openssl genrsa -aes128 -out -passout file:capass.txt myCA.key 2048
