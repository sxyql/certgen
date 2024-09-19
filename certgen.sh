#!/bin/bash
#Tested on Ubuntu 20.04
# Prompt for service name, IP common name, and DNS entries
echo "This script will generate a certificate for a service."
read -r -p "Enter service name: " SERVICE_NAME
read -r -p "Enter common name: " COMMON_NAME
read -r -p "Enter DNS entries (comma-separated): " DNS_ENTRIES
read -r -p "Enter IP addresses (comma-separated): " IP_ADDRESSES

# Create a directory for the service
mkdir -p "$SERVICE_NAME"

# Create a configuration file for OpenSSL
cat > "$SERVICE_NAME/extfile.cnf" <<EOL
[ req ]
default_bits       = 4096
default_md         = sha256
default_keyfile    = $SERVICE_NAME/$SERVICE_NAME-cert-key.pem
distinguished_name = req_distinguished_name
req_extensions     = req_ext

[ req_distinguished_name ]
commonName                  = Common Name (e.g. server FQDN or YOUR name)
commonName_default          = $COMMON_NAME

[ req_ext ]
subjectAltName = @alt_names

[ v3_ca ]
subjectAltName = @alt_names

[ alt_names ]
DNS.1 = $COMMON_NAME
DNS.2 = localhost
IP.1 = 127.0.0.1
IP.2 = ::1
EOL

# Add DNS entries to the configuration file
IFS=',' read -r -a DNS_ARR <<< "$DNS_ENTRIES"
for i in "${!DNS_ARR[@]}"; do
    echo "DNS.$((i+3)) = ${DNS_ARR[$i]}" >> "$SERVICE_NAME/extfile.cnf"
done

# Add IP addresses to the configuration file
IFS=',' read -r -a IP_ARR <<< "$IP_ADDRESSES"
for i in "${!IP_ARR[@]}"; do
    echo "IP.$((i+3)) = ${IP_ARR[$i]}" >> "$SERVICE_NAME/extfile.cnf"
done

# Debugging: Output the contents of the extfile.cnf
echo "Generated extfile.cnf:"
cat "$SERVICE_NAME/extfile.cnf"

# Generate the private key
openssl genrsa -out "$SERVICE_NAME/$SERVICE_NAME-cert-key.pem" 4096

# Generate the certificate signing request (CSR)
openssl req -new -sha256 -subj "/CN=$COMMON_NAME" -key "$SERVICE_NAME/$SERVICE_NAME-cert-key.pem" -out "$SERVICE_NAME/$SERVICE_NAME-cert.csr" -config "$SERVICE_NAME/extfile.cnf" -extensions req_ext

# Generate the certificate using the CA
openssl x509 -req -sha256 -days 3650 -in "$SERVICE_NAME/$SERVICE_NAME-cert.csr" -CA /root/certs/CA/ca.pem -CAkey /root/certs/CA/ca-key.pem -out "$SERVICE_NAME/$SERVICE_NAME-cert.pem" -extfile "$SERVICE_NAME/extfile.cnf" -extensions v3_ca -CAcreateserial

# Generate the fullchain file
cat "$SERVICE_NAME/$SERVICE_NAME-cert.pem" /root/certs/CA/ca.pem > "$SERVICE_NAME/$SERVICE_NAME-fullchain.pem"

# Clean up
rm "$SERVICE_NAME/$SERVICE_NAME-cert.csr"

echo "Certificate, key, and fullchain created successfully in the $SERVICE_NAME directory."
