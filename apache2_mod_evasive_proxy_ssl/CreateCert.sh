#!/bin/bash

function CreateCert() {
    function help() {
echo >&2 '
./CreateCert.sh -C US -ST soviet -L London \
    -O "bad guys inc" -OU "Bad Certs" \
    -CN "woohsdf.com" -AN "more.asdf.com" -AN "6666.asdf.com" \
    -E "nobody@her.ee" --comment "thi s a comment"
    
  ./CreateCert.sh --chdir -C AQ -ST "Ross Archipelago - McMurdo Landfill" -L "Mt. Erebus" -O "Hephaestos Skunk Works" -OU "Cert Authority" -E hephaistos@olymp -CN Authority 
  ./CreateCert.sh --chdir -C AQ -ST "Ross Archipelago - McMurdo Dump" -L "Mt. Terror" -O "Gollum Jewlery Ltd." -OU "Smeagol's Dept." -E deagol@mordor -CA Authority -CN default
  ./CreateCert.sh --chdir -C AQ -ST "Ross Archipelago - McMurdo Dump" -L "Mt. Terror" -O "Hades Notary Inc." -OU "Plutus Accouting Dept." -E kerberos@styx -CA Authority -CN paperless \
 -AN paperless.intranet -AN paperless.internal -AN paperless.private -AN paperless.corp -AN paperless.home -AN paperless.lan -AN paperless.local'
    }
    
function log() {
    echo " >>> $@ <<<"
    }
    
    log "create openssl config template"
    cat << EOF > /tmp/out.cnf
[ req ]
default_bits        = 4096
default_md          = sha512
default_keyfile     = whatever.company.com.key.pem
distinguished_name  = subject
req_extensions      = req_ext
x509_extensions     = x509_ext
string_mask         = utf8only
prompt              = no
encrypt_key         = no

[ subject ]
#countryName            = US
#stateOrProvinceName    = Missouri
#localityName           = Jefferson City
#organizationName       = My Company
#organizationalUnitName = My Company Technologies
#commonName             = drone-ci-web.company.com
#emailAddress           = DL_EMAIL_LIST@company.com

[ x509_ext ]
subjectKeyIdentifier   = hash
authorityKeyIdentifier = keyid,issuer
basicConstraints       = CA:FALSE
keyUsage               = digitalSignature, keyEncipherment
subjectAltName         = @alternate_names
#nsComment              = "Drone-CI - OpenSSL Generated Certificate"

[ req_ext ]
subjectKeyIdentifier = hash
basicConstraints     = CA:FALSE
keyUsage             = digitalSignature, keyEncipherment
subjectAltName       = @alternate_names
#nsComment            = "Drone-CI - OpenSSL Generated Certificate"

[ alternate_names ]
#DNS.1 = drone-ci-web.company.com
EOF

    log "parsing arguments"
    days=3650
    chown=""
    while [ "$1" != "" ]; do
    case "$1" in
        "--help"|"-?")
            help; exit 1
            ;;
        "--comment"|"-c")
            shift; nsComment=\"$1\"
            shift; continue
            ;;    
        "--countryName"|"-C")
            shift; countryName=$1
            shift; continue
            ;;
        "--stateName"|"-ST")
            shift; stateOrProvinceName=$1
            shift; continue
            ;;
        "--localityName"|"-L")
            shift; localityName=$1
            shift; continue
            ;;
        "--organizationName"|"-O")
            shift; organizationName=$1
            shift; continue
            ;;
        "--organizationalUnit"|"-OU")
            shift; organizationalUnitName=$1
            shift; continue
            ;;
        "--emailAddress"|"-E")
            shift; emailAddress=$1
            shift; continue
            ;;
        "--commonName"|"-CN")
            shift; commonName=$1; altNames=$1
            shift; continue
            ;;
        "--altName"|"-AN")
            shift; altNames="${altNames} $1"
            shift; continue
            ;;            
        "--Authority"|"-CA")
            shift; authority="$1"
            shift; continue
            ;;
        "--days"|"-d")
            shift; days="$1"
            shift; continue
            ;;
        "--chdir")
            shift; cd /etc/httpd/certs
            continue
            ;;
        "--chown")
            shift; chown="$1"
            shift; continue
            ;;
        "--chmod")
            shift; chmod="$1"
            shift; continue
            ;;
        *)
            echo "unknown option '$1'"
            help; exit 1
            ;;
    esac
    done
    
    if [ -z "${commonName}" ]; then
        echo >&2 "at least commonName must be provided"
        exit 1
    fi
    
    cp /tmp/out.cnf ${commonName}.cnf
    
    log "search and replace variables in config file"
    for key in countryName stateOrProvinceName localityName organizationName organizationalUnitName emailAddress commonName nsComment; do
        value=${!key}
        if [ ! -z "${value}" ]; then
            sed -i 's/\(^#\)\('${key}'.*= \)\(.*\)/\2'"${value}"'/' ${commonName}.cnf
        fi
    done

    #sed -i 's/\(^#\)\(.*\)/\2/' ${commonName}.cnf

    log "append alt-names"
    counter=1
    for altName in ${altNames}; do
        echo "DNS.${counter} = ${altName}" | tee -a ${commonName}.cnf
        counter=$((${counter}+1)) 
    done
    
    
    log "generate keyfile"
    openssl genrsa -aes256 -passout pass:somepassword -out ${commonName}.key.pass 4096
    openssl rsa -passin pass:somepassword -in ${commonName}.key.pass -out ${commonName}.key

    log "generate csr"
    openssl req -new -key ${commonName}.key -out ${commonName}.csr -config ${commonName}.cnf
    # openssl req -text -noout -verify -in ${commonName}.csr

    log "create the cert"
    if [ -z "${authority}" ]; then
        openssl x509 -req -sha256 -days ${days} -in ${commonName}.csr -signkey ${commonName}.key -out ${commonName}.crt 
    else
        openssl x509 -req -sha256 -days ${days} -in ${commonName}.csr -signkey ${commonName}.key -out ${commonName}.crt -CA ${authority}.crt -CAkey ${authority}.key -CAcreateserial
    fi
    
    # openssl x509 -in certificate.crt -text -noout
    openssl x509 -text -noout -in ${commonName}.crt

    # cleanup
    rm ${commonName}.key.pass ${commonName}.csr ${commonName}.cnf
    
    # reown if required
    if [ ! -z "${chown}" ]; then
        log "chowning to ${chown}"
        chown ${chown} `pwd`/${commonName}.*
    fi
    
    # remod if required
    if [ ! -z "${chmod}" ]; then
        log "chmoding to ${chmod}"
        chmod ${chmod} `pwd`/${commonName}.*
    fi
    
    
    # display generated files
    md5sum `pwd`/${commonName}.key `pwd`/${commonName}.crt
    
}

CreateCert "$@"
