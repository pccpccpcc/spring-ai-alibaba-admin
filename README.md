# This repository is now part of the [alibaba/spring-ai-alibaba](https://github.com/alibaba/spring-ai-alibaba/tree/main/spring-ai-alibaba-admin) project. The source code has been fully migrated, please submit and follow updates there.

> Spring AI Alibaba Repo: https://github.com/alibaba/spring-ai-alibaba
>
> Spring AI Alibaba Website: https://java2ai.com
>
> Spring AI Alibaba Website Repo: https://github.com/springaialibaba/spring-ai-alibaba-website

English | [中文](./README-zh.md) 

## Project Background

Agent Studio is an AI Agent development and evaluation platform based on Spring AI Alibaba, designed to provide developers and enterprises with a complete AI Agent lifecycle management solution. The platform supports a complete workflow from Prompt engineering, dataset management, evaluator configuration to experiment execution and result analysis, helping users quickly build, test, and optimize AI Agent applications.

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

## System Architecture

### Overall Architecture

![Overall Architecture](./docs/architecture.svg)

## 🚀 Quick Start

### Prerequisites
- 🐳 **Docker**, required by the LoongCollector container
- ☕ **Java 17+**, JDK 21 recommended
- **Maven**: 3.8+
- **Node.js**: 20.x+, required to build the full console frontend
- 🌐 **AI Model Provider API Keys**, supporting OpenAI-compatible providers, DashScope, DeepSeek, and others

### Running from Source Code

#### 1. Clone the Project

```bash
git clone https://github.com/spring-ai-alibaba/spring-ai-alibaba-admin.git
cd spring-ai-alibaba-admin
```

#### 2. Install and Start Local Middleware

For a new machine or a reset environment, run:

```bash
scripts/install-deps.sh
```

For day-to-day development, start the already installed middleware:

```bash
scripts/deps-start.sh
scripts/deps-status.sh
```

The scripts manage MySQL, Redis, Elasticsearch, Kibana, Nacos, RocketMQ, and LoongCollector. They also initialize MySQL schemas, Elasticsearch trace pipeline/index, and the RocketMQ topic/consumer group required by document indexing.

#### 3. Nacos Configuration (Optional)
If you need to modify the Nacos address, please update the configuration in the `spring-ai-alibaba-admin-server-start/src/main/resources/application.yml` file
```yaml
nacos:
  server-addr: ${nacos-address}
```

### 4. Start SAA Admin
Run the startup script from the repository root. `start.sh` delegates to `scripts/admin-start.sh` and by default:

1. Starts and verifies middleware
2. Builds the full frontend assets, including App / Workflow, Knowledge, MCP, and Model Service pages
3. Syncs frontend assets into backend `static`
4. Packages and starts the backend service
5. Waits for the health check to pass

```bash
./start.sh
```

Common commands:

```bash
./start.sh --skip-deps --restart      # restart Admin only when middleware is already running
./start.sh --build --restart          # force rebuild frontend/backend and restart
./start.sh --foreground               # run in foreground for live logs
scripts/deps-stop.sh                  # stop middleware
```

### 5. Access the Application

Open your browser and visit http://localhost:8081/admin to use the SAA Admin platform.

Default login:

- Username: `saa`
- Password: `123456`

Health check:

```bash
curl http://localhost:8081/actuator/health
```

If the sidebar is missing App / Workflow or Knowledge pages, hard refresh the browser first. If it is still missing, run `./start.sh --build --restart` to rebuild and sync the full frontend bundle.

At this point, you can already manage, debug, evaluate, and observe prompts on the platform. If you expect your Spring AI Alibaba Agent application to integrate with Nacos for prompt loading and dynamic updates, and observe the online running status, you can refer to step 7 to configure your AI Agent application.

### 6. Configure Model Services

The default SQL includes Tongyi / Qwen model records, but real calls still require valid credentials. Configure model providers in the console:

1. Log in to `http://localhost:8081/admin`
2. Open Model Service Management
3. Add an OpenAI-compatible provider with API Key and endpoint
4. Add models with the correct types: `llm`, `text_embedding`, and optionally `rerank`

Knowledge bases require a usable `text_embedding` model. `rerank` is optional; when omitted, retrieval uses vector search only.

### 7. Connect Your AI Agent Application
In your Spring AI Alibaba Agent application, add the following dependencies
```xml
<dependencies>
    <!-- Introduce spring ai alibaba agent nacos proxy module -->
    <dependency>
        <groupId>com.alibaba.cloud.ai</groupId>
        <artifactId>spring-ai-alibaba-agent-nacos</artifactId>
        <version>{spring.ai.alibaba.version}</version>
    </dependency>

    <!-- Introduce observability module -->

    <dependency>
        <groupId>com.alibaba.cloud.ai</groupId>
        <artifactId>spring-ai-alibaba-autoconfigure-arms-observation</artifactId>
        <version>{spring.ai.alibaba.version}</version>
    </dependency>
    
    
    <!-- For implementing various OTel related components, such as automatic loading of Tracer, Exporter -->
    <dependency>
        <groupId>org.springframework.boot</groupId>
        <artifactId>spring-boot-starter-actuator</artifactId>
    </dependency>
    
    <!-- For connecting micrometer generated metrics to otlp format -->
    <dependency>
        <groupId>io.micrometer</groupId>
        <artifactId>micrometer-registry-otlp</artifactId>
    </dependency>
    
    <!-- For replacing micrometer underlying trace tracer with OTel tracer -->
    <dependency>
        <groupId>io.micrometer</groupId>
        <artifactId>micrometer-tracing-bridge-otel</artifactId>
    </dependency>
    
    <!-- For reporting spans generated by OTel tracer according to otlp protocol -->
    <dependency>
        <groupId>io.opentelemetry</groupId>
        <artifactId>opentelemetry-exporter-otlp</artifactId>
    </dependency>

    <dependency>
        <groupId>org.springframework.ai</groupId>
        <artifactId>spring-ai-autoconfigure-model-tool</artifactId>
        <version>1.0.0</version>
    </dependency>
</dependencies>
``` 

Specify Nacos address and promptKey
```yaml
    spring.ai.alibaba.agent.proxy.nacos.serverAddr={replace nacos address, example: 127.0.0.1:8848}
    spring.ai.alibaba.agent.proxy.nacos.username={replace nacos username, example: nacos}
    spring.ai.alibaba.agent.proxy.nacos.password={replace nacos password, example: nacos}
    spring.ai.alibaba.agent.proxy.nacos.promptKey={replace with promptKey, example: mse-nacos-helper} 
```

Set observability parameters

```yaml
    management.otlp.tracing.export.enabled=true
    management.tracing.sampling.probability=1.0
    management.otlp.tracing.endpoint=http://{admin address}:4318/v1/traces
    management.otlp.metrics.export.enabled=false
    management.otlp.logging.export.enabled=false
    management.opentelemetry.resource-attributes.service.name=agent-nacos-prompt-test
    management.opentelemetry.resource-attributes.service.version=1.0
    spring.ai.chat.client.observations.log-prompt=true
    spring.ai.chat.observations.log-prompt=true
    spring.ai.chat.observations.log-completion=true
    spring.ai.image.observations.log-prompt=true
    spring.ai.vectorstore.observations.log-query-response=true
    spring.ai.alibaba.arms.enabled=true
    spring.ai.alibaba.arms.tool.enabled=true
    spring.ai.alibaba.arms.model.capture-input=true
    spring.ai.alibaba.arms.model.capture-output=true
```

## License

This project is open source under the Apache License 2.0 license.

## Contributing

We welcome submitting Issues and Pull Requests to help improve the project.

 
