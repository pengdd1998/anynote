# 部署优化技术方案 — shared-infra 独立与边缘收编（2026-09）

> 两部分：**Part 1** shared-infra 独立到 VPS `/srv/infra` 外部手动环境
> （已实施，2026-09-18）；**Part 2** 关闭 `0.0.0.0:36661` 直出、切换
> HTTPS + 域名（规划，硬阻塞 = `chishenma.top` 备案）。
>
> 平台侧契约与迁移记录（canonical，read-pal 仓库）：
> - 接入手册：`ops/edge/README.md`（三不变式、片段模板、CD 钩子）
> - 平台层方案：`ops/infra/PLAN.md`（收养记录、运维纪律、runbook）
> - 边缘迁移执行记录：`ops/edge/PLAN.md` 文末（含备案阻断实证、踩坑清单）
> - 平台 canonical compose：`ops/infra/files/docker-compose.yml`（`name: infra` 钉死）

---

## Part 1 — shared-infra 独立到 /srv/infra（已实施 2026-09-18）

### 1.1 现状与动因

平台组已于 2026-09-17/18 完成数据面收养（infra-postgres/redis/minio 归
compose project `infra` @ `/srv/infra`）与 C-6 公网端口收紧（四端口改
`127.0.0.1` 回环）。但本仓库 CD（cd.yml 原 203-204 行）每次部署仍执行：

```yaml
docker compose -f infra/docker-compose.yml up -d
```

构成**双主收敛**：本仓库 `infra/` 目录名恰为 `infra` → compose project
与 /srv/infra 同名同标签，而仓库旧定义与现场有两处实质差异——

1. 端口 `0.0.0.0`（旧）vs `127.0.0.1`（现场）：每次执行会**回滚 C-6 端口
   收紧**，重新对公网暴露 trust 认证 PG（35551）、无密码 Redis（35552）、
   默认凭据 MinIO（9000/9001）——平台方自评"全 VPS 最高危暴露"；
2. `init-db.sh` bind-mount 源路径不同（平台执行记录已实证此类差异触发
   容器 Recreate）：每次执行会重建三个数据面容器，两项目秒级中断。

因此本 PR 不是清理，是止血：**合并前避免发版**。

### 1.2 改动清单（本次 PR，2026-09-18 落盘）

| 文件 | 改动 |
| --- | --- |
| `.github/workflows/cd.yml` | 删除 infra 收敛行（原 203-204），原位留注释指向 /srv/infra；pg_isready 等待循环加兜底（30 次后不可达 → 明确报错 + `exit 1`，替代"静默继续、靠后续步骤失败"） |
| `infra/docker-compose.yml`、`infra/init-db.sh` | 删除（/srv/infra 已有副本，postgres 已在新路径下运行） |
| `infra/README.md` | 新增存根：外部管理归属、canonical 位置、消费契约、"禁止重新引入 infra 定义"警告 |
| `docker-compose.yml:10-18` | 头部过时注释更新（生产段落不再引用 infra/docker-compose.yml） |
| `docker-compose.deploy.yml:4-5` | 同上 |

应用零耦合（收养前置已满足）：deploy compose 声明 `shared-infra` 为
external 网络（`docker-compose.deploy.yml:121-124`），经容器 DNS 短名
`postgres:5432` / `redis:6379` / `minio:9000` 访问（`:20-22`）；迁移走
deploy compose 自带 `/app/migrate`（cd.yml，不经 infra 文件）。

### 1.3 保留的消费者角色（不依赖 infra 文件归属）

cd.yml 中以下 `docker exec infra-postgres ...` 按容器名工作，全部保留：
pg_isready 等待、`CREATE DATABASE anynote`（幂等）、部署前 `pg_dump`
快照（保留 5 份）。

### 1.4 验收（下次部署后执行）

1. 部署日志无 infra 收敛行；`http://localhost:36661/health` 200；
2. `docker ps` 中 infra 三容器 `StartedAt` 跨部署不变（未重建）；
3. `docker inspect infra-postgres` 端口仍为 `127.0.0.1` 绑定；
   `nc -z -w3 175.178.66.207 35551` 不通；
