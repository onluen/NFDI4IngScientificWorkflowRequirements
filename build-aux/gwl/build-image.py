'''
Bootstraps a docker image with the prerequisites to execute the
`simple_use_case` of the NFDI4Ing SIG Workflowtools with the workflow management
language extension (`gwl`) for GNU Guix (`guix`).

`guix` and `docker` must be available in the hosting operating system.

The build process requires both ~8 Gb RAM and disk space, since `paraview` is
not yet available in the upstream guix repository at the time of this writing.

# Implementation notes

`guix` is able to create docker images. Both `guix pack` and `guix system`
create images, but neither of them qualifies as is for use with the `gwl` in
github actions. The main obstacle is the dependency of the `guix-daemon` on
isolation features for its builds. These isolation features are not available in
unprivileged `docker` containers.

That is the reason why a docker image is create manually from scratch. In
`stage0` a base guix installation image is created from guix itself. `stage1`
will configure the system and install a specific guix revision to guarantee
reproducability. In `stage2` the `simple_use_case` workflow is prepared and all
required packages are installed. The `stage2` image can be used in
github actions.
'''

import os, pathlib, subprocess, textwrap


datadir = (pathlib.Path(__file__) / '../..').resolve()
container_env = (
    'HOME=/root LANG=en_US.UTF-8 '
    'PATH=/root/.config/guix/current/bin:/root/.guix-profile/bin '
    'GUIX_PACKAGE_PATH=/packages GUIX_LOCPATH=/root/.guix-profile/lib/locale '
    'GUIX_EXTENSIONS_PATH=/root/.guix-profile/share/guix/extensions'
)


def build_guix_stage0(target_image, import_options=()):
    image_path = pathlib.Path(subprocess.run(
        (
            'guix', 'pack',
            '--localstatedir', '--profile-name=guix-profile',
            '--symlink=/root/.guix-profile=/',
            'my-glibc-utf8-locales', 'coreutils', 'bash',
            'net-base', 'nss-certs', 'guix',
        ),
        env={**os.environ, 'GUIX_PACKAGE_PATH': datadir / 'docker'},
        stdout=subprocess.PIPE, check=True,
    ).stdout.decode().strip())

    subprocess.run(
        ('docker', 'import', *import_options, '-', target_image),
        stdin=image_path.open('rb'), check=True,
    )


def build_guix_stage(
    source_image, target_image, script, create_options=(), commit_options=(),
    commit=True,
):
    container = subprocess.run(
        (
            'docker', 'container', 'create', '--privileged', *create_options,
            source_image,
            'guix-daemon', '--cores=4', '--build-users-group=guixbuild',
        ),
        stdout=subprocess.PIPE, check=True,
    ).stdout.decode().strip()

    try:
        subprocess.run(('docker', 'container', 'start', container), check=True)
        subprocess.run(
            ('docker', 'exec', '-i', container, 'bash'),
            input=script.encode(), check=True
        )
        subprocess.run(('docker', 'stop', '-t', '0', container), check=True)
        if commit:
            subprocess.run(
                ('docker', 'commit', *commit_options, container, target_image),
                check=True,
            )
    finally:
        if commit:
            subprocess.run(
                ('docker', 'container', 'rm', '-f', container), check=True
            )

build_guix_stage0(
    'sigwftools-stage0', import_options=('-c', f'ENV {container_env}'),
)

build_guix_stage(
    'sigwftools-stage0', 'sigwftools-stage1',
    textwrap.dedent('''
    set -e
    mkdir /tmp /packages

    # Setup bare minimum system configuration files, necessary to build guix
    # packages.
    cat << === > /etc/passwd
    root:x:0:0::/root:/bin/bash
    guixbuilder0:x:1:1::/tmp:/usr/sbin/nologin
    ===
    cat << === > /etc/group
    root:x:0:root
    guixbuild:x:1:guixbuilder0
    ===
    cat << === > /etc/nsswitch.conf
    passwd:         compat
    group:          compat
    shadow:         compat
    hosts:          dns files
    networks:       files
    ethers:         files
    protocols:      files
    rpc:            files
    services:       files
    ===
    ln -s /root/.guix-profile/bin /bin
    ln -s /root/.guix-profile/etc/ssl /etc/ssl
    ln -s /root/.guix-profile/etc/services /etc/services

    # Copy custom packages and authorize substitutes.
    cp /data/build-aux/gwl/sigwftools.scm /packages
    guix archive --authorize < /root/.guix-profile/share/guix/ci.guix.gnu.org.pub
    guix archive --authorize < /root/.guix-profile/share/guix/bordeaux.guix.gnu.org.pub

    # Now that we have a bare minimum guix setup, pull a specific guix version.
    guix pull --commit=8f0d45ccac3f6cee69eba8de5e4ae5e5555f1a3d
    # Drop bootstrap guix from .guix-profile and update packages.
    rm /root/.guix-profile
    hash guix
    guix package -r guix
    guix package -u

    # Cleanup stuff.
    guix pull -d
    guix package -d
    guix gc
    '''),
    create_options=(f'--volume={datadir}:/data',),
    commit_options=('-c', f'ENV {container_env}'),
)


build_guix_stage(
    'sigwftools-stage1', 'sigwftools-stage2',
    textwrap.dedent('''
    set -e
    guix package -i gwl
    guix gc
    cd /data/simple_use_case
    guix workflow run -p gwl/workflow.w
    '''),
    create_options=(f'--volume={datadir}:/data',),
    commit_options=('-c', f'ENV {container_env}'),
)
