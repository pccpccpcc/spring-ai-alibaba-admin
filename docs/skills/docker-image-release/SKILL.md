---
name: docker-image-release
description: 当需要构建、打标签、推送 Docker 镜像或更新部署清单镜像地址时使用：覆盖前端/后端镜像、版本号/tag、registry、build context、Dockerfile、登录、推送、Kubernetes YAML 镜像替换和发布前验证。
---

# Docker 镜像构建与推送

当用户要“构建镜像”“推送镜像”“发一个 Docker 版本”“更新部署镜像地址”时使用这个 skill。目标是确保镜像构建上下文、tag、registry、部署清单和验证步骤一致。

## 最小输入

优先从项目文件推断构建方式。缺少关键信息时只问必要问题。

通常需要：

- 镜像范围：后端、前端、全部。
- 镜像仓库：registry 地址 / namespace。
- tag：版本号、commit sha、日期版本，或 `latest`。

可选：

- 平台架构：例如 `linux/amd64`、`linux/arm64`。
- 是否推送：只本地构建，还是构建并推送。
- 是否更新部署清单：例如 Kubernetes YAML、Helm values、compose 文件。

不要默认推送到远端仓库。推送前必须确认 registry、tag 和登录状态。

## 第一轮扫描

先定位：

- Dockerfile：根目录、后端模块、前端目录。
- 构建脚本：`deploy/README.md`、`deploy/*.sh`、Makefile、CI workflow。
- 部署清单：Kubernetes YAML、Helm values、docker-compose。
- 构建产物：后端 jar、前端 dist、workspace 构建脚本。
- `.dockerignore` 是否存在。

识别：

- 每个镜像的 build context。
- 每个镜像使用的 Dockerfile。
- 默认 image name。
- 部署清单中引用的 image 字段。
- 是否需要先构建子模块或前端 workspace。

## 本项目候选镜像

后端镜像：

```bash
docker build -f spring-ai-alibaba-admin-server-start/Dockerfile -t spring-ai-admin-server:latest .
```

说明：

- 后端 Dockerfile 要从项目根目录构建。
- Dockerfile 内部会执行 Maven package，并打包 `spring-ai-alibaba-admin-server-start`。

前端镜像：

```bash
cd frontend
docker build -t spring-ai-admin-frontend:latest .
```

说明：

- 前端 Dockerfile 以 `frontend/` 为构建上下文。
- Dockerfile 内部会执行 npm install、构建 flow 和 main 应用。

部署清单默认引用：

- `deploy/backend/backend-deployment.yaml`：`spring-ai-admin-server:latest`
- `deploy/frontend/frontend-deployment.yaml`：`spring-ai-admin-frontend:latest`

## 构建流程

### 1. 确认 tag 策略

推荐 tag：

- 本地验证：`latest` 或 `dev`。
- 联调环境：`dev-<short_sha>`。
- 发布版本：`vX.Y.Z` 或 `<date>-<short_sha>`。

避免只推 `latest` 且没有不可变 tag。生产或共享环境应至少保留一个不可变 tag。

### 2. 构建前验证

检查：

```bash
docker --version
docker info
git rev-parse --short HEAD
git status --short
```

如果工作区有未提交改动，要提示镜像包含当前工作区内容。不要擅自清理或回滚。

### 3. 构建镜像

按用户指定范围构建。

后端：

```bash
docker build -f spring-ai-alibaba-admin-server-start/Dockerfile -t <registry>/<namespace>/spring-ai-admin-server:<tag> .
```

前端：

```bash
cd frontend
docker build -t <registry>/<namespace>/spring-ai-admin-frontend:<tag> .
```

如果需要多架构：

```bash
docker buildx build --platform linux/amd64,linux/arm64 -t <image>:<tag> --push <context>
```

多架构构建通常会直接推送，执行前必须确认。

### 4. 本地验证

构建后检查：

```bash
docker images | grep spring-ai-admin
docker inspect <image>:<tag>
```

后端可选验证：

```bash
docker run --rm -p 8080:8080 <image>:<tag>
```

前端可选验证：

```bash
docker run --rm -p 8081:80 <image>:<tag>
```

如果容器依赖外部中间件，启动验证前要说明需要 MySQL、Redis、Nacos、Elasticsearch、RocketMQ 等依赖。

### 5. 登录和推送

推送前检查登录状态：

```bash
docker login <registry>
```

推送：

```bash
docker push <registry>/<namespace>/spring-ai-admin-server:<tag>
docker push <registry>/<namespace>/spring-ai-admin-frontend:<tag>
```

如果同时维护 `latest`：

```bash
docker tag <image>:<tag> <image>:latest
docker push <image>:latest
```

不要把敏感 registry token 写进文档或命令输出。

### 6. 更新部署清单

如果用户要求更新 Kubernetes / Helm / compose：

- 替换 deployment 中的 image 字段。
- 保持 imagePullPolicy 与 tag 策略一致。
- 如果推私有仓库，确认 imagePullSecret 是否已有。
- 更新后用 `rg` 反查旧镜像名是否仍残留。

本项目相关文件：

- `deploy/backend/backend-deployment.yaml`
- `deploy/frontend/frontend-deployment.yaml`

## 常见问题

- 后端 Docker build 找不到模块：检查是否从项目根目录构建。
- 前端 Docker build 找不到 workspace 包：检查是否从 `frontend/` 构建。
- Maven 下载慢或失败：确认网络、Maven 镜像源、依赖版本。
- npm install 失败：确认 Node 版本、lockfile、registry。
- 推送 denied：确认 registry、namespace、登录账号和权限。
- Kubernetes 拉不到镜像：确认镜像地址、tag、imagePullSecret、节点网络。

## 验证和收尾

最终回复用户时说明：

- 构建了哪些镜像。
- 使用的 Dockerfile、build context、tag。
- 是否已推送到 registry。
- 是否更新部署清单。
- 执行过哪些验证。
- 是否存在未提交代码、依赖外部中间件、镜像拉取权限等风险。
