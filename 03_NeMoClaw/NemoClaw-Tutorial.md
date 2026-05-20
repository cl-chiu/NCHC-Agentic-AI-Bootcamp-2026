# NemoClaw 快速上手 Tutorial

> 一份給新手的 NemoClaw demo 指南：從安裝、建立第一個 sandbox agent，到簡單的操作與整合練習。
>
> 官方文件：<https://docs.nvidia.com/nemoclaw/latest/get-started/quickstart.html>

---

## 1. 什麼是 NemoClaw？

NemoClaw 是 NVIDIA 推出的 CLI 工具（目前為 alpha 階段），用來在 **sandboxed 環境**中部署、管理一個或多個 AI agent。它建立在三層架構之上：

```
┌─────────────────────────┐
│  NemoClaw CLI           │  ← 你在這裡下指令（部署、管理、監控）
│  (Deploy & Manage)      │
├─────────────────────────┤
│  OpenShell              │  ← 建立 sandbox、強制安全策略、路由 inference
│  (Sandbox Runtime)      │
├─────────────────────────┤
│  OpenClaw               │  ← agent 本體（personality、skills、memory、channels）
│  (Inside the Sandbox)   │
└─────────────────────────┘
```

簡單來說：**NemoClaw = OpenClaw agent + OpenShell sandbox + 一條 CLI 把它們串起來**。

---

## 2. 環境需求 (Prerequisites)

| 項目 | 最低需求 | 建議 |
|------|----------|------|
| OS | Linux (Ubuntu 22.04+) / macOS (Apple Silicon) / Windows WSL2 / DGX Spark | Linux |
| CPU | 4 vCPU | 4+ vCPU |
| RAM | 8 GB | 16 GB |
| Disk | 20 GB | 40 GB |
| Node.js | 22.16+ | 22.x LTS |
| npm | 10+ | latest |
| Docker | Engine / Desktop / Colima | Engine 24+ |

**檢查環境**：

```bash
node --version    # 應 >= v22.16
npm --version     # 應 >= 10
docker --version  # 應 >= 24.0
docker ps         # 確認 daemon 在跑
```

---

## 3. 安裝 NemoClaw

一行指令完成安裝（會啟動互動式 onboarding wizard）：

```bash
curl -fsSL https://www.nvidia.com/nemoclaw.sh | bash
```

如果要做自動化部署（CI / 不需互動）：

```bash
curl -fsSL https://www.nvidia.com/nemoclaw.sh \
  | NEMOCLAW_NON_INTERACTIVE=1 \
    NEMOCLAW_ACCEPT_THIRD_PARTY_SOFTWARE=1 \
    bash
```

安裝完成後驗證：

```bash
nemoclaw --version
nemoclaw --help
```

---

## 4. 第一次 Onboarding：建立你的 Sandbox Agent

執行 wizard：

```bash
nemoclaw onboard
```

過程中你會被問到：

### 4.1 選擇 Inference Provider

| 選項 | 適合情境 |
|------|----------|
| NVIDIA Endpoints | 用 NVIDIA hosted model（需要 API key） |
| OpenAI | OpenAI 官方 API |
| OpenAI-compatible | 自架 vLLM / LM Studio 等 |
| Anthropic | Claude API |
| Google Gemini | Gemini API |
| Local Ollama | 本機跑 Ollama（DGX Spark 推薦） |
| Model Router | 多 provider 自動路由 |

### 4.2 為 Sandbox 命名

例如：`my-assistant`

### 4.3 選擇額外功能

- **Web search**：讓 agent 可以上網查資料
- **Messaging channels**：Telegram / Discord / Slack
- **Network policy tier**：選擇預設安全等級（strict / moderate / open）

完成後 NemoClaw 會在 sandbox 內建立一個新鮮的 OpenClaw 實例。

---

## 5. 與你的 Agent 互動

### 5.1 透過瀏覽器 (Dashboard)

安裝完成後 CLI 會顯示 dashboard URL，預設 port `18789`：

```
http://localhost:18789
```

取得登入 token：

```bash
nemoclaw my-assistant token
```

