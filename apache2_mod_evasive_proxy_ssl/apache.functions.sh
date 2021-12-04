#!/bin/bash

### 
# this document describes a common semi-automated apache installation on CentOS/Redhat 7+. It's grouped into functions:
#   1.  function 'apache_install_all'
#   2.  function 'apache_minimum_modules'
#   3.  function 'apache_default_vhost'
#   4.  function 'apache_lil_tweaks'
#   5.  function 'apache_enable_proxy'
#   6.  function 'apache_enable_balancer'
#   7.  function 'apache_enable_ssl'

# keep your C:\Windows\System32\drivers\etc\hosts handy

certpath=/etc/httpd/certs

cd /etc/httpd 2> /dev/null

function _apache_module_enabler() {
    pushd /etc/httpd >/dev/null
    echo ">>>> enable apache module '$1'"
    sed -i '/'$1'/s/^#;//' conf.modules.d/*
    popd >/dev/null
}

function apache_install_all() {    
    #echo ">>> enable epel-repo (for at least mod_evasive)"
    #yum install -y epel-release
     
    echo ">>> install apache and modules"
    dnf install -y httpd mod_evasive mod_security mod_proxy_html mod_ssl openssl whois
     
    echo ">>> create a copy of default config"
    tar -zcf ~/http-orig.tgz /var/www /etc/httpd     
     
    cd /etc/httpd
    echo ">>> whyever, mod_evasive end up in the wrong directory"  # TODO: check _evasive and _security config path
    mv -v conf.d/mod_evasive.conf conf.modules.d/
    mv -v conf.d/mod_security.conf conf.modules.d/
        
    sed -i 's/DOSHashTableSize .*/DOSHashTableSize 8193/g' conf.modules.d/mod_evasive.conf
    sed -i 's/DOSPageCount .*/DOSPageCount 10/g' conf.modules.d/mod_evasive.conf
    sed -i 's/DOSPageInterval .*/DOSPageInterval 1/g' conf.modules.d/mod_evasive.conf
    sed -i 's/DOSSiteCount .*/DOSSiteCount 100/g' conf.modules.d/mod_evasive.conf
    sed -i 's/DOSSiteInterval .*/DOSSiteInterval 1/g' conf.modules.d/mod_evasive.conf
    sed -i 's/DOSBlockingPeriod .*/DOSBlockingPeriod 3/g' conf.modules.d/mod_evasive.conf
    #sed -i 's/#DOSSystemCommand .*/DOSSystemCommand "date +\%Y.\%m.\%d-\%H:\%M:\%S.\%N \%s >> /var/log/http/evasive.log"/g' conf.modules.d/mod_evasive.conf # TODO tofix

    echo ">>> function ${FUNCNAME[0]} done"
}

