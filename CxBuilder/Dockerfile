FROM        progrium/busybox
MAINTAINER  Fletcher Nichol <fnichol@nichol.ca>

RUN opkg-install uhttpd
RUN printf '#!/bin/sh\nset -e\n\nchmod 755 /www\nexec /usr/sbin/uhttpd $*\n' > /usr/sbin/run_uhttpd && chmod 755 /usr/sbin/run_uhttpd

EXPOSE 8000
VOLUME /www

ENTRYPOINT ["/usr/sbin/run_uhttpd", "-f", "-p", "8000", "-h", "/www"]
