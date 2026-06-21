# 应用启动日志

## 启动记录

### 2026-06-11 11:00 ~ 11:10

#### 标准启动脚本确认

**./start.sh --skip-deps --build --restart**

| 阶段 | 结果 | 说明 |
|------|------|------|
| 前端构建 | 成功 | `npm run build:flow`、`BACK_END=java npm run build:app` 均通过 |
| 静态资源同步 | 成功 | `frontend/packages/main/dist` 已同步到 `spring-ai-alibaba-admin-server-start/src/main/resources/static` |
| 后端构建 | 成功 | Maven reactor 5 个模块全部 `SUCCESS`，产物为 `spring-ai-alibaba-admin-server-start.jar` |
| 服务启动 | 成功 | 脚本等待 `/actuator/health` 通过后输出 `admin server ready: http://localhost:8081/admin` |
| 健康检查 | 成功 | `db`、`redis`、`elasticsearch`、`ping` 均为 `UP`，ES cluster `green` |
| 模型类型验证 | 成功 | 临时新增 `text_embedding` 模型后查询返回 `type=text_embedding`，临时数据已删除 |
| Rerank 可选验证 | 成功 | 不传 Rerank 创建知识库成功，`enable_rerank=false`，临时知识库已删除 |

#### 当前推荐命令

```bash
# 首次安装或重置中间件
scripts/install-deps.sh

# 日常完整启动
./start.sh

# 中间件已运行时，仅重启 Admin
./start.sh --skip-deps --restart

# 前端菜单、静态资源或后端代码变更后强制重建
./start.sh --build --restart

# 查看中间件状态
scripts/deps-status.sh
```

#### 功能完整性要求

启动不只看进程。成功标准：

1. `curl http://localhost:8081/actuator/health` 返回 `UP`
2. 浏览器访问 `http://localhost:8081/admin`
3. 使用 `saa/123456` 登录成功
4. 侧边栏能看到 Prompt、评测、应用 / 工作流编排、知识库、可观测、设置 / 模型服务
5. 核心 API 冒烟返回 200

如果页面只出现 Prompt、评测、可观测，通常是旧静态资源或浏览器缓存。先强制刷新；仍异常时执行：

```bash
./start.sh --build --restart
```

### 2026-06-09 16:37 ~ 16:42

#### 构建阶段

**mvn clean package -DskipTests**

| # | 错误 | 原因 | 修复 |
|---|------|------|------|
| 1 | `无效的目标发行版: 17` | jenv 指向 Java 8，JAVA_HOME=`~/.jenv/versions/1.8` | 设置 `JAVA_HOME=/Library/Java/JavaVirtualMachines/jdk-21.jdk/Contents/Home` 后重新构建 |
| 2 | (构建成功，22.3s) | — | — |

#### 启动阶段

**mvn spring-boot:run（第一次尝试）**

| # | 错误 | 原因 | 修复 |
|---|------|------|------|
| 1 | `Could not resolve dependencies ... SNAPSHOT` | `mvn clean package` 不安装到本地仓库，`spring-boot:run` 找不到 sibling 模块 | 改用 `java -jar` 直接运行打包好的 jar |

**java -jar（第二次尝试）**

| # | 错误 | 原因 | 修复 |
|---|------|------|------|
| 1 | `UnsupportedClassVersionError: class file version 61.0` | jenv 覆盖了 JAVA_HOME，`java` 命令仍用 Java 8 (只支持 52.0) | 使用绝对路径 `/Library/Java/JavaVirtualMachines/jdk-21.jdk/Contents/Home/bin/java` 运行 |

**最终启动命令（成功）**

```bash
source scripts/install-deps.local.env 2>/dev/null

SPRING_DATASOURCE_URL='jdbc:mysql://localhost:3306/admin?useUnicode=true&characterEncoding=utf-8&zeroDateTimeBehavior=convertToNull&allowMultiQueries=true&useSSL=false&allowPublicKeyRetrieval=true&serverTimezone=Asia/Shanghai' \
SPRING_DATASOURCE_USERNAME='admin' \
SPRING_DATASOURCE_PASSWORD='admin' \
SPRING_REDIS_HOST='localhost' \
SPRING_REDIS_PORT='6379' \
SPRING_ELASTICSEARCH_URIS='http://localhost:9200' \
SPRING_ELASTICSEARCH_URL='http://localhost:9200' \
NACOS_SERVER_ADDR='localhost:8848' \
ROCKETMQ_ENDPOINTS='localhost:18080' \
ROCKETMQ_NAME_SERVER='localhost:9876' \
SERVER_PORT=8081 \
/Library/Java/JavaVirtualMachines/jdk-21.jdk/Contents/Home/bin/java \
  -jar spring-ai-alibaba-admin-server-start/target/spring-ai-alibaba-admin-server-start.jar
```

## 启动结果

| 项目 | 值 |
|------|-----|
| 应用端口 | **8081**（默认 8080 被 Nacos 控制台占用，需通过 `SERVER_PORT` 指定） |
| 管理界面 | **http://localhost:8081/admin** |
| Java 版本 | 21.0.9 (Oracle LTS) |
| Spring Boot | 3.3.6 |
| Hibernate | 6.5.3.Final |
| 启动耗时 | ~15s |

## 注意事项

1. **jenv 冲突**：本地 jenv 默认设为 Java 8，但项目需要 Java 17+。构建和运行都必须显式指定 `JAVA_HOME` 或使用 JDK 21 的绝对路径。建议执行 `jenv global 21` 或在项目根目录 `jenv local 21`。
2. **mvn package vs install**：`mvn clean package` 只打包不安装到本地仓库。如果要用 `mvn spring-boot:run` 启动，需要先 `mvn clean install`。直接用 `java -jar` 不受影响。
3. **端口冲突**：Nacos 3.x 内嵌 Web 控制台默认监听 8080，与应用默认端口冲突。解决方案：通过环境变量 `SERVER_PORT=8081` 给应用指定其他端口。
4. **model-config**：首次使用需要在管理界面配置模型 Provider API Key（如 DashScope、OpenAI、DeepSeek），否则 AI 对话功能不可用。