開啟瀏覽器，貼上 token，就能用 chat UI 跟 agent 對話。

### 5.2 透過 Terminal

連進 sandbox：

```bash
nemoclaw my-assistant connect
```

進去後啟動 OpenClaw 的 TUI 對話介面：

```bash
openclaw tui
```

在 TUI 內直接打字即可。離開：先 `/exit` 離開 chat，再 `exit` 回到 host shell。

> ⚠️ **不要用 `openclaw agent --local`** — 這個 flag 會繞過 sandbox 的 secret scanning / network policy / inference auth，NemoClaw 已經明確阻擋。Sandbox 內一律用 `openclaw tui`（互動）或從 host 端透過 dashboard。

---

## 6. 常用功能 Demo

以下是新手最快可以「玩起來」的幾個功能：

### Demo 1 — 查看 sandbox 狀態

```bash
nemoclaw my-assistant status        # agent 狀態 / uptime / inference provider
nemoclaw list                       # 列出所有 sandbox
```

### Demo 2 — 看 sandbox 內部的檔案

OpenClaw 把 memory 寫成 plain Markdown，可以直接讀：

```bash
nemoclaw my-assistant connect
# 進去 sandbox 後：
ls ~/.openclaw/memory/
cat ~/.openclaw/memory/MEMORY.md
```

### Demo 3 — 換一個 inference provider

```bash
nemoclaw my-assistant inference set --provider anthropic
nemoclaw my-assistant inference test    # 跑一次 ping 驗證
```

### Demo 4 — 啟動 / 停止 / 重啟

```bash
nemoclaw my-assistant stop
nemoclaw my-assistant start
nemoclaw my-assistant restart
```

### Demo 5 — 加一個 Skill（讓 agent 學新技能）

OpenClaw 的 skill 是一個資料夾 + `SKILL.md`。範例：建立一個「今日 NASA APOD」skill。

```bash
nemoclaw my-assistant connect
mkdir -p ~/.openclaw/skills/nasa-apod
cat > ~/.openclaw/skills/nasa-apod/SKILL.md <<'EOF'
---
name: nasa-apod
description: Fetch NASA Astronomy Picture of the Day
---

When the user asks about today's astronomy picture, call:

    curl -s "https://api.nasa.gov/planetary/apod?api_key=DEMO_KEY"

Return the title, explanation, and image URL.
EOF
```

回到 chat 介面問：「What's today's NASA picture?」就會觸發這個 skill。

### Demo 6 — 接 Messaging Channel（Telegram 範例）

```bash
nemoclaw my-assistant channels add telegram
# 依提示輸入 Bot Token
nemoclaw my-assistant channels list
```

設定完成後，從你的 Telegram bot 傳訊息就會被 agent 接收。

### Demo 7 — 看 logs / 監控活動

```bash
nemoclaw my-assistant logs --tail 50
nemoclaw my-assistant activity      # 顯示 sandbox 內近期 inference / tool calls
```

### Demo 8 — Backup & Restore

```bash
nemoclaw my-assistant backup ./my-assistant-backup.tar.gz
nemoclaw my-assistant restore ./my-assistant-backup.tar.gz
```

### Demo 9 — Network Policy（控管 agent 可以連哪些網域）

```bash
nemoclaw my-assistant policy show
nemoclaw my-assistant policy allow-host api.openai.com
nemoclaw my-assistant policy deny-host *.untrusted.com
```

### Demo 10 — 清掉 sandbox

```bash
nemoclaw my-assistant destroy
```

---

## 6.5 Mini-demo：用 NemoClaw 做「只能看 public 帳本」的記帳助手

這個 demo 展示 NemoClaw / OpenShell 最重要的安全特性：**sandbox 預設與 host 完全隔離**。我們在 host 上建兩份 CSV（public + private），只把 public 帶進 sandbox，然後從 sandbox 內驗證 private 那份**根本看不到**，最後請 agent 對 public 做分析。

### Step 1 — 在 host 上建兩份假 CSV

