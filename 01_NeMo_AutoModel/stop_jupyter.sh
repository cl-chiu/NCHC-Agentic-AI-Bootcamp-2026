#!/usr/bin/env bash
# 停止 NCHC LLM 工作坊環境並釋放磁碟空間：

set -euo pipefail

IMAGE="nvcr.io/nvidia/nemo-automodel:26.04"
CONTAINER="nchc-llm-workshop"

# 移除 container
if docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER}\$"; then
    echo "▶ 停止並移除 container ${CONTAINER}"
    docker rm -f "$CONTAINER" >/dev/null
    echo "✅ container 已移除"
    echo "▶ 移除 image ${IMAGE}"
    docker rmi "$IMAGE" >/dev/null
    echo "✅ image 已移除（釋放 ~41 GB）"
else
    echo "（container ${CONTAINER} 不存在，略過）"
fi