function apache_minimum_modules() {
    cd /etc/httpd
    # minimum modules
    MODULES="systemd_module access_compat_module actions_module alias_module allowmethods_module auth_basic_module auth_digest_module"
    MODULES+=" authn_anon_module authn_core_module authn_file_module authz_core_module authz_groupfile_module authz_host_module" 
    MODULES+=" authz_user_module data_module deflate_module dir_module echo_module env_module expires_module ext_filter_module filter_module"
    MODULES+=" headers_module include_module log_config_module logio_module mime_magic_module mime_module negotiation_module remoteip_module"
    MODULES+=" reqtimeout_module rewrite_module setenvif_module substitute_module unixd_module version_module"
    MODULES+=" vhost_alias_module log_debug_module log_debug_module mod_slotmem_shm"
    #MODULES+=" status_module dumpio_module cache_disk_module cache_module"
     
    echo ">>> disable ALL module config" # essentially comment-out everything
    sed -i '/^#;/!s/^/#;/' conf.d/autoindex.conf
    sed -i '/^#;/!s/^/#;/' conf.d/userdir.conf
    sed -i '/^#;/!s/^/#;/' conf.d/welcome.conf
    sed -i '/^#;/!s/^/#;/' conf.d/ssl.conf
    sed -i '/^#;/!s/^/#;/' conf.modules.d/*
          
    echo ">>> re-enable MPM and CGI" # essentially re-enabling basic apache functionality
    sed -i 's/^#;//' conf.modules.d/00-mpm.conf
    sed -i 's/^#;//' conf.modules.d/01-cgi.conf
    sed -i 's/^#;//' conf.modules.d/mod_evasive.conf
     
    echo ">>> re-enable minimal requiered modules"
    for module in ${MODULES}; do
        _apache_module_enabler ${module}
    done

    echo ">>> function ${FUNCNAME[0]} done"
}

function apache_default_vhost(){
    LOGFORMAT='"%a %h %l %u %t \"%r\" %>s %O \"%{Referer}i\" \"%{User-Agent}i\""'
    SERVERADMIN=this.admin.is@not.configured
    SERVERNAME="default-vhost-on-`hostname -s`-at-`date +%Y%m%d-%H%M%S`"

    echo ">>> configure ServerAdmin and Servername, and default vhost(s)"
    sed -i 's/^ServerAdmin .*/ServerAdmin '"${SERVERADMIN}"'/g' conf/httpd.conf
    sed -i 's/^#ServerName .*/ServerName '"${SERVERNAME}"'/g' conf/httpd.conf
    sed -i 's/^EnableSendfile .*/EnableSendfile off/' conf/httpd.conf # when serving from nfs
        
    # disable conf.d/ include at this point
    sed -i '/^IncludeOptional.*conf.d\/\*.conf/s/^/# -- first the default vhost here, then include custom vhosts -- # /' conf/httpd.conf
     
    # insert custom properties, and the default vhost
    echo "# additional custom settings
ServerSignature              Off
ServerTokens                 Prod
 
UseCanonicalName             Off
DeflateCompressionLevel      9
HostnameLookups              on
RemoteIPHeader               X-Forwarded-For
LogFormat                    ${LOGFORMAT} proxy
#ErrorLog                    \"| /usr/bin/logger -t httpd-default -i -p local5.error\"
#CustomLog                   \"| /usr/bin/logger -t httpd-default -i -p local5.notice\"  proxy
 
# increase these values for your vhost
RequestHeader                set Connection close
LimitRequestBody             32
LimitXMLRequestBody          32
Timeout                      1
Options                      -ExecCGI -FollowSymLinks -Indexes -MultiViews
 
# DEFAULT VHOST: if no other ServerName or ServerAlias matches to the requested url

<VirtualHost *:80> # default port 80 vhost
    <Location \"/\">
        Require ip           127.0.0.0/8 10.0.0.0/8 172.16.0.0/12 192.168.0.0/16
    </Location>
    <IfModule status_module>
        <Location /server-status>
            SetHandler server-status
        </Location>
    </IfModule>
    <IfModule proxy_balancer_module>
        <Location \"/balancer-manager\">
            SetHandler balancer-manager
        </Location>
    </IfModule>
    DocumentRoot /var/www/html
</VirtualHost>
 
<IfModule ssl_module>
    Listen                       443         https
    SSLPassPhraseDialog          exec:/usr/libexec/httpd-ssl-pass-dialog
    SSLSessionCache              shmcb:/run/httpd/sslcache(512000)
    SSLSessionCacheTimeout       300
    SSLRandomSeed                startup     file:/dev/urandom  2048
    SSLRandomSeed                connect     file:/dev/urandom  2048
    SSLCryptoDevice              builtin
     
    <VirtualHost *:443> # default port 443 vhost
        SSLEngine                on
        SSLProtocol              all -SSLv2 -SSLv3 -TLSV1
        SSLCipherSuite           EECDH+AESGCM:EDH+AESGCM:AES256+EECDH:AES256+EDH
        SSLHonorCipherOrder      on
        SSLCertificateChainFile  /etc/httpd/certs/default.ca-crt
        SSLCertificateFile       /etc/httpd/certs/default.crt
        SSLCertificateKeyFile    /etc/httpd/certs/default.key
        # default ssl-vhost: redirect back to the non-ssl variant of your request
        RewriteEngine            on
        RewriteCond              %{HTTPS}    on
        RewriteRule              (.*)        http://%{HTTP_HOST}%{REQUEST_URI} [R=temp,L]
    </VirtualHost>
</IfModule>
 
IncludeOptional              conf.d/*.conf
" >> conf/httpd.conf
     
    echo ">>> creating default /var/www/html/index.html"
    echo "<title>{HOSTNAME}</title>
    <h1>default vhost on {HOSTNAME} </h1><br>
    Apache: <a href=/server-status>server-status</a> <br>" >> /var/www/html/index.html

    echo "GOTO HTTP://`hostname -f`"
    echo ">>> function ${FUNCNAME[0]} done"
}

function apache_lil_tweaks() {
    cd /etc/httpd
    _apache_module_enabler mod_autoindex
    _apache_module_enabler status_module
    # lil nice-ness
    sed -i 's/FancyIndexing/FancyIndexing NameWidth=*/g' conf.d/autoindex.conf
    sed -i 's/^#;//g' conf.d/autoindex.conf

    echo ">>> function ${FUNCNAME[0]} done"
}

