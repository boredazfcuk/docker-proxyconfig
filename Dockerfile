FROM alpine:3.14
MAINTAINER boredazfcuk
ARG app_dependencies="nginx tzdata wget"
ENV home_dir="/var/www/proxy"

RUN echo "$(date '+%d/%m/%Y - %H:%M:%S') | ***** BUILD STARTED FOR PROXYCONFIG *****" && \
echo "$(date '+%d/%m/%Y - %H:%M:%S') | Install application dependencies" && \
   apk add --no-cache --no-progress ${app_dependencies} && \
echo "$(date '+%d/%m/%Y - %H:%M:%S') | ***** BUILD COMPLETE *****"

COPY nginx.conf /etc/nginx/nginx.conf
COPY --chmod=0755 entrypoint.sh /usr/local/bin/entrypoint.sh
COPY --chmod=0755 healthcheck.sh /usr/local/bin/healthcheck.sh

HEALTHCHECK --start-period=10s --interval=1m --timeout=10s \
  CMD /usr/local/bin/healthcheck.sh

VOLUME "${home_dir}"

WORKDIR "${home_dir}"

ENTRYPOINT "/usr/local/bin/entrypoint.sh"
