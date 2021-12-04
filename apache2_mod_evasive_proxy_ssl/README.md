# apache2_mod_evasive_proxy_ssl container image
A simple sample apache mod proxy and mod evasive container. Sample configuration contains a HTTPS proxy for [paperless-ng](github.com/jonaswinkler/paperless-ng).
```bash
export tag=`date +%Y%m%d`
export image="maldex/apache2_mod_evasive_proxy_ssl"
```

### build - cleanup
```bash
sudo rm -rf certs/
docker image rm ${image}:${tag}
docker image rm ${image}:latest
```

### build - image
```bash
docker build -t ${image}:${tag} . 
```

### run - debug - ???
```bash
docker run --rm -it \
    -p 88:80 \
    -p 443:443 \
    ${image}:${tag}
```

### run - create LOCAL certificates
```bash
mkdir certs/

docker run --rm -it -v ${PWD}/certs:/etc/httpd/certs ${image}:${tag} \
    /root/CreateCert.sh --chdir -C AQ -ST "Ross Archipelago" -L "Mt. Erebus" -O "Hephaestos Skunk Works" -OU "Cert Authority" -E hephaistos@olymp -CN Authority 
    
docker run --rm -it -v ${PWD}/certs:/etc/httpd/certs ${image}:${tag} \
    /root/CreateCert.sh --chdir -C AQ -ST "Ross Archipelago" -L "Mt. Terror" -O "Gollum Jewlery Ltd." -OU "Smeagol's Dept." -E deagol@mordor -CA Authority -CN default
    
docker run --rm -it -v ${PWD}/certs:/etc/httpd/certs ${image}:${tag} \
    /root/CreateCert.sh --chdir -C AQ -ST "Ross Archipelago" -L "Mt. Terror" -O "Hades Notary Inc." -OU "Plutus Accouting Dept." -E kerberos@styx -CA Authority -CN paperless \
    -AN paperless.intranet -AN paperless.internal -AN paperless.private -AN paperless.corp -AN paperless.home -AN paperless.lan -AN paperless.local
    
ls -lah certs/
```

### run - run
```bash
docker run --rm -it \
    -p 88:80 \
    -p 443:443 \
    -v `pwd`/httpd.conf:/etc/httpd/conf/httpd.conf \
    -v `pwd`/certs:/etc/httpd/certs \
    -v `pwd`/logs:/var/log/httpd \
    ${image}:${tag}
```