4. read-pal 与 anynote 双项目健康。

### 1.5 回退

revert 本 PR 即可——容器全程未被触碰，回退只是"谁来收敛"的归属切换
（平台 PLAN §1⑥）。⚠ revert 期间再次发版会重现 1.1 的双主收敛危害。

### 1.6 运维契约变更（治理目标）

infra 变更（镜像升级/调参）今后只能走平台 runbook：通告平台组 →
`/srv/infra` per-service `up -d` → 回写 canonical。本仓库不再有 infra
服务定义。自愈缺口由三层覆盖：`restart: unless-stopped`（重启/宕机）、
平台 check.py `containers_healthy` 告警（人为停机）、CD 兜底 `exit 1`
响亮失败（不静默带病上线）。

---

## Part 2 — 关闭 0.0.0.0:36661 直出，切换 HTTPS + 域名（规划）

状态：**方案定稿，阻塞于备案**。应用侧前置改造（E-0）已于 2026-09-18
实施（TrustedRealIP 替换 chi RealIP，默认收紧为不信任任何代理头）。

### 2.1 现状

- Go 后端以纯 HTTP 直出公网：`docker-compose.deploy.yml:32`
  `ports: "${PORT:-36661}:36661"`（0.0.0.0），无 TLS 终结；
- App 内置默认地址 `http://175.178.66.207:36661`
  （`frontend/lib/main.dart:117`，可被 `--dart-define=API_BASE_URL` 覆盖）；
- 后端 HSTS 头（`security_middleware.go:25`）在纯 HTTP 上被浏览器忽略，
  当前为无效配置；
- web 构建的 CSP（`frontend/web/index.html:35`）connect-src 已是
  `https:`/`wss:` only——web 端现在连不上明文 API，HTTPS 是既定设计方向；
- 平台边缘 edge-caddy（/srv/infra，caddy:2，0.0.0.0:80/443/443udp，
  ACME 自动签续）已就绪，read-pal / what-to-eat 已接入或列入接入清单，
  edge PLAN 阶段 D 明确 anynote"收编即关闭 0.0.0.0:36661 直出"。

### 2.2 风险分析（0.0.0.0:36661 直出）

传输层（核心）：

| # | 风险 | 依据 |
| --- | --- | --- |
| T-1 | **登录凭据可截获重放**：登录明文发送 `email + auth_key_hash`（客户端派生的口令等价凭据，截获即可直接重放）；JWT access/refresh token 每请求明文传输 = 会话可劫持 | `api_client.dart:297-307,314-325` |
| T-2 | **非 E2E 加密数据明文裸奔**：AI 对话内容（`/api/v1/ai/proxy`）、用户保存的 LLM API key（`/api/v1/llm/configs` 写入）、**分享密码（明文 `X-Share-Password` 请求头）**、发布内容/统计、笔记元数据（数量/大小/时间线/ID） | `api_client.dart:445-461,476-504,608-617` |
| T-3 | 公开 recovery-salt 端点按 email 返回 `recovery_salt + encrypted_master_key`，明文链路可被在路者按 email 收割（有 IP 限流，但数据在链路可见） | `api_client.dart:350-355` |
| T-4 | 受害场景 = 公共 WiFi / 被劫持链路上的移动客户端；性质是链路安全缺位（在路攻击），非可远程任意利用漏洞 | — |

**缓解事实（定级依据）**：笔记正文客户端加密后才同步
（`sync_engine.dart:220` `_encryptNoteForPush`，服务端只见密文 blob），
最核心内容即使被截获也是密文。但护不住 T-1/T-2/T-3——"笔记 E2E 加密"
的产品与明文登录凭据/分享密码并存，安全水位由最弱链路定义。**综合定级：
高**。

治理/平台层：

- 三项目唯一绕过边缘的直出孤例，违反平台不变式"被反代服务不得发布
  0.0.0.0 端口"（绕过边缘 = 绕过 TLS/统一 header/审计）；无边缘访问日志，
  出事无审计线索；独立端口是扫描/爆破直接目标。

移动平台层：