```bash
# host shell（不是 sandbox 內）
mkdir -p ~/budget-demo/public ~/budget-demo/private

# Public：可以給 agent 看的日常消費
cat > ~/budget-demo/public/transactions.csv <<'EOF'
date,amount,merchant,category
2026-05-02,-3200,房東,居住
2026-05-03,-185,全聯,生活
2026-05-05,-95,星巴克,餐飲
2026-05-07,-1250,台電,居住
2026-05-09,-420,Uber Eats,餐飲
2026-05-11,-680,家樂福,生活
2026-05-13,-95,星巴克,餐飲
2026-05-15,-260,Spotify,訂閱
2026-05-18,-1480,誠品,購物
2026-05-21,-560,7-11,生活
2026-05-25,-95,星巴克,餐飲
2026-05-28,-340,計程車,通勤
EOF

# Private：薪資、投資、敏感金額 — 不希望 agent 看到
cat > ~/budget-demo/private/salary_and_investments.csv <<'EOF'
date,amount,source,note
2026-05-10,85000,公司薪轉,月薪
2026-05-10,-15000,XX證券,定期定額 0050
2026-05-15,42000,XX銀行,股利
2026-05-20,-200000,XX建設,房屋頭期款匯款
EOF
```

### Step 2 — 進 sandbox，先確認 host isolation 有生效

NemoClaw sandbox 預設不會看到 host 任何路徑 — 連我們剛建的 `~/budget-demo/` 都看不到。先驗證一下：

```bash
nemoclaw my-assistant connect
```

進到 sandbox 後（prompt 變 `sandbox@...$`）：

```bash
# Sandbox 看不到 host 任何路徑 ✅
ls ~/budget-demo/ 2>&1            #  → No such file or directory
ls /host/ 2>&1                     #  → No such file or directory
ls /home/ubuntu/budget-demo 2>&1   #  → No such file or directory
```

這就是 OpenShell 的 filesystem isolation — 不用設 policy，sandbox 本來就看不到 host。

### Step 3 — 把 public CSV 帶進 sandbox（但不帶 private）

NemoClaw 提供 `share mount` 子命令，用 SSHFS 把 sandbox 的 `/sandbox` 雙向掛到 host：

```bash
# 開新的 host terminal（保留 sandbox shell 不要關）
nemoclaw my-assistant share mount
# 預設掛到 ~/.nemoclaw/mounts/my-assistant
```

掛好後，host 端寫到 mount point 的檔案會直接出現在 sandbox 內：

```bash
# 還在 host
mkdir -p ~/.nemoclaw/mounts/my-assistant/budget
cp ~/budget-demo/public/transactions.csv ~/.nemoclaw/mounts/my-assistant/budget/
# 注意：~/budget-demo/private/ 完全沒碰，private CSV 不會進 sandbox
```

回到 sandbox shell 確認 public 已經進去、private 仍然看不到：

```bash
# sandbox 內
ls /sandbox/budget/
#  → transactions.csv

# private 路徑依舊不存在
ls /sandbox/private 2>&1     #  → No such file or directory
```

> 不想用 `share mount` 的話，最簡單的替代方案是直接在 sandbox 內用 `cat > transactions.csv <<EOF ... EOF` heredoc 重建檔案 — 同樣達到「只有 public 進 sandbox」的效果。

### Step 4 — 用 OpenClaw TUI 請 agent 做分析

```bash
# 還在 sandbox 內
openclaw tui
```

在 TUI 內輸入：

```
請讀 /sandbox/budget/transactions.csv：
1. 把 category 分組，算出 5 月每組的總金額
2. 算每組佔總支出的百分比
3. 把報表寫到 /sandbox/budget/reports/2026-05.md
```

OpenClaw 會用 sandbox 內建的 Python 跑分析、寫出 markdown 報表。

接著測一下 agent 真的看不到敏感資料 — 在 TUI 同一個對話內問：

```
我這個月薪資多少？股利收入多少？
```

預期：agent 回覆**找不到這些資料** — 因為從它的視角，這些檔案物理上不存在。這不是 prompt engineering 約束，是 sandbox 隔離。

離開 TUI：`/exit`。