function apache_enable_proxy(){
    _apache_module_enabler proxy_module
    _apache_module_enabler proxy_http_module
    _apache_module_enabler proxy_html_module
    echo ">>> placing demo-vhost into conf.d/vhost-simple-proxy.conf"
    echo "# sample vhost for simple proxy
<VirtualHost *:80>
    ServerName                   simple.`hostname -f`
    ServerAlias                  simple.`hostname -s` simple.localhost simple.your.domain
    
    # https://httpd.apache.org/docs/2.4/mod/mod_proxy.html
    ProxyRequests                Off
    ProxyVia                     Off

    ProxyPass                    /               http://10.86.33.23:8090/
    ProxyPassReverse             /               http://10.86.33.23:8090/
    
    # same through balancer
    #ProxyPass                    /balancer-manager       !
    #<Location /balancer-manager>
    #    SetHandler               balancer-manager
    #</Location>
    #
    #ProxyPass                     /              balancer://simple-backend/
    #ProxyPassReverse              /              balancer://simple-backend/
    #
    #<Proxy balancer://simple-backend>
    #    BalancerMember           http://10.86.33.23:8090
    #</Proxy>
</VirtualHost> " > conf.d/vhost-simple-proxy.conf

    echo ">>> function ${FUNCNAME[0]} done"
}

function apache_enable_balancer(){
    _apache_module_enabler proxy_balancer_module
    _apache_module_enabler slotmem_plain_module
    _apache_module_enabler slotmem_shm_module
    _apache_module_enabler socache_shmcb_module
    _apache_module_enabler xml2enc_module
    _apache_module_enabler lbmethod_bybusyness_module
    _apache_module_enabler lbmethod_byrequests_module
    _apache_module_enabler lbmethod_bytraffic_module
    _apache_module_enabler lbmethod_heartbeat_module
    echo ">>> TODO: edit conf.d/vhost-simple-proxy.conf"
    echo ">>> TODO: restart your apache   'httpd -S && systemctl restart httpd; tail -fn0 /var/log/httpd/*_log'"
    echo "GOTO HTTP://simple.your.domain/balancer-manager"
    
    echo ">>> function ${FUNCNAME[0]} done"
}

function apache_enable_ssl(){
    echo ">>> create some self-signed certificates for default vhosts"
#    if [ ! -e /etc/httpd/certs ]; then 
#        mkdir /etc/httpd/certs
#        echo ">>> created an Authority (passwords won't matter and won't be used further, just type asdfasdf)"
#        CreateSelfSignedAuthority
#        echo ">>> created an Certificate (passwords won't matter and won't be used further, just type asdfasdf)"
#        CreateSelfSignedCertificate
#    fi

    _apache_module_enabler ssl_module 
    _apache_module_enabler socache_shmcb_module

    echo "GOTO HTTPS://`hostname -f`"
    echo ">>> function ${FUNCNAME[0]} done"
}

