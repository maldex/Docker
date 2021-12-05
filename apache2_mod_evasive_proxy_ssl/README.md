# Alright i'm not sure i understand the issue. My own apache container works on Fedora, but not on Alpine!

## scenario
Run the following:
```bash
docker run --rm -it -p 60080:80 -p 60443:443 maldex/apache2_mod_evasive_proxy_ssl:20211205
```
- on Fedora: alright, stays up & running and ports are connecting as expected (use private/anonymous mode of browser)
- on Alpine, it exists with "AH02324: A resource shortage or other unrecoverable failure was encountered before any child process initialized successfully... httpd is exiting!"

## expectations
- Upon hitting http://host-ip:60080, you should see an empty page titled "index of /" (default vhos config)
- Upon hitting http://host-ip:60443, you should be presented with an Antarctic CA and Cert, and be weirdly redirected to a weird http-non-ssl site. (https->http redirect on default-vhost)

## issue
running this on a (virtual machine) with [Alpine Linux Docker installation](AlpineLinux-Manual.COPY_OF_20211204.md) termintes with
```
docker run --rm -it -p 60080:80 -p 60443:443 maldex/apache2_mod_evasive_proxy_ssl:20211205
...
...
[Sat Dec 04 23:50:49.083365 2021] [mpm_event:notice] [pid 15:tid 15] AH00489: Apache/2.4.51 (Fedora) OpenSSL/1.1.1l configured -- resuming normal operations
[Sat Dec 04 23:50:49.083396 2021] [mpm_event:info] [pid 15:tid 15] AH00490: Server built: Oct 12 2021 00:00:00
[Sat Dec 04 23:50:49.083416 2021] [core:notice] [pid 15:tid 15] AH00094: Command line: 'httpd -D FOREGROUND'
[Sat Dec 04 23:50:49.084909 2021] [mpm_event:alert] [pid 18:tid 18] (1)Operation not permitted: AH00480: apr_thread_create: unable to create worker thread
[Sat Dec 04 23:50:49.085386 2021] [mpm_event:alert] [pid 17:tid 17] (1)Operation not permitted: AH00480: apr_thread_create: unable to create worker thread
[Sat Dec 04 23:50:49.089712 2021] [mpm_event:alert] [pid 19:tid 19] (1)Operation not permitted: AH00480: apr_thread_create: unable to create worker thread
[Sat Dec 04 23:50:51.085606 2021] [mpm_event:alert] [pid 15:tid 15] AH02324: A resource shortage or other unrecoverable failure was encountered before any child process initialized successfully... httpd is exiting!
/run.sh                 ]]]]]]]] exit with 0 [[[[[[[[
```

## preliminary assumption: alpine linux???

---
---
---


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

### publish image
```bash
docker image tag ${image}:${tag} ${image}:latest
docker push ${image}:${tag} ${image}:latest
docker push ${image}:${tag}
docker push ${image}:latest
```
