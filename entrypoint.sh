#!/bin/ash

##### Functions #####
Initialise(){
   lan_ip="$(hostname -i)"
   echo -e "\n"
   echo "$(date '+%c') INFO:    ***** Configuring httpd container launch environment *****"
   echo "$(date '+%c') INFO:    $(cat /etc/*-release | grep "PRETTY_NAME" | sed 's/PRETTY_NAME=//g' | sed 's/"//g')"
   echo "$(date '+%c') INFO:    Listening address: ${lan_ip}:81"
   echo "$(date '+%c') INFO:    Home directory: ${home_dir}"
   echo "$(date '+%c') INFO:    Proxy server IP: ${host_ip_address}"
   if [ ! -f "${home_dir}/local_domains.txt" ] || [ ! -s "${home_dir}/local_domains.txt" ]; then
      echo "$(grep search /etc/resolv.conf | cut -d' ' -f2)" > "${home_dir}/local_domains.txt"
   fi
   echo "$(date '+%c') INFO:    Local domains list:"
   for local_domain in $(cat "${home_dir}/local_domains.txt"); do
      echo "$(date '+%c') INFO:       - ${local_domain}"
   done
   if [ ! -f "${home_dir}/direct_domains.txt" ]; then
      touch "${home_dir}/direct_domains.txt"
   fi
   if [ -s "${home_dir}/direct_domains.txt" ]; then
      sort -fibu -o "${home_dir}/direct_domains.txt" "${home_dir}/direct_domains.txt"
      sed -i '/^$/d' "${home_dir}/direct_domains.txt"
      echo "$(date '+%c') INFO:    Direct domains list:"
      for direct_domain in $(cat "${home_dir}/direct_domains.txt"); do
         echo "$(date '+%c') INFO:       - ${direct_domain}"
      done
   else
      echo "$(date '+%c') INFO:    Direct domains list file empty, nothing to load"
   fi
   if [ ! -f "${home_dir}/blocked_domains.txt" ]; then
      touch "${home_dir}/blocked_domains.txt"
   fi
   if [ -s "${home_dir}/blocked_domains.txt" ]; then
      sort -fibu -o "${home_dir}/blocked_domains.txt" "${home_dir}/blocked_domains.txt"
      sed -i '/^$/d' "${home_dir}/blocked_domains.txt"
      echo "$(date '+%c') INFO:    Blocked domains list:"
      for blocked_domain in $(cat "${home_dir}/blocked_domains.txt"); do
         echo "$(date '+%c') INFO:       - ${blocked_domain}"
      done
   else
      echo "$(date '+%c') INFO:    Blocked domains list file empty, nothing to load"
   fi
   if [ ! -L "/var/log/nginx/access.log" ]; then
      echo "$(date '+%c') INFO:    Configure access log to log to stdout"
      if [ -f "/var/log/nginx/access.log" ]; then rm "/var/log/nginx/access.log"; fi
      ln -sf "/dev/stdout" "/var/log/nginx/access.log"
   fi
   if [ ! -L "/var/log/nginx/error.log" ]; then
      echo "$(date '+%c') INFO:    Configure access log to log to stderr"
      if [ -f "/var/log/nginx/error.log" ]; then rm "/var/log/nginx/error.log"; fi
      ln -sf "/dev/stderr" "/var/log/nginx/error.log"
   fi
}

LanLogging(){
   echo "$(date '+%c') INFO:    Exclude networks from logging: ${lan_ip}"
   {
      echo 'map $remote_addr $ignore_lan_ip {'
      echo "   ${lan_ip} 0;"
      echo '   default 1;'
      echo '}'
   } > /etc/nginx/logging.conf
}

