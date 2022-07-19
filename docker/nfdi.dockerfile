FROM sigwftools-gwl-base
RUN mkdir /root
RUN echo -e "root:x:0:0::/root:/bin/bash\nguixbuilder0:x:1:1::/tmp:/usr/sbin/nologin" > /etc/passwd
RUN echo -e "root:x:0:root\nguixbuild:x:1:guixbuilder0" > /etc/group
COPY nsswitch.conf /etc
RUN mkdir /tmp /packages
COPY nfdi.scm /packages
RUN guix archive --authorize < /share/guix/ci.guix.gnu.org.pub
RUN guix archive --authorize < /share/guix/bordeaux.guix.gnu.org.pub
ENV HOME=/root GUIX_PACKAGE_PATH=/packages GUIX_EXTENSIONS_PATH=/share/guix/extensions
# Install all required tools (prepare the workflow).
#RUN bash -c "guix-daemon --cores 4 --build-users-group=guixbuild &; env -C /data guix workflow run -p gwl/workflow.w"