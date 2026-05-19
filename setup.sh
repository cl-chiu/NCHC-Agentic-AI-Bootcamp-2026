#!/usr/bin/env bash
set -euo pipefail

exec > >(tee -a /var/log/nvbootcamp-init.log) 2>&1

BASTION_IP="10.1.1.81"
BASTION_USER="nvbootcamp"
BASTION_PASS="nvbootcamp2026"
REGISTRY="${BASTION_IP}:5000"
VLLM_IMAGE="${REGISTRY}/vllm/vllm-openai:v0.21.0-ubuntu2404"

DATA_MOUNT="/data"
DOCKER_DATA_ROOT="${DATA_MOUNT}/docker"
MODEL_DIR="${DATA_MOUNT}/nvidia"

DEFAULT_USER="$(getent passwd 1000 | cut -d: -f1 || true)"
DEFAULT_HOME="$(getent passwd 1000 | cut -d: -f6 || true)"

if [ -z "${DEFAULT_USER}" ]; then
  DEFAULT_USER="ubuntu"
  DEFAULT_HOME="/home/ubuntu"
fi

export DEBIAN_FRONTEND=noninteractive

echo "[1/9] Install basic packages"
apt update
apt install -y ca-certificates curl gnupg lsb-release wget rsync sshpass e2fsprogs

echo "[2/9] Detect and mount empty data disk"

ROOT_SRC="$(findmnt -n -o SOURCE / || true)"
ROOT_PARENT="$(lsblk -no PKNAME "${ROOT_SRC}" 2>/dev/null | head -n1 || true)"

if [ -n "${ROOT_PARENT}" ]; then
  ROOT_DISK="/dev/${ROOT_PARENT}"
else
  ROOT_DISK="$(readlink -f "${ROOT_SRC}" || true)"
fi

DATA_DISK=""

while read -r DISK TYPE; do
  if [ "${TYPE}" != "disk" ]; then
    continue
  fi

  # 跳過 root disk
  if [ "$(readlink -f "${DISK}")" = "$(readlink -f "${ROOT_DISK}")" ]; then
    continue
  fi

  # 如果這顆 disk 底下已經有 partition，就跳過
  CHILD_COUNT="$(lsblk -nr "${DISK}" | tail -n +2 | wc -l)"
  if [ "${CHILD_COUNT}" -ne 0 ]; then
    echo "[INFO] Skip ${DISK}: has partitions or children"
    continue
  fi

  # 如果 disk 本身已經有 filesystem，就跳過
  if blkid "${DISK}" >/dev/null 2>&1; then
    echo "[INFO] Skip ${DISK}: filesystem exists"
    continue
  fi

  # 如果 disk 已經被掛載，就跳過
  if lsblk -nr -o MOUNTPOINT "${DISK}" | grep -q '/'; then
    echo "[INFO] Skip ${DISK}: already mounted"
    continue
  fi

  DATA_DISK="${DISK}"
  break

done < <(lsblk -dpn -o NAME,TYPE)

if [ -z "${DATA_DISK}" ]; then
  echo "[ERROR] Cannot find empty data disk. Stop to avoid formatting wrong disk."
  lsblk -f
  exit 1
fi

echo "[INFO] DATA_DISK=${DATA_DISK}"

echo "[INFO] Formatting ${DATA_DISK} as ext4"
mkfs.ext4 -F "${DATA_DISK}"

DATA_UUID="$(blkid -s UUID -o value "${DATA_DISK}")"

mkdir -p "${DATA_MOUNT}"

if ! grep -q "${DATA_UUID}" /etc/fstab; then
  echo "UUID=${DATA_UUID} ${DATA_MOUNT} ext4 defaults,nofail 0 2" >> /etc/fstab
fi

mount -a

mkdir -p "${DOCKER_DATA_ROOT}" "${MODEL_DIR}"
chown -R "${DEFAULT_USER}:${DEFAULT_USER}" "${DATA_MOUNT}"

echo "[3/9] Install Docker"
install -m 0755 -d /etc/apt/keyrings

curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
  -o /etc/apt/keyrings/docker.asc

chmod a+r /etc/apt/keyrings/docker.asc

tee /etc/apt/sources.list.d/docker.sources <<EOF
Types: deb
URIs: https://download.docker.com/linux/ubuntu
Suites: $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}")
Components: stable
Architectures: $(dpkg --print-architecture)
Signed-By: /etc/apt/keyrings/docker.asc
EOF

apt update
apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

systemctl enable --now docker

echo "[4/9] Configure Docker data-root and insecure registry"

mkdir -p /etc/docker

tee /etc/docker/daemon.json <<EOF
{
  "data-root": "${DOCKER_DATA_ROOT}",
  "insecure-registries": ["${REGISTRY}"]
}
EOF

systemctl restart docker

usermod -aG docker "${DEFAULT_USER}" || true

echo "[INFO] Docker root dir:"
docker info | grep "Docker Root Dir" || true

echo "[5/9] Install NVIDIA driver / nvidia-smi"
apt update
apt install -y "linux-headers-$(uname -r)" || apt install -y linux-headers-generic

DISTRO=$(. /etc/os-release; echo ubuntu${VERSION_ID/./})

wget -O /tmp/cuda-keyring_1.1-1_all.deb \
  https://developer.download.nvidia.com/compute/cuda/repos/${DISTRO}/x86_64/cuda-keyring_1.1-1_all.deb

dpkg -i /tmp/cuda-keyring_1.1-1_all.deb
apt update
apt install -y cuda-drivers

echo "[6/9] Install NVIDIA Container Toolkit"
apt-get update
apt-get install -y ca-certificates curl gnupg2

curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey \
  | gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg

curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list \
  | sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' \
  | tee /etc/apt/sources.list.d/nvidia-container-toolkit.list

apt-get update
apt-get install -y nvidia-container-toolkit

nvidia-ctk runtime configure --runtime=docker
systemctl restart docker

echo "[7/9] Rsync ~/nvidia from bastion to ${MODEL_DIR}"

sshpass -p "${BASTION_PASS}" rsync -avz \
  -e "ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null" \
  "${BASTION_USER}@${BASTION_IP}:~/nvidia/" \
  "${MODEL_DIR}/"

chown -R "${DEFAULT_USER}:${DEFAULT_USER}" "${MODEL_DIR}"

echo "[8/9] Create ~/nvidia symlink to data disk"

rm -rf "${DEFAULT_HOME}/nvidia"
ln -s "${MODEL_DIR}" "${DEFAULT_HOME}/nvidia"
chown -h "${DEFAULT_USER}:${DEFAULT_USER}" "${DEFAULT_HOME}/nvidia"

echo "[9/9] Pull vLLM image from internal registry"

docker pull "${VLLM_IMAGE}"

echo "[INFO] Disk usage:"
df -h
du -sh "${DOCKER_DATA_ROOT}" || true
du -sh "${MODEL_DIR}" || true

echo "[DONE] Init finished. Rebooting for NVIDIA driver to take effect."
reboot