### Step 5 — 把報表抓回 host 看

因為 Step 3 已經 `share mount` 過了，sandbox 內寫到 `/sandbox/budget/reports/` 的報表會自動出現在 host：

```bash
# host 端
cat ~/.nemoclaw/mounts/my-assistant/budget/reports/2026-05.md
```

完成後可以 unmount 跟 exit：

```bash
# host
nemoclaw my-assistant share unmount

# sandbox shell
exit
```

✅ 完成 — agent 能對 public 做完整分析、寫報表、給建議，但 **物理上無法接觸 private 那份**（因為從未進 sandbox）。

### 還能延伸

| 想做的 | 怎麼做（已驗證指令） |
|--------|--------|
| 加一個 `/etc/hosts` alias 給 sandbox 用 | `nemoclaw my-assistant hosts-add searxng.local 192.168.1.105` |
| 看 sandbox 目前有哪些 host aliases | `nemoclaw my-assistant hosts-list` |
| 套用 NemoClaw 內建的 network policy preset | `nemoclaw my-assistant policy-add pypi --yes` |
| 套用自訂 policy 檔 | `nemoclaw my-assistant policy-add --from-file ./my-policy.yaml` |
| 看當前有哪些 policy presets 已套用 | `nemoclaw my-assistant policy-list` |
| 把 sandbox 狀態打包 | `nemoclaw my-assistant snapshot create --name pre-experiment` |
| 還原到某個 snapshot | `nemoclaw my-assistant snapshot restore <name-or-version>` |
| 升級 agent 版本但保留 workspace | `nemoclaw my-assistant rebuild` |
| 重啟 in-sandbox gateway（不開 SSH） | `nemoclaw my-assistant recover` |
| 安裝一個 skill 進 sandbox | `nemoclaw my-assistant skill install ./my-skill/` |

> 💡 NemoClaw `<name>` 的有效 actions（v0.0.41）：`connect`, `status`, `doctor`, `logs`, `policy-add/remove/list`, `hosts-add/list/remove`, `skill`, `snapshot`, `share`, `rebuild`, `recover`, `shields`, `config`, `channels`, `gateway-token`, `destroy`。**沒有** `restart` / `workspace`。要重啟用 `recover`（輕量）或 `rebuild`（升版本）。
> `snapshot` / `share` / `skill` 都是 noun，需要 subcommand（例如 `snapshot create`、`share mount`、`skill install`）。
> 完整參考：<https://docs.nvidia.com/nemoclaw/reference/commands>。

---

## 7. 進階學習資源

| 主題 | 路徑 / 連結 |
|------|-------------|
| NemoClaw 官方 quickstart | <https://docs.nvidia.com/nemoclaw/latest/get-started/quickstart.html> |
| NemoClaw CLI 指令參考 | <https://docs.nvidia.com/nemoclaw/latest/reference/commands.html> |
| OpenClaw（agent 框架） | <https://docs.openclaw.ai/> |
| OpenShell（sandbox runtime） | <https://docs.nvidia.com/openshell/> |
| 內部完整訓練教材 | `./claw-training-assets-main/` （7 modules、46 notebooks） |

如果想要更系統化的訓練，本 repo 內的 `claw-training-assets-main/tracks/` 已經有完整 7 個模組，從 architecture 一路到 production operations。

---

## 8. 完整安裝順序（NCHC Ubuntu VM 實戰紀錄）

這是在 NCHC GPU VM（Ubuntu + NVIDIA H200）上實際走過一次的順序，把碰到的錯誤跟需要安裝的東西整理在一起。其他 Ubuntu 環境流程大同小異。

### 8.1 安裝項目（依順序）