- iOS ATS 目前靠"裸 IP 直连豁免"工作（ATS 不适用于 IP 地址）；一旦
  域名化 + HTTP 立即被 ATS 拒绝，HTTPS 无退路；
- Android `network_security_config.xml` 为自托管 LAN 开了全局
  `cleartextTrafficPermitted="true"`，公网 IP 亦被覆盖，配置层无法强制
  （与其注释"公网端点必须 HTTPS"不符）。

### 2.3 必要性结论

**必要，紧迫度中偏高**：① 认证根基（凭据重放/会话劫持）；② 平台既定
路线（阶段 D）；③ web 端上线硬前提（CSP 已 https-only）；④ 移动平台
政策（ATS 域名化后无退路、Play 明文政策）。

### 2.4 可行性结论

**高，唯一硬阻塞 = 备案**：

- **平台侧就绪**：接入是五步模板（注册别名 → compose 加 edge-net →
  仓库片段 → DNS → CD 钩子 validate+reload）。reload 原子、validate
  失败旧配置继续服务——割接最坏结果是"没生效"而非下线。WebSocket 经
  caddy 自动 Upgrade，`ws_client.dart:259` 已按 http/https 推导 ws/wss，
  前端仅换 baseUrl。
- **应用侧改动小而明确**（见 2.7），其中一项必改且是**现存漏洞修复**：
  `router.go` 挂的 `chiMiddleware.RealIP`（chi v5.1.0）对
  `True-Client-IP`/`X-Real-IP`/`X-Forwarded-For` **无条件信任**（仅语法
  校验、不校验直连对端，chi 自身文档亦警告仅限可信代理后使用）——当前
  直连 36661 的客户端可伪造这些头轮换限流键，绕过 auth 限流与
  recovery-salt 防枚举限流，并污染日志。E-0 用"可信代理网段门控"的
  TrustedRealIP 替换之：默认（`TRUSTED_PROXIES` 空）不信任任何头（修复
  漏洞）；部署时配置 Docker 私网段后，边缘流量取真实客户端 IP，公网
  直连伪造的头继续被忽略。
- **硬阻塞**：平台执行记录实证 `read.chishenma.top` 的 ACME 签发被
  DNSPod 备案阻断页拦截（未备案域名 80/443 上 HTTP-01 挑战被墙）。
  anynote 子域名接入会撞同一堵墙；自签证书对面向用户的移动 App 不可
  接受（禁用校验比明文更糟；App 内置 pin 则换证书即发版）。read-pal
  的 `-k` 只用于服务端健康检查，App 用户端不可复制此模式。
- **存量客户端**：`kDefaultApiUrl` 是编译期默认值，旧版本 App 割接后
  仍指明文地址 → 36661 需保留公告宽限期（4 周）后再收紧回环。

### 2.5 实施路线（两段式，E-0 可立即启动）

**E-0 前置改造（现在做，不等备案）**

1. 后端可信代理门控的 RealIP 改造（独立价值：修复现存伪造漏洞）：
   以 `TrustedRealIP(cfg.Server.TrustedProxies)` 替换 `router.go` 的
   `chiMiddleware.RealIP`（后者无条件信任代理头，见 2.4）。语义：仅当
   直连对端 IP ∈ `TRUSTED_PROXIES`（CIDR/裸 IP，逗号分隔；如 Docker
   私网段 `172.16.0.0/12,192.168.0.0/16`）时，按 `True-Client-IP` →
   `X-Real-IP` → `XFF` 最左值 采纳客户端 IP；否则保留 socket 对端地址。
   默认空 = 绝不信任头（收紧现状）。recovery-salt 公开端点的防枚举限流
   同样受益。
2. 分支备好边缘接入改动（2.7 全部 + 2.8 序列），备案通过后一次割接。

**E-1 割接（备案通过后，一次部署）**

前提：DNS `anynote.chishenma.top` A 记录 → 175.178.66.207；平台组
登记别名 `anynote-api`。

部署序列（顺序即正确性——片段先生效，旧入口后关）：