Configure(){
   echo "$(date '+%c') INFO:    Configure mime types"
   {
      echo 'types {'
         echo '   text/html                           html;'
         echo '   text/plain                          txt;'
         echo '   application/x-ns-proxy-autoconfig   pac;'
         echo '   application/x-ns-proxy-autoconfig   dat;'
         echo '   application/x-ns-proxy-autoconfig   da;'
         echo '   application/x-x509-ca-cert          der pem cer crt;'
      echo '}'
   } > "/etc/nginx/mime.types"
   echo "$(date '+%c') INFO:    Building proxy.pac file"
   chown -R squid:squid "${home_dir}"
   {
      echo 'function FindProxyForURL(url, host) {'
      echo
      echo '   // Configure destinations'
      echo "   squidproxy = \"PROXY ${host_ip_address}:3128\";"
      echo '   blackhole = "PROXY 127.0.0.1:3131";'
      echo '   direct = "DIRECT";'
      echo
      echo '   // Convert URLs to lowercase due to case-sensitive matching'
      echo '   url = url.toLowerCase();'
      echo '   host = host.toLowerCase();'
      echo
      echo '   // Proxy bypass: Localhost'
      echo '   if ('
      echo '      shExpMatch(host, "localhost") ||'
      echo '      shExpMatch(host, "*.local")'
      echo '      ) return direct;'
      echo
      echo '   // Proxy bypass: Local network machine names'
      echo '   if ('
      echo '      isPlainHostName(host)'
      echo '      ) return direct;'
      if [ -s "${home_dir}/local_domains.txt" ]; then
         echo
         echo '   // Proxy bypass: Local domains'
         local_domains="$(cat "${home_dir}/local_domains.txt")"
         local_domains_line_terminator=" ||"
         local_domains_counter=0
         local_domains_total="$(echo -n "${local_domains}" | grep -c '^')"
         echo '   if ('
         for local_domain in ${local_domains}; do
            local_domains_counter=$((local_domains_counter + 1))
            if [ "${local_domains_counter}" -eq "${local_domains_total}" ]; then unset local_domains_line_terminator; fi
            echo "      dnsDomainIs(host, \"${local_domain}\")${local_domains_line_terminator}"
         done
         echo '      ) return direct;'
      fi
      if [ -s "${home_dir}/direct_domains.txt" ]; then
         echo
         echo '   // Proxy bypass: Remote domains'
         direct_domains="$(cat "${home_dir}/direct_domains.txt")"
         direct_domains_line_terminator=" ||"
         direct_domains_counter=0
         direct_domains_total="$(echo -n "$direct_domains" | grep -c '^' | awk '{print $1}')"
         echo '   if ('
         for direct_domain in ${direct_domains}; do
            direct_domains_counter=$((direct_domains_counter + 1))
            if [ "${direct_domains_counter}" -eq "${direct_domains_total}" ]; then unset direct_domains_line_terminator; fi
            echo "      dnsDomainIs(host, \"$(echo ${direct_domain} | awk '{print $1}')\") || shExpMatch(host, \"*.$(echo ${direct_domain} | awk '{print $1}')\")${direct_domains_line_terminator}"
         done
         echo '      ) return direct;'
      fi
      if [ -s "${home_dir}/blocked_domains.txt" ]; then
         echo
         echo '   // Proxy blackhole: Blocked domains'
         echo '   if ('
         blocked_domains="$(cat "${home_dir}/blocked_domains.txt")"
         blocked_domains_line_terminator=" ||"
         blocked_domains_counter=0
         blocked_domains_total="$(echo -n "$blocked_domains" | grep -c '^')"
         for blocked_domain in ${blocked_domains}; do
            blocked_domains_counter=$((blocked_domains_counter + 1))
            if [ "${blocked_domains_counter}" -eq "${blocked_domains_total}" ]; then unset blocked_domains_line_terminator; fi
            echo "      dnsDomainIs(host, \"$(echo ${blocked_domain} | awk '{print $1}')\") || shExpMatch(host, \"*.$(echo ${blocked_domain} | awk '{print $1}')\")${blocked_domains_line_terminator}"
         done
         echo '      ) return blackhole;'
      fi
      echo
      echo '   // Proxy bypass: Non-routable networks'
      echo '   var resolved_ip = dnsResolve(host);'
      echo '   if ('
      echo '      isInNet(resolved_ip, "10.0.0.0", "255.0.0.0") ||'
      echo '      isInNet(resolved_ip, "127.0.0.0", "255.0.0.0") ||'
      echo '      isInNet(resolved_ip, "169.254.0.0", "255.255.0.0") ||'
      echo '      isInNet(resolved_ip, "172.16.0.0", "255.240.0.0") ||'
      echo '      isInNet(resolved_ip, "192.168.0.0", "255.255.0.0") ||'
      echo '      isInNet(resolved_ip, "198.18.0.0", "255.254.0.0") ||'
      echo '      isInNet(resolved_ip, "224.0.0.0", "240.0.0.0") ||'
      echo '      isInNet(resolved_ip, "240.0.0.0", "240.0.0.0")'
      echo '      ) return direct;'
      echo
      echo '   // Proxy bypass: Local Addresses'
      echo '   if (false) return direct;'
      echo
      echo '   // Proxy by traffic type'
      echo '   if ('
      echo '      url.substring(0, 5) == "http:" ||'
      echo '      url.substring(0, 6) == "https:"'
      echo "      ) return squidproxy; direct;"
      echo '   if ('
      echo '      url.substring(0,4) == "ftp" ||'
      echo '      url.substring(0,3) == "mms"'
      echo '      ) return direct;'
      echo
      echo '   // Proxy bypass: Not Classified'
      echo '   return direct;'
      echo '}'
   } >"${home_dir}/proxy.pac"
   if [ ! -L "${home_dir}/wpad.dat" ]; then
      echo "$(date '+%c') INFO:    Create wpad.dat link"
      cd "${home_dir}"
      ln -s "./proxy.pac" "wpad.dat"
      cd - >/dev/null
   fi
   if [ ! -L "${home_dir}/wpad.da" ]; then
      echo "$(date '+%c') INFO:    Create wpad.da link"
      cd "${home_dir}"
      ln -s "./proxy.pac" "wpad.da"
      cd - >/dev/null
   fi
   # echo "$(date '+%c') INFO:    Configure proxy address ${host_ip_address}:3128"
   # sed -i \
      # "s%return \"PROXY .*%return \"PROXY ${host_ip_address}:3128\"; \"DIRECT\"; }%" \
      # "${home_dir}/proxy.pac"
   echo "$(date '+%c') INFO:    Wait for Squid to come online..."
   while [ "$(nc -z squid 3128; echo $?)" -ne 0 ]; do
      echo "$(date '+%c') INFO:    Retry in 5 seconds"
      sleep 5
   done
   echo "$(date '+%c') INFO:    Create HTML holding page"
   {
      echo "<html>"
      echo "   <head/>"
      echo "   <title>Essential Proxy Server Files</title>"
      echo "   <body>"
      echo "      <br>Right-click to download<br>"
      echo "      <p>"
      if [ -f "${home_dir}/squid_ca_cert.pem" ]; then echo "      <a href=./squid_ca_cert.pem>Certification Authority Certificate - PEM</a><br>"; fi
      if [ -f "${home_dir}/squid_ca_cert.der" ]; then echo "      <a href=./squid_ca_cert.der>Certification Authority Certificate - DER</a><br>"; fi
      echo "<br>"
      if [ -f "${home_dir}/proxy.pac" ]; then echo "     <a href=./proxy.pac>proxy.pac</a><br>"; fi
      if [ -L "${home_dir}/wpad.dat" ]; then echo "      <a href=./wpad.dat>wpad.dat</a><br>"; fi
      echo "<br>"
      if [ -f "${home_dir}/local_domains.txt" ]; then echo "      <a href=./local_domains.txt>Locally accessed domains override list</a><br>"; fi
      if [ -f "${home_dir}/direct_domains.txt" ]; then echo "      <a href=./direct_domains.txt>Directly accessed domains override list</a><br>"; fi
      if [ -f "${home_dir}/blocked_domains.txt" ]; then echo "      <a href=./blocked_domains.txt>Blocked domains list</a><br>"; fi
      echo "   </p>"
      echo "   <body>"
      echo "</html>"
   } >"${home_dir}/index.html"
}

SetOwner(){
   echo "$(date '+%c') INFO:    Set owner of application files"
   chown -R squid:squid "${home_dir}"
}

LaunchNGINX(){
   echo "$(date '+%c') INFO:    ***** Configuration of NGINX container launch environment complete *****"
   if [ -z "${1}" ]; then
      echo "$(date '+%c') INFO:    Starting NGINX"
      exec $(which nginx)
   else
      exec "$@"
   fi
}

##### Script #####
Initialise
LanLogging
Configure
SetOwner
LaunchNGINX