| # | 項目 | 用途 | 指令 |
|---|------|------|------|
| 1 | Docker Engine | OpenShell sandbox 的 runtime | NemoClaw installer 會自動裝 |
| 2 | 把使用者加進 `docker` group | 讓 docker 不用 sudo | installer 會做，但要 `newgrp docker` 才生效 |
| 3 | Node.js 22.x + npm 10+ | NemoClaw CLI runtime | installer 透過 `nvm` 自動裝 |
| 4 | NemoClaw CLI 本體 | 主程式 | `curl -fsSL https://www.nvidia.com/nemoclaw.sh \| bash` |
| 5 | NVIDIA Container Toolkit | 提供 `nvidia-ctk`、產 CDI spec、讓 sandbox 看到 GPU | 見 9.2（GPU 機才需要） |
| 6 | CDI device spec (`/etc/cdi/nvidia.yaml`) | 讓 Docker 把 `nvidia.com/gpu` 解析成實體裝置 | `sudo nvidia-ctk cdi generate --output=/etc/cdi/nvidia.yaml` |

> Driver / CUDA 不在 NemoClaw 的安裝範圍內 — NCHC VM 預設已經有 driver 580.142 / CUDA 13.0，`nvidia-smi` 能跑就算 OK。

### 8.2 錯誤總表（依出現順序）

| 階段 | 錯誤訊息 | 原因 | 修法 | 詳見 |
|------|----------|------|------|------|
| Docker 安裝後 | `Your user 'ubuntu' is not in the docker group` | group membership 還沒在當前 shell 生效 | `newgrp docker`，然後重跑 installer | — |
| `[2/3] NemoClaw CLI` | `npm error code ECONNRESET` / `npm error network aborted` | npm 出去到 `registry.npmjs.org` 中斷（亞洲常見） | 拉高 timeout + 換 mirror | 9.1 |
| `[1/8] Preflight checks` | `unresolvable CDI devices nvidia.com/gpu=all` | Docker 開了 CDI 但缺 `nvidia-container-toolkit` | 裝 toolkit + 產 CDI spec，或 `nemoclaw onboard --no-gpu` | 9.2 |

### 8.3 一鍵 setup 腳本（給之後重做的人）

```bash
#!/usr/bin/env bash
set -euo pipefail

# 0. 先設好 npm 環境變數，避免 NemoClaw installer 中途死在 ECONNRESET
mkdir -p ~/.npm
cat > ~/.npmrc <<EOF
fetch-retries=5
fetch-retry-mintimeout=20000
fetch-retry-maxtimeout=120000
fetch-timeout=600000
registry=https://registry.npmmirror.com/
EOF

# 1. 跑 NemoClaw installer
curl -fsSL https://www.nvidia.com/nemoclaw.sh | bash

# 2. 若 docker group 還沒生效，新開 shell 或 newgrp
#    newgrp docker

# 3. GPU 機器才需要：裝 NVIDIA Container Toolkit + CDI spec
if command -v nvidia-smi >/dev/null && ! command -v nvidia-ctk >/dev/null; then
  curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey \
    | sudo gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg
  curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list \
    | sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#' \
    | sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list
  sudo apt-get update
  sudo apt-get install -y nvidia-container-toolkit
  sudo mkdir -p /etc/cdi
  sudo nvidia-ctk cdi generate --output=/etc/cdi/nvidia.yaml
fi

# 4. Onboarding
nemoclaw onboard
```

---

## 9. 常見問題 (Troubleshooting)

| 問題 | 解法 |
|------|------|
| `docker: command not found` | 安裝 Docker Engine 或 Docker Desktop，並確認 user 在 `docker` group |
| `docker group not active in shell` | 跑 `newgrp docker` 或登出再登入，讓 group 生效 |
| sandbox OOM / 卡死 | 機器 RAM < 8GB 時加上 8GB swap，或升級記憶體 |
| Dashboard 連不上 | 檢查 port 18789 是否被佔用：`lsof -i :18789` |
| Inference provider 連線失敗 | `nemoclaw my-assistant inference test` 看詳細錯誤；通常是 API key 沒設好 |
| 在 Ubuntu 上 Ollama 解壓失敗 | 安裝 `zstd`：`sudo apt install zstd` |
| `npm error code ECONNRESET` 安裝時斷線 | 見 9.1 — 調 npm timeout / 換 mirror |
| `unresolvable CDI devices nvidia.com/gpu=all` | 見 9.2 — 安裝 NVIDIA Container Toolkit |
| `Docker GPU patch failed: AMD CDI spec not found` | NemoClaw GPU patch 會找 AMD CDI，沒有就失敗。先 `openshell sandbox delete <name>`，再 `export NEMOCLAW_DOCKER_GPU_PATCH=0` 跳過 patch，重跑 `nemoclaw onboard`。NVIDIA GPU 還是會透過 CDI 正常 passthrough |
| `'openclaw agent --local' is not supported inside NemoClaw sandboxes` | `--local` 會繞過 gateway 安全機制，預期會被擋。在 sandbox 內改用 `openclaw tui`（互動）或從 host 端用 dashboard / `nemoclaw <name> connect` |

