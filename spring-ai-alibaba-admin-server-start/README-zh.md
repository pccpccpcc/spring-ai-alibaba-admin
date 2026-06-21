# Spring AI Alibaba Admin Server

> Spring AI Alibaba Repo: https://github.com/alibaba/spring-ai-alibaba
>
> Spring AI Alibaba Website: https://java2ai.com
>
> Spring AI Alibaba Website Repo: https://github.com/springaialibaba/spring-ai-alibaba-website

[English](./README-en.md) | 中文

## 项目概述

Spring AI Alibaba Admin Server 是基于 Spring Boot 3.x 构建的 AI Agent 管理平台后端服务，为 Agent Studio 提供完整的 RESTful API 支持。该服务支持 Prompt 管理、数据集管理、评估器配置、实验执行、结果分析和可观测性等核心功能。

## 核心功能

### 🤖 Prompt 管理
- **Prompt 模板管理**: 创建、更新、删除 Prompt 模板
- **版本控制**: 支持 Prompt 版本管理和历史追踪
- **实时调试**: 提供 Prompt 在线调试和流式响应
- **会话管理**: 支持多轮对话会话管理

### 📊 数据集管理
- **数据集创建**: 支持多种格式的数据集导入和创建
- **版本管理**: 数据集版本控制和历史管理
- **数据项管理**: 细粒度的数据项增删改查
- **从链路追踪创建**: 支持从 OpenTelemetry 链路数据创建数据集

### ⚖️ 评估器管理
- **评估器配置**: 支持多种评估器的创建和配置
- **模板系统**: 提供评估器模板和自定义评估逻辑
- **调试功能**: 支持评估器在线调试和测试
- **版本管理**: 评估器版本控制和发布管理

### 🧪 实验管理
- **实验执行**: 自动化执行评估实验
- **结果分析**: 详细的实验结果分析和统计
- **实验控制**: 支持实验的启动、停止、重启和删除
- **批量处理**: 支持批量实验执行和结果对比

### 📈 可观测性
- **链路追踪**: 集成 OpenTelemetry 提供完整的链路追踪
- **服务监控**: 支持服务列表和概览统计
- **Trace 分析**: 提供详细的 Trace 详情和 Span 分析

### 🔧 模型配置
- **多模型支持**: 支持 OpenAI、DashScope、DeepSeek 等主流 AI 模型
- **配置管理**: 模型参数的统一配置和管理
- **动态切换**: 支持运行时模型配置的动态更新

 
 
## 快速开始

### 环境要求
- **JDK 17+**
- **Maven 3.8+**
- **Node.js 20.x+**（构建完整控制台前端需要）
- **MySQL 8.0+**
- **Elasticsearch 9.x**
- **Nacos 3.x**
- **Redis、RocketMQ、LoongCollector**


#### 1. 克隆项目

```bash
git clone https://github.com/spring-ai-alibaba/spring-ai-alibaba-admin.git
cd admin
```

#### 2. 安装和启动依赖中间件

首次使用：

```bash
scripts/install-deps.sh
```

日常启动：

```bash
scripts/deps-start.sh
scripts/deps-status.sh
```

#### 3. nacos配置（可选）
如果您需要修改nacos地址，请更新spring-ai-alibaba-admin-server/src/main/resources/application.yml文件中的配置
```yaml
nacos:
  server-addr: ${nacos地址}
```

### 4. 启动SAA Admin
在仓库根目录下执行启动脚本。该脚本会启动中间件、构建完整前端、同步静态资源、打包并启动后端服务。

```bash
./start.sh
```

常用命令：

```bash
./start.sh --skip-deps --restart
./start.sh --build --restart
./start.sh --foreground
```

### 5. 访问应用

打开浏览器访问 http://localhost:8081/admin 即可使用 SAA Admin 平台。

默认账号：`saa` / `123456`。

健康检查：

```bash
curl http://localhost:8081/actuator/health
```

至此，您已经可以在平台中对 Prompt 进行管理、调试、评估、可观测。如果您期望 Spring AI Alibaba Agent 应用能够集成 Nacos 以实现 Prompt 加载以及动态更新，并且观测线上的运行情况，请参考根目录 README 的“连接您的 AI Agent 应用”。

如需真实模型调用，登录后进入“模型服务管理”配置 OpenAI 兼容 Provider、API Key、endpoint 和模型类型。知识库至少需要 `text_embedding` 模型；`rerank` 可选。


## 配置说明

### 数据库配置
```yaml
spring:
  datasource:
    type: com.alibaba.druid.pool.DruidDataSource
    driver-class-name: com.mysql.cj.jdbc.Driver
    url: jdbc:mysql://127.0.0.1:3306/admin
    username: admin
    password: admin
```

### Elasticsearch 配置
```yaml
spring:
  elasticsearch:
    uris: http://localhost:9200
```

### Nacos 配置
```yaml
nacos:
  server-addr: 127.0.0.1:8848
```

### 可观测性配置
```yaml
management:
  otlp:
    tracing:
      export:
        enabled: true
      endpoint: http://localhost:4318/v1/traces
```

## 许可证

本项目基于 Apache License 2.0 许可证开源。

## 贡献指南

欢迎提交 Issue 和 Pull Request 来帮助改进项目。
