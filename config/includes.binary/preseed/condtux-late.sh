#!/bin/sh
set -e

echo "[ Condtux ] Ejecutando post-instalación..."

echo "condtux" > /etc/hostname

cat > /etc/hosts <<'EOF'
127.0.0.1       localhost
127.0.1.1       condtux

::1             localhost ip6-localhost ip6-loopback
ff02::1         ip6-allnodes
ff02::2         ip6-allrouters
EOF

cat > /etc/issue <<'EOF'
Condtux Minimal Orange \n \l

EOF

cat > /etc/issue.net <<'EOF'
Condtux Minimal Orange
EOF

cat > /etc/condtux-release <<'EOF'
Condtux Minimal Orange - Debian Stable amd64
EOF

cat > /etc/os-release <<'EOF'
PRETTY_NAME="Condtux Minimal Orange"
NAME="Condtux"
VERSION="Minimal Orange"
VERSION_CODENAME=trixie
ID=condtux
ID_LIKE=debian
HOME_URL="https://github.com/jechugit/condtux-live-lab"
SUPPORT_URL="https://github.com/jechugit/condtux-live-lab/issues"
BUG_REPORT_URL="https://github.com/jechugit/condtux-live-lab/issues"
EOF

mkdir -p /etc/apt/sources.list.d
mkdir -p /etc/apt/preferences.d
mkdir -p /etc/apt/apt.conf.d

cat > /etc/apt/sources.list <<'EOF'
# Condtux no usa este archivo directamente.
# Las fuentes APT están en /etc/apt/sources.list.d/*.sources
EOF

cat > /etc/apt/sources.list.d/condtux.sources <<'EOF'
Types: deb
URIs: https://repo-condtux.jeval.cl/apt
Suites: trixie trixie-updates trixie-security
Components: main desktop tools artwork
Architectures: amd64
Trusted: yes
EOF

cat > /etc/apt/sources.list.d/debian.sources <<'EOF'
Types: deb
URIs: https://deb.debian.org/debian
Suites: trixie trixie-updates
Components: main
Architectures: amd64

Types: deb
URIs: https://security.debian.org/debian-security
Suites: trixie-security
Components: main
Architectures: amd64
EOF

cat > /etc/apt/preferences.d/condtux.pref <<'EOF'
Package: *
Pin: release o=Condtux,n=trixie
Pin-Priority: 700

Package: *
Pin: release o=Condtux,n=trixie-updates
Pin-Priority: 700

Package: *
Pin: release o=Condtux,n=trixie-security
Pin-Priority: 750

Package: *
Pin: release o=Condtux,n=trixie-testing
Pin-Priority: 100

Package: *
Pin: release o=Condtux,n=trixie-experimental
Pin-Priority: 1

Package: *
Pin: release o=Debian
Pin-Priority: 500
EOF

cat > /etc/apt/apt.conf.d/99condtux <<'EOF'
APT::Install-Recommends "false";
APT::Install-Suggests "false";
Acquire::Retries "3";
EOF

cat > /etc/apt/apt.conf.d/20auto-upgrades <<'EOF'
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
APT::Periodic::AutocleanInterval "7";
EOF

cat > /etc/apt/apt.conf.d/50unattended-upgrades <<'EOF'
Unattended-Upgrade::Origins-Pattern {
        "origin=Debian,codename=trixie-security,label=Debian-Security";
        "origin=Debian,codename=trixie-updates,label=Debian";
        "origin=Condtux,codename=trixie-security,label=Condtux";
        "origin=Condtux,codename=trixie-updates,label=Condtux";
};

Unattended-Upgrade::Remove-Unused-Dependencies "true";
Unattended-Upgrade::Automatic-Reboot "false";
EOF

apt-get purge -y popularity-contest || true

systemctl enable NetworkManager || true
systemctl enable unattended-upgrades || true
systemctl enable ssh || true
systemctl enable condtux-first-config.service || true

apt-get clean || true

echo "[ Condtux ] Post-instalación completada."