### 9.1 npm `ECONNRESET` — 安裝 NemoClaw dependencies 時連線中斷

症狀（安裝 log 出現）：

```
✗  Installing NemoClaw dependencies
npm error code ECONNRESET
npm error network aborted
```

通常是出去到 `registry.npmjs.org` 不穩（NCHC / 台灣 VM 常見）。修法：

```bash
# 1. 拉長 timeout、加 retry
npm config set fetch-retries 5
npm config set fetch-retry-mintimeout 20000
npm config set fetch-retry-maxtimeout 120000
npm config set fetch-timeout 600000

# 2. 清 cache（避免半下載的 tarball 干擾）
npm cache clean --force

# 3. 換 Asia mirror（亞洲速度比官方快很多）
npm config set registry https://registry.npmmirror.com/

# 4. 重跑安裝
curl -fsSL https://www.nvidia.com/nemoclaw.sh | bash
```

`npmmirror.com` 不通的話，備用 mirror：

```bash
npm config set registry https://registry.yarnpkg.com/
```

裝完想切回官方：

```bash
npm config set registry https://registry.npmjs.org/
```

**診斷網路**（判斷是 registry 還是 VM 出去整體有問題）：

```bash
curl -v https://registry.npmjs.org/npm 2>&1 | tail -20            # 小檔
curl -v -o /dev/null https://registry.npmjs.org/npm/-/npm-10.9.8.tgz 2>&1 | tail -10  # 大檔
```

### 9.2 `unresolvable CDI devices nvidia.com/gpu=all` — Docker 沒裝 NVIDIA Container Toolkit

症狀（preflight 紅字）：

```
Docker is configured for CDI device injection (CDISpecDirs is set), but no
nvidia.com/gpu CDI spec was found on the host. OpenShell's gateway start will
fail with `unresolvable CDI devices nvidia.com/gpu=all`.
```

原因：Docker daemon 開了 CDI device injection，但缺 `nvidia-container-toolkit`（提供 `nvidia-ctk`）。

#### 方案 A — 跳過 GPU（最快，適合 remote inference demo）

```bash
nemoclaw onboard --no-gpu
```

Wizard 內 provider 選 NVIDIA Endpoints / OpenAI / Anthropic（**不要選 Local Ollama**）。

#### 方案 B — 安裝 NVIDIA Container Toolkit（需要 local GPU inference）

先確認真有 GPU：

```bash
nvidia-smi    # 應該看到 GPU 型號與 driver version
```

接著安裝 + 產 CDI spec：

```bash
# 1. 加 repo
curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey \
  | sudo gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg

curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list \
  | sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#' \
  | sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list

# 2. 安裝
sudo apt-get update
sudo apt-get install -y nvidia-container-toolkit

# 3. 產 CDI spec
sudo mkdir -p /etc/cdi
sudo nvidia-ctk cdi generate --output=/etc/cdi/nvidia.yaml

# 4. 驗證：應看到 nvidia.com/gpu=0 和 nvidia.com/gpu=all
nvidia-ctk cdi list

# 5. 重跑 onboarding
nemoclaw onboard
```

---

完成這份 tutorial 後，你應該已經能：

- 安裝並 onboard 一個 NemoClaw sandbox
- 用 Dashboard 和 Terminal 兩種方式和 agent 對話
- 切換 inference provider、加 skill、接 messaging channel
- 做 backup / restore，並控管 network policy

Happy clawing! 🦞