function apache_mkComplexProxy() {
    CreateSelfSignedCertificate complex.your.domain
    echo "# # http-to-https redirect vhost
<VirtualHost *:80>
        ServerName              complex.localhost
        ServerAlias             complex.localhost complex.localhost complex.your.domain

        # push to https
        RewriteEngine           On
        RewriteRule             (.*)   https://%{HTTP_HOST}%{REQUEST_URI}
</VirtualHost>

# THE vhost that counts
<VirtualHost *:443>
# ssl/tls
        SSLEngine               on
        SSLProtocol             all -SSLv2 -SSLv3 -TLSV1
        SSLHonorCipherOrder     on
        SSLCipherSuite          EECDH+AESGCM:EDH+AESGCM:AES256+EECDH:AES256+EDH
        SSLCertificateChainFile /etc/httpd/certs/default.ca-crt
        SSLCertificateFile      /etc/httpd/certs/complex.your.domain.crt
        SSLCertificateKeyFile   /etc/httpd/certs/complex.your.domain.key

# globals
        ServerName              complex.localhost
        ServerAlias             complex.localhost complex.localhost complex.your.domain
        ErrorLog                logs/proxy-confluence_error_log
        CustomLog               logs/proxy-confluence_access_log combined

        LimitRequestBody        104857600
        LimitXMLRequestBody     104857600
        Timeout                 300
        KeepAlive               On
        KeepAliveTimeout        0

# remote management
        <IfModule status_module>
                ProxyPass               /server-status          !
                <Location               /server-status>
                        SetHandler      server-status
                        Require ip      127.0.0.0/8 10.0.0.0/8 172.16.0.0/12 192.168.0.0/16
                </Location>
        </IfModule>
        <IfModule proxy_balancer_module>
                ProxyPass               /balancer-manager       !
                <Location               /balancer-manager>
                        SetHandler      balancer-manager
                        Require ip      127.0.0.0/8 10.0.0.0/8 172.16.0.0/12 192.168.0.0/16
                </Location>
        </IfModule>

# reverse proxy settings
        # https://httpd.apache.org/docs/2.4/mod/mod_proxy.html
        ProxyRequests           Off
        ProxyVia                Off
        ProxyPreserveHost       On
        SSLProxyEngine          On

# here the application-specific config begins
        <Location /synchrony>
            Require all granted
            RewriteEngine on
            RewriteCond %{HTTP:UPGRADE} ^WebSocket$ [NC]
            RewriteCond %{HTTP:CONNECTION} Upgrade$ [NC]
            RewriteRule .* ws://127.0.0.2:8091%{REQUEST_URI} [P]
        </Location>

# reverse-proxy mappings
        ProxyPass           /           balancer://backend-confluence/tiles
        ProxyPassReverse    /           balancer://backend-confluence/tiles

# reverse-proxy-backends
        # proxy-sided add cookie to map back-end member server (ROUTEID=route)
        Header                  add Set-Cookie  "ROUTEID=.%{BALANCER_WORKER_ROUTE}e; path=/" env=BALANCER_ROUTE_CHANGED
        <Proxy balancer://backend-confluence>
                ProxySet        stickysession=ROUTEID
                ProxySet        failonstatus=500,501,502,503
                ProxySet        lbmethod=byrequests
                BalancerMember  http://127.0.0.2:8080 route=instance1 flushpackets=On  keepalive=On  connectiontimeout=5  timeout=300  ping=3  retry=30
        </Proxy>
</VirtualHost>
" > conf.d/vhost-complex-proxy.conf
    echo ">>> function ${FUNCNAME[0]} done"
}


## increase semaphores - apache mod_proxy reports 'no space left on device'
## see current settings / limits
#ipcs -l
# 
## clean up last semaphores
#ipcrm sem $(ipcs -s | grep apache | awk '{print$2}')
# 
#echo ">>> increase semaphores
#kernel.msgmni = 1024
#kernel.sem = 1500 256000 32 4096
#">> /etc/sysctl.conf
# 
#sysctl -p

function _apache_add_sshtunnel(){
# https://nurdletech.com/linux-notes/ssh/via-http.html     http://dag.wiee.rs/howto/ssh-http-tunneling/
    _apache_module_enabler mod_proxy
    _apache_module_enabler mod_proxy_connect
    _apache_module_enabler mod_proxy_http

# add something like the below to your DEFAULT VHOST
# ohther vhost wont work 
echo "
    ProxyRequests on
    ProxyVia block
    AllowCONNECT 22 996
    # Proxy: Deny all proxying by default
    <Proxy *>                      Require all denied  </Proxy>

    # but enable the following
    <Proxy 127.0.0.3>              Require all granted  </Proxy>
    <Proxy server123>              Require all granted  </Proxy>
"

# proxytunnel -p 192.168.118.99:80 -d 127.0.0.3:22 -v
# proxytunnel -p 192.168.118.99:80 -d server123:996 -v
}

if [ ! -z "$1" ]; then 
    echo "calling function '$1'"
    $1 $2
fi