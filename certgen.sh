#!/bin/bash

# Function to display help message
usage() {
    echo "Usage: $0 -servicename <service_name> -commonname <common_name> -dnsentries <dns_entries_comma_separated> -ipaddresses <ip_addresses_comma_separated>"
    exit 1
}

# Parse command line arguments
while [[ "$#" -gt 0 ]]; do
    case $1 in
        -servicename) SERVICE_NAME="$2"; shift ;;
        -commonname) COMMON_NAME="$2"; shift ;;
        -dnsentries) DNS_ENTRIES="$2"; shift ;;
        -ipaddresses) IP_ADDRESSES="$2"; shift ;;
        *) usage ;;
    esac
    shift
done

# Check if all required parameters are provided
if [ -z "$SERVICE_NAME" ] || [ -z "$COMMON_NAME" ] || [ -z "$DNS_ENTRIES" ] || [ -z "$IP_ADDRESSES" ]; then
    usage
fi

# Prompt for CA password
read -r -sp "Enter CA password: " CA_PASSWORD
echo ""

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

# Generate the certificate using the CA (CA password required)
openssl x509 -req -sha256 -days 3650 -in "$SERVICE_NAME/$SERVICE_NAME-cert.csr" -CA /root/certs/CA/ca.pem -CAkey /root/certs/CA/ca-key.pem -out "$SERVICE_NAME/$SERVICE_NAME-cert.pem" -extfile "$SERVICE_NAME/extfile.cnf" -extensions v3_ca -CAcreateserial -passin pass:$CA_PASSWORD

# Generate the fullchain file
cat "$SERVICE_NAME/$SERVICE_NAME-cert.pem" /root/certs/CA/ca.pem > "$SERVICE_NAME/$SERVICE_NAME-fullchain.pem"

# Clean up
rm "$SERVICE_NAME/$SERVICE_NAME-cert.csr"

echo "Certificate, key, and fullchain created successfully in the $SERVICE_NAME directory."