```bash
# 1) 边缘片段收敛 + 原子 reload（validate 失败即中止部署，旧入口无损）
cp docker/edge.caddy /srv/infra/sites/anynote.caddy
docker exec edge-caddy caddy validate --config /etc/caddy/Caddyfile \
  && docker exec edge-caddy caddy reload --config /etc/caddy/Caddyfile
# 2) 应用服务滚动（compose 变更 = server 容器重建接入 edge-net）
IMAGE_TAG="$TAG" docker compose -f docker-compose.deploy.yml up -d
# 3) 健康检查（新入口为主，回环旧入口为辅）
curl -sf https://anynote.chishenma.top/health
curl -sf http://localhost:36661/health
```

期间 36661 公网绑定**保留**（宽限期，旧版 App 仍依赖）。

**E-2 App 发版**：`kDefaultApiUrl` → `https://anynote.chishenma.top`；
发版公告引导旧版本用户升级（自托管用户可自行改 API 地址）。

**E-3 收口（宽限期 ~4 周后）**：`ports: "127.0.0.1:${PORT:-36661}:36661"`
（公网关闭、宿主健康检查保留），App 侧可评估收紧
`network_security_config`（公网域名加入 cleartext 禁止清单）。

### 2.6 边缘片段草案（`docker/edge.caddy`）

```caddyfile
# anynote edge fragment — 只写 site 块, 全局选项归骨架（ops/edge/README.md）
anynote.chishenma.top {
	encode gzip

	reverse_proxy anynote-api:36661 {
		# 后端限流键依赖此头（E-0 改造后仅信任边缘来源）
		header_up X-Real-IP {remote_host}
		# AI 对话/SSE 流式接口
		flush_interval -1
	}
}
```

### 2.7 改动清单（file 级）

| # | 文件 | 改动 |
| --- | --- | --- |
| 1 | `docker-compose.deploy.yml` | server 服务加 `edge-net: {aliases: [anynote-api]}`（网络声明 `edge-net: external: true`）；E-3 时端口收紧回环 |
| 2 | `docker/edge.caddy` | 新增，内容见 2.6 |
| 3 | `.github/workflows/cd.yml` | 加片段收敛钩子（cp + validate + reload，validate 失败中止部署；仅片段变更时执行）；健康检查加新入口 |
| 4 | `router.go` + 新中间件 + `config.go` | `chiMiddleware.RealIP` 替换为 `TrustedRealIP`（可信网段门控，见 E-0）；`ServerConfig` 增 `trusted_proxies` + 环境变量 `TRUSTED_PROXIES`（E-0） |
| 5 | `frontend/lib/main.dart:117` | `kDefaultApiUrl` → https 域名（E-2） |
| 6 | Android `network_security_config.xml`（可选，E-3） | 域名加 cleartext 禁止清单 |
| 7 | README / .env.example | API 地址文档同步 |

前端 `ws_client.dart` / `api_client.dart` 零改动（baseUrl 传导 +
ws/wss 自动推导）。CORS 默认拒绝跨域（空 `CORS_ALLOWED_ORIGINS`），
如后续部署 web 端需显式放行，不阻塞本方案。

### 2.8 风险登记（切换动作）

| 风险 | 等级 | 缓解 |
| --- | --- | --- |
| 限流键可被伪造（chi RealIP 无条件信任代理头，现存漏洞；漏做 E-0 则割接后依旧） | 高 | E-0 已实施：可信网段门控替换；片段显式 `header_up X-Real-IP`；割接当日验证限流键分布 |
| 存量 App 指向旧明文地址 | 中 | 36661 宽限期 ~4 周 + 发版公告 + 自托管用户可改地址 |
| 双出口并存期绕过边缘（明文口仍开） | 中（宽限期内） | 缩短窗口；宽限期内明文风险与现状持平，不劣化 |
| 片段语法/匹配错误 | 低 | validate 前置中止 + reload 原子（最坏"没生效"）；read-pal 影子验证经验可复用 |
| 备案继续拖延 | 不可控 | E-0 独立价值不浪费；方案挂起不产生维护成本 |
| ACME 首签延迟数秒 | 低 | curl 重试即可（read-pal 经验） |

### 2.9 验收（E-1 割接后）

