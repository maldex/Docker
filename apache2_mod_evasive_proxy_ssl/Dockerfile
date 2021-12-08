 # dockerfile for apache2_mod_evasive_proxy_ssl
FROM        fedora:35
RUN         dnf update -y

# install apache (note: mod_evasive included in fedora. other rh-clones: install epel-release)
RUN         dnf install -y httpd mod_evasive mod_security mod_proxy_html mod_ssl openssl whois

# copy the functions-script
COPY        apache.functions.sh /root/apache.functions.sh
COPY        CreateCert.sh /CreateCert.sh
RUN         chmod +x /root/apache.functions.sh /CreateCert.sh

# do something
RUN         /root/apache.functions.sh apache_install_all
RUN         /root/apache.functions.sh apache_minimum_modules
#RUN         /root/apache.functions.sh apache_default_vhost
RUN         /root/apache.functions.sh apache_lil_tweaks
RUN         /root/apache.functions.sh apache_enable_proxy
RUN         /root/apache.functions.sh apache_enable_balancer
RUN         /root/apache.functions.sh apache_enable_ssl
COPY        httpd.conf /etc/httpd/conf/httpd.conf
RUN         mkdir /etc/httpd/certs
RUN         /CreateCert.sh --chdir -C AQ -ST "Ross Archipelago - McMurdo Landfill" -L "Mt. Erebus" -O "Hephaestos Skunk Works" -OU "Cert Authority" -E hephaistos@olymp -CN Authority 
RUN         /CreateCert.sh --chdir -C AQ -ST "Ross Archipelago - McMurdo Dump" -L "Mt. Terror" -O "Gollum Jewlery Ltd." -OU "Smeagol's Dept." -E deagol@mordor -CA Authority -CN default
RUN         /CreateCert.sh --chdir -C AQ -ST "Ross Archipelago - McMurdo Dump" -L "Mt. Terror" -O "Hades Notary Inc." -OU "Plutus Accouting Dept." -E kerberos@styx -CA Authority -CN paperless \
               -AN paperless.intranet -AN paperless.internal -AN paperless.private -AN paperless.corp -AN paperless.home -AN paperless.lan -AN paperless.local
                    
# assume persistent storage
#VOLUME  /etc/httpd/conf/httpd.conf
#VOLUME  /var/log/httpd/
 
# assume exposed ports
EXPOSE  80
EXPOSE  443

# include this very file into the image for documentation
COPY    Dockerfile /
 
# standart run inside
COPY        run.sh /run.sh
RUN         chmod +x /run.sh
CMD         ["/run.sh"]
