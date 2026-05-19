#!/usr/bin/env bash
# 停止 NCHC LLM 工作坊環境並釋放磁碟空間：
#   1) 停掉並移除 container
#   2) 移除 nemo-automodel:26.04 image
# 用法：./stop.sh           （只移除 container，保留 image）
#       ./stop.sh --purge   （連 image 一起移除）

set -euo pipefail

IMAGE="nvcr.io/nvidia/nemo-automodel:26.04"
CONTAINER="nchc-llm-workshop"
PURGE_IMAGE=0

for arg in "$@"; do
    case "$arg" in
        --purge|--all) PURGE_IMAGE=1 ;;
        -h|--help)
            echo "用法：$0 [--purge]"
            echo "  --purge   連同 docker image 一併移除（釋放 ~41 GB）"
            exit 0 ;;
        *) echo "未知參數：$arg" >&2; exit 1 ;;
    esac
done

# 移除 container
if docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER}\$"; then
    echo "▶ 停止並移除 container ${CONTAINER}"
    docker rm -f "$CONTAINER" >/dev/null
    echo "✅ container 已移除"
else
    echo "（container ${CONTAINER} 不存在，略過）"
fi

if [[ $PURGE_IMAGE -eq 1 ]]; then
    if docker image inspect "$IMAGE" >/dev/null 2>&1; then
        echo "▶ 移除 image ${IMAGE}"
        docker rmi "$IMAGE" >/dev/null
        echo "✅ image 已移除（釋放 ~41 GB）"
    else
        echo "（image ${IMAGE} 不存在，略過）"
    fi
else
    echo
    echo "（image ${IMAGE} 保留 — 若要釋放磁碟請執行：./stop.sh --purge）"
fi
