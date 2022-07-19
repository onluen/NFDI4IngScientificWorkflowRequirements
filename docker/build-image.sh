set -e

IMAGE_SYMLINKS="-S /bin=/bin -S /etc/services=/etc/services -S /etc/ssl=/etc/ssl\
 -S /share=/share"
IMAGE_PACKAGES="guix gwl gzip bash coreutils net-base nss-certs openssh git bind:utils strace inetutils"

IMAGE_PATH=$(GUIX_PACKAGE_PATH=$(dirname ${BASH_SOURCE[0]}) guix pack $IMAGE_SYMLINKS $IMAGE_PACKAGES)
docker import - sigwftools-gwl-base < $IMAGE_PATH
docker build ../docker -f ../docker/nfdi.dockerfile -t sigwftools-gwl