```bash
curl -s -o /dev/null -w '%{http_code}\n' https://anynote.chishenma.top/health        # 200
curl -s -D - -o /dev/null https://anynote.chishenma.top/ | head -20                   # 路由/证书/TLS 符合预期
docker exec edge-caddy caddy validate --config /etc/caddy/Caddyfile && echo OK        # 组装后配置有效
# X-Real-IP 生效：外部请求后查后端结构化日志，client IP 为真实公网 IP 而非 caddy 容器 172.x
# （read-pal 复审教训：X-Real-IP 是请求头，响应头里 grep 不到）
# WS/流式：App 实测 wss 协作连接 + AI 对话流式输出
# 限流：多客户端 IP 分别触发限流不互相误伤（单桶坍缩检测）
```

外加一次完整 App e2e（对生产新入口）。

E-3 收口验收：`nc -z -w3 175.178.66.207 36661` 不通；回环
`curl -sf http://localhost:36661/health` 仍 200（CD 健康检查不受影响）。

### 2.10 回退

- E-1 后：revert PR → CD 自动把旧状态收敛回去；边缘侧删除
  `/srv/infra/sites/anynote.caddy` + reload（或由 revert 后的钩子自然
  处理）。36661 公网绑定在宽限期内始终未关，回退零窗口。
- E-3 后：端口绑定改回 0.0.0.0 一次 up 即恢复（权衡：重新引入直出
  风险，仅应急用）。

### 2.11 WS 实时协作的第二层断裂 — room 契约（2026-09-18 发现，待立项）

E-0 真机排查实测（CI 构建 APK + 服务端日志）：token 层修复后，客户端
`POST /api/v1/ws/token` 200、旧 401 循环与 refresh 风暴消失，但握手变为
`GET /api/v1/ws → 400`：后端要求连接 URL 必带 `room` 参数
（ws_handler.go:171-175），连接即完成成员校验（IsMember）、presence join
与 CRDT catch-up（一房一连模型，read pump 不处理 join/leave 消息）；前端
WSClient 则是"无 room 连接 + join 消息进房"模型（ws_client.dart）。

**两层模型不兼容，实时协作在 token 层修复后仍不可用**。处置结论
（2026-09-18，产品定位澄清）：**AnyNote 是个人笔记应用，实时多人协作
不是产品需求**，不做 A/B 模型对齐。客户端 WS 连接入口（启动、登录、
DEV 注册路径）已移除（commit 4975092）——重连循环、后台流量与 refresh
churn 随下个 App 版本发布自然消失。WSClient 类与测试保留作为将来可能的
功能底座。后续清理项（待立项）：前端 collab/presence 消费模块与测试、
后端 ws_handler/presence_service/collab API 与相关表。

同轮关联修复（commit 2e22fd9）：`sodium_libs` 平台实例未注册导致全新
安装注册/登录必崩（LateInitializationError），已在 CryptoCompat.init()
显式注册修复并真机回归（注册→登录→主界面全通）。Mobile QA 工作流
（mobile-qa.yml，workflow_dispatch）产出带 `.debug` 后缀的并行安装
arm64 APK，供无本地工具链时的真机验证。

### 2.12 协作功能清理清单（2026-09-18 全工程扫描，待执行）

定位澄清后的全量删除清单。原则：sodium/E2EE 加密、sync_engine（个人
多设备同步）、share 分享链接、comments（基于 shared_notes）、publish/
AI/语义搜索全部保留（已验证与 collab 零耦合）。

**后端删除（Go）**

| 目标 | 测试文件 |
| --- | --- |
| `internal/handler/ws_handler.go`（520 行，含 clientRateLimiter） | `ws_handler_test.go`（1383 行） |
| `internal/handler/collab_handler.go`（rooms/join/leave/members） | `collab_handler_test.go`（919 行） |
| `internal/service/presence_service.go`（Redis presence/typing/pubsub） | `presence_service_test.go`、`presence_service_integration_test.go` |
| `internal/service/collab_service.go`（邀请码等） | `collab_service_test.go`（798 行） |
| `internal/repository/collab_repository.go`、`collab_operations_repository.go` | `collab_operations_repository_test.go`（470 行） |
| go.mod `nhooyr.io/websocket`（仅 ws_handler 使用） | — |

