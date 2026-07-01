## 二次开发准备

### 接入 claude code

原理: Claude Code 内置 OpenTelemetry 数据导出能力, Langfuse 原生支持符合 OTLP(OpenTelemetry Protocol) 协议数据的解析

问题: 用不了，cc的 OTLP 只发送 metrics/logs，不发送 traces。所以要自行开发实现。原理差不多。

解决：Langfuse 有官方的 hook 实现

### 其他

#### Langfuse 主要支持的链路追踪接入协议
- OTLP
- Langfuse SDK: Langfuse 自己的SDK
- 其他: 框架集成, 如 OpenAI，Langchain等