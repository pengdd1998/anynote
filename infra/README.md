# infra/ — 已独立到外部手动环境（2026-09）

共享基础设施（PostgreSQL / Redis / MinIO，容器 `infra-postgres` /
`infra-redis` / `infra-minio`）已从本仓库独立到 VPS `/srv/infra`，
由平台组手动管理，**不随任何项目 CD 收敛**。

- canonical 配置：read-pal 仓库 `ops/infra/files/docker-compose.yml`
- 变更流程与运维纪律（per-service 操作、禁裸 down）：read-pal `ops/infra/PLAN.md`
- 多项目接入手册：read-pal `ops/edge/README.md`

本项目消费方式（不依赖本目录任何文件）：

- `docker-compose.deploy.yml` 声明 `shared-infra` 为 external 网络并加入；
- 通过容器 DNS 短名访问：`postgres:5432` / `redis:6379` / `minio:9000`
  （见 deploy compose 的 `DATABASE_URL` / `REDIS_URL` / `MINIO_ENDPOINT`）；
- CD 中的 `docker exec infra-postgres ...`（pg_isready 等待 / 建库 /
  pg_dump 备份）为消费者角色，按容器名工作。

⚠ 不要在本仓库重新引入 infra 服务定义——会与 `/srv/infra` 形成双主收敛：
compose project 同名（`infra`）导致定义差异（端口绑定、挂载路径）触发
数据面容器重建，并回滚平台的公网端口收紧。
