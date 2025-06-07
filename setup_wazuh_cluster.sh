#!/bin/bash

set -e

# This script helps install and configure a Wazuh cluster environment.
# It will ask the user for configuration preferences and then attempt to
# install the components with sensible defaults.

if [[ "$EUID" -ne 0 ]]; then
  echo "Please run this script as root." >&2
  exit 1
fi

read -p "설치할 Wazuh 버전을 입력하세요 [4.6.0]: " WAZUH_VERSION
WAZUH_VERSION=${WAZUH_VERSION:-4.6.0}

read -p "클러스터에 포함될 Wazuh 매니저 노드 수를 입력하세요: " MANAGER_NODES

declare -a NODE_IPS
declare -a NODE_NAMES
for ((i=1;i<=MANAGER_NODES;i++)); do
  read -p "매니저 노드 $i 의 IP 주소를 입력하세요: " ip
  read -p "매니저 노드 $i 의 이름을 입력하세요: " name
  NODE_IPS+=("$ip")
  NODE_NAMES+=("$name")
done

read -p "Wazuh 인덱서(OpenSearch)를 설치하시겠습니까? [Y/n] " INSTALL_INDEXER
INSTALL_INDEXER=${INSTALL_INDEXER:-Y}

if [[ "$INSTALL_INDEXER" =~ ^[Yy]$ ]]; then
  read -p "인덱서 노드 개수를 입력하세요: " INDEXER_NODES
  for ((i=1;i<=INDEXER_NODES;i++)); do
    read -p "인덱서 노드 $i 의 IP 주소를 입력하세요: " idx_ip
  done
fi

read -p "Wazuh 대시보드를 설치하시겠습니까? [Y/n] " INSTALL_DASHBOARD
INSTALL_DASHBOARD=${INSTALL_DASHBOARD:-Y}

# ---- Package installation ----

apt-get update -y
curl -s https://packages.wazuh.com/key/GPG-KEY-WAZUH | apt-key add -

echo "deb https://packages.wazuh.com/${WAZUH_VERSION}/apt/ stable main" \
  > /etc/apt/sources.list.d/wazuh.list

apt-get update -y

apt-get install -y wazuh-manager

if [[ "$INSTALL_INDEXER" =~ ^[Yy]$ ]]; then
  apt-get install -y wazuh-indexer
fi

if [[ "$INSTALL_DASHBOARD" =~ ^[Yy]$ ]]; then
  apt-get install -y wazuh-dashboard
fi

# ---- Basic cluster configuration ----

cluster_conf="/var/ossec/etc/ossec.conf"

backup_conf="${cluster_conf}.backup.$(date +%s)"
cp "$cluster_conf" "$backup_conf"

cat > "$cluster_conf" <<CFG
<ossec_config>
  <cluster>
    <name>wazuh_cluster</name>
    <node_name>${NODE_NAMES[0]}</node_name>
    <node_type>master</node_type>
  </cluster>
</ossec_config>
CFG

systemctl enable wazuh-manager
systemctl restart wazuh-manager

if [[ "$INSTALL_INDEXER" =~ ^[Yy]$ ]]; then
  systemctl enable wazuh-indexer
  systemctl restart wazuh-indexer
fi

if [[ "$INSTALL_DASHBOARD" =~ ^[Yy]$ ]]; then
  systemctl enable wazuh-dashboard
  systemctl restart wazuh-dashboard
fi

echo "Wazuh installation completed. Review configuration files as needed."
