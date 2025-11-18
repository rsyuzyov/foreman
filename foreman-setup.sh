#!/bin/bash
set -e

. /etc/os-release
if [[ "$ID" != "debian" || "$VERSION_ID" != "12" ]]; then
  echo "Неподходящая версия ОС: ${PRETTY_NAME}, установка рассчитана на debian 12"
  exit 1
fi

# Если в lxc динамичесикий ip, то для fqdn будет ip 127.0.1.1 и при установке foreman не проверка записи dns не будет выполнена
if grep -q "127.0.1.1 $(hostname -f)" /etc/hosts; then
  sed -i "/^127.0.1.1 $(hostname -f).*/d" /etc/hosts
  grep -qxF "127.0.0.1 $(hostname -f) $(hostname -s)" /etc/hosts || sed -i "1i127.0.0.1 $(hostname -f) $(hostname -s)" /etc/hosts
fi

apt update && apt dist-upgrade -y
apt install -y ca-certificates wget gnupg lsb-release locales

sed -i 's/^# *\(en_US.UTF-8 UTF-8\)/\1/' /etc/locale.gen
sed -i 's/^# *\(ru_RU.UTF-8 UTF-8\)/\1/' /etc/locale.gen
locale-gen
update-locale LANG=ru_RU.UTF-8

export LANG=ru_RU.UTF-8
export LC_ALL=ru_RU.UTF-8
export LC_CTYPE=ru_RU.UTF-8

[ -f /usr/share/keyrings/foreman.gpg ] && rm -f /usr/share/keyrings/foreman.gpg
wget -O- https://deb.theforeman.org/pubkey.gpg | gpg --dearmor -o /usr/share/keyrings/foreman.gpg 2>/dev/null || true
echo "deb [signed-by=/usr/share/keyrings/foreman.gpg] http://deb.theforeman.org/ bookworm 3.17" | tee /etc/apt/sources.list.d/foreman.list
echo "deb [signed-by=/usr/share/keyrings/foreman.gpg] http://deb.theforeman.org/ plugins 3.17" | tee /etc/apt/sources.list.d/foreman-plugins.list
apt update

dpkg -i ./assets/*.deb
apt --fix-broken install -y 
apt install -y -o Acquire::ForceIPv4=true openjdk-17-jdk postgresql foreman-installer
systemctl enable postgresql
systemctl start postgresql

foreman-installer \
  --enable-apache-mod-status \
  --enable-foreman \
  --enable-foreman-cli \
  --enable-foreman-cli-ansible \
  --enable-foreman-cli-bootdisk \
  --enable-foreman-cli-discovery \
  --enable-foreman-cli-puppet \
  --enable-foreman-cli-remote-execution \
  --enable-foreman-cli-ssh \
  --enable-foreman-cli-tasks \
  --enable-foreman-cli-templates \
  --enable-foreman-cli-webhooks \
  --enable-foreman-proxy \
  --enable-puppet \
  --enable-foreman-plugin-ansible \
  --enable-foreman-plugin-bootdisk \
  --enable-foreman-plugin-default-hostgroup \
  --enable-foreman-plugin-dhcp-browser \
  --enable-foreman-plugin-discovery \
  --enable-foreman-plugin-expire-hosts \
  --enable-foreman-plugin-monitoring \
  --enable-foreman-plugin-proxmox \
  --enable-foreman-plugin-puppet \
  --enable-foreman-plugin-puppetdb \
  --enable-foreman-plugin-remote-execution \
  --enable-foreman-plugin-rescue \
  --enable-foreman-plugin-snapshot-management \
  --enable-foreman-plugin-statistics \
  --enable-foreman-plugin-tasks \
  --enable-foreman-plugin-templates \
  --enable-foreman-plugin-webhooks \
  --enable-foreman-proxy-plugin-ansible \
  --enable-foreman-proxy-plugin-discovery \
  --enable-foreman-proxy-plugin-monitoring \
  --enable-foreman-proxy-plugin-remote-execution-script \
  --enable-foreman-proxy-plugin-shellhooks \
  --foreman-initial-admin-username=admin \
  --foreman-initial-admin-password=changeme

echo "Foreman installation completed. Access the web interface at: https://$(hostname -f)"
