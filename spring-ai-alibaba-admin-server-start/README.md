# Spring AI Alibaba Admin Server

> Spring AI Alibaba Repo: https://github.com/alibaba/spring-ai-alibaba
>
> Spring AI Alibaba Website: https://java2ai.com
>
> Spring AI Alibaba Website Repo: https://github.com/springaialibaba/spring-ai-alibaba-website

English  | [中文](./README-zh.md)  

## Project Overview

Spring AI Alibaba Admin Server is a backend service for AI Agent management platform built on Spring Boot 3.x, providing complete RESTful API support for Agent Studio. The service supports core functionalities including Prompt management, dataset management, evaluator configuration, experiment execution, result analysis, and observability.

## Core Features

### 🤖 Prompt Management
- **Prompt Template Management**: Create, update, and delete Prompt templates
- **Version Control**: Support for Prompt version management and history tracking
- **Real-time Debugging**: Provide online Prompt debugging and streaming responses
- **Session Management**: Support for multi-turn conversation session management

### 📊 Dataset Management
- **Dataset Creation**: Support for importing and creating datasets in multiple formats
- **Version Management**: Dataset version control and history management
- **Data Item Management**: Fine-grained data item CRUD operations
- **Create from Trace**: Support for creating datasets from OpenTelemetry trace data

### ⚖️ Evaluator Management
- **Evaluator Configuration**: Support for creating and configuring various evaluators
- **Template System**: Provide evaluator templates and custom evaluation logic
- **Debugging Features**: Support for online evaluator debugging and testing
- **Version Management**: Evaluator version control and release management

### 🧪 Experiment Management
- **Experiment Execution**: Automated execution of evaluation experiments
- **Result Analysis**: Detailed experiment result analysis and statistics
- **Experiment Control**: Support for starting, stopping, restarting, and deleting experiments
- **Batch Processing**: Support for batch experiment execution and result comparison

### 📈 Observability
- **Trace Tracking**: Integrated OpenTelemetry providing complete trace tracking
- **Service Monitoring**: Support for service list and overview statistics
- **Trace Analysis**: Provide detailed Trace details and Span analysis

### 🔧 Model Configuration
- **Multi-model Support**: Support for mainstream AI models including OpenAI, DashScope, DeepSeek
- **Configuration Management**: Unified configuration and management of model parameters
- **Dynamic Switching**: Support for dynamic updates of model configuration at runtime

## Quick Start

### Prerequisites
- **JDK 17+**
- **Maven 3.8+**
- **Node.js 20.x+** for building the full console frontend
- **MySQL 8.0+**
- **Elasticsearch 9.x**
- **Nacos 3.x**
- **Redis, RocketMQ, LoongCollector**

#### 1. Clone the Project

```bash
git clone https://github.com/spring-ai-alibaba/spring-ai-alibaba-admin.git
cd admin
```

#### 2. Install and Start Middleware

For first-time setup:

```bash
scripts/install-deps.sh
```

For day-to-day startup:

```bash
scripts/deps-start.sh
scripts/deps-status.sh
```

#### 3. Nacos Configuration (Optional)
If you need to modify the Nacos address, please update the configuration in the `spring-ai-alibaba-admin-server/src/main/resources/application.yml` file
```yaml
nacos:
  server-addr: ${nacos-address}
```

### 4. Start SAA Admin
Run the startup script from the repository root. It starts middleware, builds the full frontend, syncs static assets, packages the backend, starts Admin, and waits for health.

```bash
./start.sh
```

Common commands:

```bash
./start.sh --skip-deps --restart
./start.sh --build --restart
./start.sh --foreground
```

### 5. Access the Application

Open your browser and visit http://localhost:8081/admin to use the SAA Admin platform.

Default login: `saa` / `123456`.

Health check:

```bash
curl http://localhost:8081/actuator/health
```

At this point, you can already manage, debug, evaluate, and observe prompts on the platform. If you expect your Spring AI Alibaba Agent application to integrate with Nacos for prompt loading and dynamic updates, and observe the online running status, refer to the root README section "Connect Your AI Agent Application".

For real model calls, configure an OpenAI-compatible provider, API Key, endpoint, and model types in Model Service Management. Knowledge bases require a `text_embedding` model; `rerank` is optional.

## Configuration

### Database Configuration
```yaml
spring:
  datasource:
    type: com.alibaba.druid.pool.DruidDataSource
    driver-class-name: com.mysql.cj.jdbc.Driver
    url: jdbc:mysql://127.0.0.1:3306/admin
    username: admin
    password: admin
```

### Elasticsearch Configuration
```yaml
spring:
  elasticsearch:
    uris: http://localhost:9200
```

### Nacos Configuration
```yaml
nacos:
  server-addr: 127.0.0.1:8848
```

### Observability Configuration
```yaml
management:
  otlp:
    tracing:
      export:
        enabled: true
      endpoint: http://localhost:4318/v1/traces
```

## License

This project is open source under the Apache License 2.0 license.

## Contributing

We welcome submitting Issues and Pull Requests to help improve the project.