**后端联动编辑**：`cmd/server/main.go`（86-90,137-138,252,270-275,325-336
collab/presence 装配；Redis 客户端保留——限流/健康/worker 共用）、
`router.go`（74,78,130-131,144-145,233-242 路由；282,288,292-293
Services 字段）、`router_test.go`（218-241,271 stub）、
`e2e_full_server_test.go`（136-137,151,196-197）、`domain/types.go`
546-594（CollabRoom/Member/Operation 等）、可选：`plan.go` CanCollaborate
+ `plan_service.go:135-137` "collaborate" 分支、`notification_service.go:62`
collab_invite（DB enum 值 029 已含，保留无害）。

**数据库**：`034_drop_collab` 迁移 `DROP TABLE IF EXISTS collab_operations,
collab_room_members, collab_rooms`（FK 顺序/CASCADE）；生产现况
rooms=2 / members=2 / operations=0（实验残留），删前 pg_dump 备份；
022/023 的 down 文件一并删除。Redis presence 键 TTL≤5min 自愈，无需清理。

**前端删除（Flutter，约 6,100 行代码 + 6,100 行测试）**

| 目标 | 说明 |
| --- | --- |
| `lib/core/collab/`：crdt_text(656)、crdt_editor_controller(407)、merge_engine(165)、remote_cursor(172)、cursor_overlay(282)、cursor_position_calculator(231)、presence_indicator(521)、ws_client(337) | 全部仅被 collab 消费方引用 |
| `lib/features/collab/`：collab_provider(395)、share_dialog(568，协作邀请弹窗，非个人分享) | 仅 note_editor_screen 引用 |
| `lib/features/notes/presentation/widgets/collab_cursors_widget.dart`(116) | 100% collab |
| `lib/core/database/daos/collab_dao.dart` + `tables.dart` CollabStates 表 | Drift schemaVersion 22 → 新迁移步 deleteTable('collab_states') 后重新 build_runner |
| `api_client.dart` 842-864（createCollabRoom/joinCollabRoom） | getWsToken 一并删（若 ws_client 删除） |
| 测试：test/core/collab/ 全部 7 文件、test/features/collab/ 4 文件、collab_dao_test、collab_cursors_widget_test | ~6,100 行 |
| pubspec `web_socket_channel: ^3.0.1` | 仅 ws_client 使用 |

**前端联动编辑**：`note_editor_screen.dart`（isCollab 死模式全剥离：
imports 18,19,20,28,44,49；86-145 字段；216-218,259-268,297-339,366-371,
518-523,942-1020,1057-1066,1211-1215,1369,1468-1476,1698-1710,2327）；
`editor_app_bar_actions.dart`（import 6 + 116-121 PresenceAvatarStack）；
`sign_out_section.dart`（73-74,187-188 disconnect）；`onboarding_screen.dart`
68-87（协作宣传页，删或换文案）；l10n 四语言 arb 协作键
（onboardingCollaborate*/inviteCode*/nooneInRoom 等 16 个，保留 shareNote、
collaborationSharing 标签）。

**需决策**：编辑器 AppBar"分享"按钮当前打开协作邀请弹窗
（note_editor_screen:1211-1215）——删除后改接个人分享链接 sheet
（`share_sheet.dart`）或移除入口。

---

## 3. 附录 — 平台组接口索引

| 事项 | 去处 |
| --- | --- |
| 接入契约（网络 + 片段 + CD 钩子）、禁止事项、故障排查 | read-pal `ops/edge/README.md` |
| infra 变更 runbook（通告 → per-service up → 回写 canonical）、运维纪律 | read-pal `ops/infra/PLAN.md` |
| 备案现状与 IP 过渡形态先例 | read-pal `ops/edge/PLAN.md` 执行记录 |
| 别名登记（接入 PR 中登记 `anynote-api`） | read-pal `ops/edge/README.md` 登记表 |

平台边界提醒：`/srv/infra` 下任何文件禁止手改；对平台 compose 禁止任何
项目侧操作；`edge-caddy` 仅 validate + reload，永不 restart。
