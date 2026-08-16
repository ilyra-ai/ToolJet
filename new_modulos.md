# Plano diretor de novos módulos — ToolJet CE expandido (2026)

> Status: proposta técnica executável
> Escopo: evolução incremental deste repositório, com prioridade para execução local e self-hosted
> Público: produto, arquitetura, backend, frontend, dados, segurança, SRE e QA
> Estimativas: relativas — S, M, L e XL — sem prometer datas ou homem-dia

## 1. Resumo executivo

Este documento propõe dez módulos novos para transformar o ToolJet CE expandido em uma plataforma local-first de aplicações, automação, integrações, agentes e governança:

1. AI Agent Studio;
2. MCP & Connector Hub;
3. Workflow Orchestrator 2.0;
4. Observability & AgentOps;
5. Secrets & Identity Vault;
6. Data Catalog & Governance;
7. Integration Marketplace;
8. Feature Flags & Experiments;
9. API/Event Gateway;
10. FinOps & Usage Center.

A recomendação é evoluir primeiro como monólito modular, mantendo os contratos de módulo já usados pelo backend NestJS, o banco PostgreSQL/TypeORM, Redis/BullMQ, os workers, o frontend React e a arquitetura de plugins. Separar serviços só deve ocorrer quando métricas reais demonstrarem necessidade de isolamento operacional, escala ou segurança.

As fundações compartilhadas vêm antes das telas mais visíveis: identidade de workload, segredos, autorização, outbox de eventos, idempotência, telemetria e feature flags. AI Agent Studio, MCP e Workflow 2.0 dependem diretamente dessas fundações.

### Resultado esperado

- Agentes com ferramentas, memória controlada, avaliações, aprovação humana e execução auditável.
- Conectividade MCP bidirecional: consumir servidores MCP e expor recursos ToolJet com políticas.
- Workflows duráveis, retomáveis, versionados e seguros.
- Observabilidade unificada de API, queries, plugins, workflows, agentes e custos.
- Segredos com versionamento, rotação, escopo e trilha de acesso.
- Catálogo e linhagem de dados coletados a partir das fontes já conectadas.
- Marketplace de integrações com manifesto, permissões, assinatura e validação.
- Flags e experimentos separados do licenciamento.
- Gateway para APIs, webhooks e eventos com contratos padronizados.
- Custos e consumo por workspace, app, workflow, agente, modelo e conector.

## 2. Limites, linguagem e premissas

### 2.1 Limite de edição

- Este plano descreve módulos novos para o código CE presente neste checkout.
- Os gitlinks/submódulos privados server/ee e frontend/ee não estão disponíveis no repositório atual.
- Portanto, nenhum item deste documento deve ser anunciado como implementação do “ToolJet Enterprise oficial”, nem como equivalência contratual, certificada ou suportada pela ToolJet.
- Uma chave local que habilita recursos não materializa código ausente. A verificação de disponibilidade deve combinar flag, permissão e presença efetiva da capacidade.
- Nomes públicos recomendados: “ToolJet CE expandido”, “módulo local” ou “recurso experimental”. Evitar selo ou promessa “Enterprise”.

### 2.2 Premissas arquiteturais observadas

- Backend: NestJS 11, módulos dinâmicos, TypeORM, PostgreSQL, Redis, BullMQ, workers, WebSocket, PostgREST, CASL, criptografia e auditoria.
- Frontend: React 18, React Router 6, Zustand, React Flow, CodeMirror e páginas orientadas por workspace.
- Integrações: pacotes em plugins/packages com manifest.json, operations.json e implementação TypeScript.
- Persistência: migrations estruturais em server/migrations e migrations de dados em server/data-migrations.
- Execução: módulos existentes de AI, workflows, data sources, plugins, licensing, group permissions, external APIs, audit logs e OpenTelemetry.
- Dependências já presentes que podem ser aproveitadas: BullMQ, bibliotecas Temporal, OpenTelemetry, AI SDK, isolated-vm, AJV, Zod e WebSocket.

### 2.3 Princípios

1. Segurança e autorização são verificadas no servidor; esconder tela não é controle de acesso.
2. Todo registro de domínio é scoped por organization_id/workspace, salvo entidades globais explicitamente aprovadas.
3. Toda operação repetível aceita idempotency_key.
4. Toda alteração administrativa relevante gera audit log imutável.
5. Segredos nunca voltam em texto puro por API depois da gravação.
6. Workflows e agentes usam privilégios mínimos e consentimento explícito para ações de impacto.
7. Telemetria não coleta prompts, payloads ou dados pessoais por padrão.
8. Contratos HTTP e de eventos são versionados antes da implementação.
9. Migrations seguem expandir, preencher, alternar e só depois contrair.
10. Recursos experimentais começam desligados e são liberados por workspace.
11. Falhas externas devem ser isoladas por timeout, retry com jitter, circuit breaker e dead-letter queue.
12. O produto continua operável sem provedor externo de IA.

## 3. Evidências e tendências relevantes em 2026

“Tendência” aqui significa direção técnica sustentada por padrões e projetos oficiais; não é previsão garantida de mercado.

- MCP consolidou um contrato aberto para recursos, prompts e ferramentas. A revisão oficial de 2026 enfatiza núcleo stateless, roteamento, cache e extensões para tarefas longas; a implementação deve negociar versão e usar adaptadores, não congelar uma única revisão: [MCP 2026-07-28](https://blog.modelcontextprotocol.io/posts/2026-07-28/) e [arquitetura MCP](https://modelcontextprotocol.io/specification/2025-06-18/architecture).
- Observabilidade moderna correlaciona traces, métricas, logs e baggage; o repositório já possui instrumentação OpenTelemetry que deve ser ampliada: [OpenTelemetry Signals](https://opentelemetry.io/docs/concepts/signals/) e [Semantic Conventions](https://opentelemetry.io/docs/specs/semconv/).
- Feature flags interoperáveis evitam acoplamento a fornecedor e permitem contexto, hooks e tracking: [OpenFeature](https://openfeature.dev/docs/reference/intro/) e [Evaluation Context](https://openfeature.dev/specification/sections/evaluation-context/).
- Durable execution é adequada a processos que precisam sobreviver a falhas e esperas longas: [Temporal Documentation](https://docs.temporal.io/). Temporal deve ser um adapter opcional, não requisito do MVP local.
- APIs orientadas a eventos ganham portabilidade com [CloudEvents](https://cloudevents.io/) e documentação por [AsyncAPI](https://www.asyncapi.com/docs/reference/specification/v3.0.0); APIs HTTP continuam descritas por [OpenAPI](https://spec.openapis.org/oas/).
- Linhagem de dados pode seguir o modelo aberto de datasets, jobs e runs do [OpenLineage](https://openlineage.io/docs/next/spec/object-model/).
- Identidades curtas e verificáveis entre workloads podem interoperar futuramente com [SPIFFE](https://spiffe.io/docs/latest/spiffe-specs/).
- Agentes exigem controles específicos contra sequestro de objetivo, abuso de ferramenta, excesso de privilégio, cadeia de suprimentos e execução inesperada: [OWASP Top 10 for Agentic Applications 2026](https://genai.owasp.org/resource/owasp-top-10-for-agentic-applications-for-2026/).
- Custo por unidade, inclusive por token, execução e transação, é uma prática central de [FinOps Unit Economics](https://www.finops.org/framework/capabilities/unit-economics/).

## 4. Matriz de prioridade

| Módulo | Prioridade | Impacto | Esforço | Dependências críticas | Primeiro valor entregue |
|---|---:|---:|---:|---|---|
| Secrets & Identity Vault | P0 | Muito alto | L | Encryption, RBAC, audit logs | Segredos versionados e write-only |
| Observability & AgentOps | P0 | Muito alto | L | OpenTelemetry, métricas, eventos | Traces e painel de execuções |
| Workflow Orchestrator 2.0 | P0 | Muito alto | XL | BullMQ, Vault, OTel, flags | Retry, retomada e idempotência |
| AI Agent Studio | P0 | Muito alto | XL | Vault, Workflow 2.0, AgentOps | Agente com tools e aprovação |
| MCP & Connector Hub | P1 | Muito alto | XL | Vault, Gateway, Agent Studio | Cliente MCP remoto controlado |
| API/Event Gateway | P1 | Alto | XL | Redis, Vault, OTel, outbox | API keys, rate limit e webhooks |
| Data Catalog & Governance | P1 | Alto | XL | Data sources, Workflow, OTel | Inventário e classificação |
| Integration Marketplace | P1 | Alto | L | Plugins, Vault, assinaturas | Instalação validada e auditada |
| Feature Flags & Experiments | P1 | Alto | L | OTel, Events, RBAC | Rollout por workspace |
| FinOps & Usage Center | P2 | Alto | L | OTel, AgentOps, Gateway | Uso e orçamento por dimensão |

### 4.1 Dependências em ordem

| Fundação | Consumidores |
|---|---|
| Vault + identidade | Agent Studio, MCP, Workflow, Gateway, Marketplace |
| Outbox/inbox + idempotência | Workflow, Gateway, Marketplace, Data Catalog |
| OpenTelemetry + correlação | todos os módulos |
| Feature flags | rollout de todos os módulos |
| RBAC/grupos | todos os módulos |
| Gateway | MCP remoto, webhooks de workflow, marketplace |
| Workflow 2.0 | agentes duráveis, catalog scanners, rotação de secrets, FinOps aggregation |

## 5. Arquitetura alvo

### 5.1 Visão lógica

| Plano | Responsabilidade | Implementação inicial |
|---|---|---|
| Control plane | CRUD, versões, políticas, RBAC, catálogo, configuração | NestJS + TypeORM + PostgreSQL |
| Execution plane | runs, jobs, timers, retries, compensações | worker NestJS + BullMQ/Redis |
| Connector plane | plugins, MCP, HTTP, eventos e credenciais | plugins + Gateway + Vault |
| Experience plane | telas, editores e painéis | React + React Router + React Flow |
| Telemetry plane | traces, métricas, logs, custos e avaliações | OpenTelemetry + collector/backend opcional |

### 5.2 Decisões estruturais

- Manter os novos módulos em server/src/modules e registrá-los em AppModule.register.
- Usar SubModule e getImportPath apenas quando houver implementação alternativa real; módulos CE novos não devem importar diretórios EE ausentes.
- Repositórios isolam TypeORM; services aplicam domínio; controllers apenas validam e delegam.
- Processors BullMQ não executam no processo web quando WORKER=true estiver separado.
- Eventos de domínio saem por uma tabela domain_outbox na mesma transação da mudança.
- Um dispatcher publica eventos em Redis Streams ou webhook inicialmente; Kafka/NATS permanecem adapters futuros.
- Todos os eventos usam envelope compatível com CloudEvents e schema versionado.
- Frontend cria áreas lazy-loaded por rota para evitar aumentar o bundle inicial.
- APIs novas usam /api/v2; endpoints existentes só são alterados com compatibilidade documentada.

### 5.3 Fundações de dados compartilhadas

| Tabela | Finalidade | Índices/regras mínimas |
|---|---|---|
| domain_outbox | eventos a publicar | status + available_at; aggregate_id; id único |
| domain_inbox | deduplicação de eventos recebidos | unique source + event_id |
| idempotency_keys | resposta estável de comandos repetidos | unique organization_id + scope + key |
| resource_locks | lock lógico com lease | unique resource_type + resource_id |
| module_settings | configuração por workspace/ambiente | unique organization_id + module + environment |
| retention_policies | retenção por tipo de dado | unique organization_id + resource_type |

### 5.4 Regras para migrations

- Uma migration estrutural por agregado coerente; migrations de backfill ficam separadas.
- UUID como chave, timestamptz em UTC, created_at/updated_at e created_by quando aplicável.
- organization_id obrigatório e indexado em dados tenant-scoped.
- Foreign keys explícitas; cascade apenas em filhos sem significado independente.
- Índices parciais para filas e registros ativos; JSONB somente para extensão, não para esconder campos consultados.
- Up não bloqueante para tabelas grandes: adicionar nullable, backfill em lotes, validar, tornar obrigatório.
- Down deve ser implementado quando reversão não perde dados; caso contrário, comentário explícito e plano de restauração.
- Toda migration deve passar em banco vazio e banco com dados representativos.

## 6. Módulo 1 — AI Agent Studio

### Objetivo

Permitir criar, versionar, avaliar, publicar e executar agentes com ferramentas ToolJet, MCP, plugins, queries e workflows, com aprovação humana e limites explícitos.

### Escopo funcional

- Editor de instruções, modelo, parâmetros, ferramentas e política de memória.
- Versões draft/published imutáveis.
- Runs streaming com passos, tool calls, artefatos, custos e estados.
- Aprovação humana antes de ferramentas marcadas como sensíveis.
- Memória de sessão no MVP; memória persistente somente com consentimento e retenção.
- Suites de avaliação com datasets, rubricas e regressão entre versões.
- Guardrails: limite de passos, tokens, custo, tempo, paralelismo e domínio de rede.
- Importação/exportação sem segredos.

### Entidades e migrations

- ai_agents: organization_id, name, slug, status, owner_id.
- ai_agent_versions: agent_id, version, instructions, model_policy_id, memory_policy, checksum, published_at.
- ai_agent_tools: agent_version_id, tool_type, tool_ref_id, input_schema, approval_policy, scopes.
- ai_agent_runs: agent_version_id, initiated_by, status, input_ref, output_ref, trace_id, usage, cost_snapshot.
- ai_agent_run_steps: run_id, sequence, kind, status, parent_step_id, redacted_input, redacted_output, timestamps.
- ai_agent_approval_requests: run_id, step_id, approver_policy, status, expires_at, decided_by.
- ai_memory_scopes e ai_memory_items: owner, namespace, retention, encrypted_content, embedding_ref opcional.
- ai_eval_suites, ai_eval_cases, ai_eval_runs e ai_eval_results.
- ai_model_policies: provedores permitidos, modelos, limites e fallback.

Índices: organization_id + status, agent_id + version unique, run_id + sequence unique, approval status + expires_at e GIN somente onde houver consultas JSONB comprovadas.

### Backend

- Pasta: server/src/modules/agent-studio.
- Controllers: AgentsController, AgentVersionsController, AgentRunsController, AgentApprovalsController e AgentEvalsController.
- Services: AgentDefinitionService, AgentRuntimeService, ToolBrokerService, MemoryPolicyService, ApprovalService, EvalService e ModelRoutingService.
- Queues: agent-run, agent-tool-call, agent-eval e agent-retention.
- Eventos: agent.version.published, agent.run.started/completed/failed, agent.approval.requested/decided e agent.eval.completed.
- Reutilizar AiModule para adapters de modelo; não duplicar credenciais nem streaming.
- ToolBroker resolve capabilities através de um registro tipado; nenhuma tool recebe service locator irrestrito.

### API inicial

- POST /api/v2/agents
- GET/PATCH /api/v2/agents/:id
- POST /api/v2/agents/:id/versions
- POST /api/v2/agents/:id/versions/:version/publish
- POST /api/v2/agent-runs com Idempotency-Key
- GET /api/v2/agent-runs/:id
- GET /api/v2/agent-runs/:id/stream
- POST /api/v2/agent-approvals/:id/approve ou reject
- POST /api/v2/agent-eval-suites/:id/run

### Frontend e UX

- Rota /:workspaceId/agents.
- Abas: Agents, Runs, Approvals, Evaluations, Models e Policies.
- Editor em três painéis: definição, tools/scopes e teste.
- Run inspector em árvore/timeline com payloads redigidos.
- Diff entre versões e comparação de avaliação.
- Confirmação reforçada para publicar e para aprovar ação destrutiva.

### RBAC e flags

- Permissões: agents.read, agents.create, agents.edit, agents.publish, agents.execute, agents.approve, agents.evaluate e agents.admin.
- Feature keys: agentStudio, agentApprovals, agentMemory, agentEvals e agentMcpTools.
- Licensing e feature rollout são camadas diferentes; nenhuma permissão é concedida apenas porque a flag está ativa.

### Critérios de aceite

- Um builder cria, testa, versiona e publica agente sem reiniciar o servidor.
- Uma tool sensível nunca executa sem aprovação quando a política exigir.
- Interrupção do worker não perde o run; ele retoma ou termina de modo consistente.
- Usuário sem agents.execute recebe 403 no servidor.
- Trace, tokens, duração e custo estimado aparecem no run.
- Exportação não contém secret material.

## 7. Módulo 2 — MCP & Connector Hub

### Objetivo

Consumir servidores MCP remotos/locais e, em fase posterior, expor recursos ToolJet como um servidor MCP governado.

### Escopo funcional

- Registro de servidor, transporte, versão de protocolo e método de autenticação.
- Descoberta e cache de capabilities, tools, resources e prompts.
- Teste de conexão e health status.
- Policies por tool: allow, deny, approval required e limites.
- Cliente MCP para Agent Studio e workflows.
- Server MCP ToolJet com catálogo mínimo e escopos.
- Compatibilidade por adapter de versão; negociação explícita.

### Entidades

- mcp_servers, mcp_server_versions, mcp_connections.
- mcp_capability_snapshots e mcp_catalog_items.
- mcp_tool_policies e mcp_tool_bindings.
- mcp_calls, mcp_call_attempts e mcp_approvals.
- mcp_oauth_clients e referências ao Vault, nunca tokens em claro.

### Backend e execução

- Pasta: server/src/modules/mcp-hub.
- McpRegistryService, McpDiscoveryService, McpClientService, McpPolicyService, McpServerFacade e McpProtocolAdapter.
- Transports isolados por interface; stdio permitido apenas em worker sandbox local e com allowlist de executáveis.
- HTTP remoto passa por egress policy, DNS/IP validation, timeout, tamanho máximo e proteção SSRF.
- Queues: mcp-discovery, mcp-call e mcp-health.
- Eventos: mcp.server.registered, mcp.catalog.changed e mcp.call.completed/denied.

### API e UX

- /api/v2/mcp/servers para CRUD e teste.
- /api/v2/mcp/servers/:id/discover.
- /api/v2/mcp/catalog com filtros por capability.
- /api/v2/mcp/calls e /api/v2/mcp/approvals.
- Rota /:workspaceId/integrations/mcp.
- Wizard de conexão, diff de capabilities, policy matrix e call inspector.

### RBAC, flags e aceite

- Permissões: mcp.read, mcp.manage, mcp.connect, mcp.invoke, mcp.approve e mcp.expose.
- Flags: mcpHub, mcpRemoteHttp, mcpLocalStdio e mcpTooljetServer.
- Um servidor não aprovado não pode ser usado por agente.
- Mudança de schema de tool invalida bindings incompatíveis e gera alerta.
- Requisição a IP privado/bloqueado falha antes da conexão, salvo allowlist explícita.
- Cada call registra servidor, tool, ator, decisão, duração, trace e resultado redigido.

## 8. Módulo 3 — Workflow Orchestrator 2.0

### Objetivo

Evoluir os workflows existentes para execução durável, retomável, observável e versionada, preservando compatibilidade durante a migração.

### Capacidades

- Estados waiting, running, retrying, suspended, compensating e terminal.
- Timers, signals, webhooks correlacionados e human tasks.
- Retry policy por erro, exponential backoff com jitter e DLQ.
- Idempotência de nó e workflow.
- Compensação/Saga e timeout por nó/run.
- Concorrência, rate limit, fan-out/fan-in e cancelamento cooperativo.
- Replay seguro de definição versionada; nunca reinterpretar um run antigo com draft novo.
- Backfill e reprocessamento com seleção explícita.

### Entidades

Antes de criar tabelas duplicadas, ADR deve decidir extensão das entidades workflow_execution, workflow_execution_node, workflow_execution_edge, workflow_schedule e workflow_bundle.

Se a extensão for arriscada, criar:

- workflow_definitions_v2 e workflow_definition_versions.
- workflow_runs_v2 e workflow_task_runs.
- workflow_signals, workflow_timers e workflow_checkpoints.
- workflow_compensations e workflow_dead_letters.
- workflow_idempotency e workflow_run_artifacts.

### Backend

- Pasta sugerida: server/src/modules/workflows-v2, convivendo com workflows.
- Engine interface com adapter BullMQ no MVP.
- Adapter Temporal opcional após prova de compatibilidade e operação local.
- WorkflowCompiler valida DAG, schemas, cycles permitidos e dependências.
- WorkflowRuntime grava transição antes/depois da publicação via outbox.
- ActivityExecutor chama plugins, queries, agentes e MCP via brokers com políticas.
- Reconciler detecta leases expirados, timers vencidos e runs órfãos.

### API e frontend

- POST /api/v2/workflows/:id/runs.
- POST /api/v2/workflow-runs/:id/signals/:name.
- POST /api/v2/workflow-runs/:id/cancel, retry e resume.
- GET /api/v2/workflow-runs/:id/timeline.
- Editor React Flow com validação imediata, políticas de retry e compensação.
- Timeline causal, filtros de tentativa, payload redigido, replay e diff de versão.
- Migração assistida de workflow v1 para v2 com relatório de incompatibilidades.

### RBAC, flags e aceite

- Permissões: workflows.read, edit, publish, execute, cancel, retry, signal, inspect_payload e admin.
- Flags: workflowsV2, workflowHumanTasks, workflowCompensation e workflowTemporalAdapter.
- Reiniciar Redis/worker durante uma espera não pode perder timer ou sinal aceito.
- O mesmo Idempotency-Key não cria dois runs.
- Retry respeita policy e não repete activity marcada non-retryable.
- Cancelamento é observável e não deixa task com lease permanente.
- Run antigo conserva definition_version original.

## 9. Módulo 4 — Observability & AgentOps

### Objetivo

Unificar diagnóstico técnico e operacional de requests, queries, plugins, workflows, agentes, MCP e gateway.

### Escopo

- Convenções de spans e correlação trace_id/run_id.
- Dashboards de latência, throughput, erros, filas, tokens, tools e custos.
- Run explorer para agentes e workflows.
- Regras de alerta, SLOs e incident annotations.
- Feedback e scores de qualidade de agentes.
- Exportação OTLP configurável.
- Redação e amostragem por política.

### Persistência

Não armazenar todos os spans de alta cardinalidade no PostgreSQL principal. Usar collector/backend OTLP externo opcional. No banco operacional:

- observability_saved_views.
- observability_alert_rules e observability_alert_events.
- observability_slos e observability_slo_windows.
- agent_feedback, agent_scores e eval_regressions.
- incident_annotations e telemetry_export_configs.

### Instrumentação

- Spans: tooljet.http, tooljet.query, tooljet.plugin, tooljet.workflow.run, tooljet.workflow.task, tooljet.agent.run, tooljet.agent.tool, tooljet.mcp.call e tooljet.gateway.delivery.
- Atributos tenant-safe: organization.id hash/UUID interno, app.id, workflow.id, run.id, connector.type, outcome e error.type.
- Nunca exportar password, token, secret, prompt completo, SQL com valores ou response body por padrão.
- Métricas: RED para APIs; USE para workers/filas; tokens, tool approvals, retries, DLQ, budget burn e eval score.
- Propagar W3C trace context em HTTP, BullMQ e eventos.

### API, UX, RBAC e aceite

- /api/v2/observability/overview, /runs, /alerts, /slos e /exports.
- Rota /:workspaceId/observability com Overview, Traces, Runs, Alerts, SLOs e AgentOps.
- Permissões: observability.read, payload.read, alerts.manage, exports.manage e retention.manage.
- Flags: observabilityCenter, agentOps, sloManagement e otlpExport.
- Um request que dispara workflow, agente e MCP preserva o mesmo trace correlacionável.
- Redaction tests comprovam ausência de secrets.
- Cardinalidade máxima e sampling são configuráveis.
- Falha do exporter não derruba request do produto.

## 10. Módulo 5 — Secrets & Identity Vault

### Objetivo

Centralizar segredos, identidades de integração, rotação e acesso de curta duração, substituindo credenciais espalhadas.

### Escopo

- Secret lógico com versões, ambientes, tags e owner.
- Campos write-only e visualização mascarada.
- Bindings para data source, plugin, workflow, agente, MCP e gateway.
- Rotação manual e jobs de rotação por provider.
- Envelope encryption com provider local inicialmente.
- Adapters opcionais: HashiCorp Vault, KMS e identidade de workload.
- Access log append-only e alertas de uso anômalo.

### Entidades

- vault_secrets e vault_secret_versions.
- vault_secret_bindings.
- vault_key_providers e vault_rotation_policies.
- vault_access_events e vault_lease_records.
- workload_identities e workload_identity_bindings.

O ciphertext, nonce, key_version e authentication tag são separados de metadata. A chave-mestra nunca reside no banco.

### Backend e API

- Pasta: server/src/modules/secrets-vault.
- SecretService, EnvelopeEncryptionService, KeyProviderRegistry, SecretResolver, RotationService e WorkloadIdentityService.
- POST /api/v2/vault/secrets.
- POST /api/v2/vault/secrets/:id/versions.
- GET retorna metadata e masked_value, nunca plaintext.
- POST /api/v2/vault/secrets/:id/rotate.
- POST /api/v2/vault/bindings.
- Resolução interna usa capability token de curta duração; não expor endpoint genérico de reveal.

### UX, RBAC e aceite

- Rota /:workspaceId/settings/secrets.
- Permissões: secrets.list, create, update, rotate, bind, delete, audit e keyProviders.manage.
- Flags: secretsVault, externalKeyProviders e workloadIdentity.
- Usuário autorizado cria e vincula segredo sem conseguir recuperá-lo em claro.
- Rotação preserva versões necessárias a runs em andamento e muda novos runs.
- Logs, exceptions, exports e backups lógicos não exibem plaintext.
- Exclusão falha com 409 quando bindings ativos existem, salvo fluxo de revogação explícito.

## 11. Módulo 6 — Data Catalog & Governance

### Objetivo

Inventariar fontes, schemas, tabelas, campos e fluxos usados pelo ToolJet, com ownership, classificação, qualidade e linhagem.

### Escopo

- Scanner por plugin/data source com capability de introspecção.
- Catálogo pesquisável por nome, tag, owner, tipo e classificação.
- Classificação manual e detectores opt-in para PII.
- Linhagem entre data source, query, workflow, agente e app.
- Regras de qualidade e execução agendada.
- Impact analysis antes de alterar/remover recurso.
- Exportação/emissão compatível com OpenLineage.

### Entidades

- catalog_assets, catalog_asset_versions e catalog_fields.
- catalog_tags, catalog_tag_assignments e catalog_owners.
- catalog_classifications e catalog_classification_assignments.
- lineage_nodes, lineage_edges e lineage_events.
- data_quality_rules, data_quality_runs e data_quality_results.
- governance_policies, governance_policy_bindings e policy_violations.

### Backend e UX

- Pasta: server/src/modules/data-catalog.
- ScannerRegistry, CatalogService, LineageService, ClassificationService, QualityService e ImpactAnalysisService.
- Queues: catalog-scan, lineage-ingest, quality-run e catalog-retention.
- APIs: /api/v2/catalog/assets, /lineage, /impact, /quality-rules e /violations.
- Rota /:workspaceId/data-catalog com busca, detalhes, schema diff, lineage graph e qualidade.
- Conectar eventos de data queries/workflows para lineage runtime; parser SQL gera lineage design-time com nível de confiança.

### RBAC, flags e aceite

- Permissões: catalog.read, scan, classify, own, quality.manage, governance.manage e sensitiveMetadata.read.
- Flags: dataCatalog, dataLineage, dataQuality e piiClassification.
- Scanner nunca lê linhas de negócio quando apenas metadata basta.
- Uma alteração de schema produz versão e diff.
- Linhagem informa evidência e confidence; inferência não é apresentada como fato.
- Usuário sem sensitiveMetadata.read vê nomes sensíveis mascarados.

## 12. Módulo 7 — Integration Marketplace

### Objetivo

Transformar o sistema existente de plugins em marketplace governado, com instalação segura, compatibilidade e ciclo de vida.

### Escopo

- Catálogo local e registro remoto opcional.
- Manifest v2 com capabilities, scopes, secrets, egress e compatibilidade.
- Assinatura de pacote, checksum, SBOM, proveniência e quarentena.
- Instalação, atualização, rollback e desinstalação com dependency checks.
- Contract tests automatizados para operações.
- SDK para connectors, triggers e actions.

### Entidades

- marketplace_packages e marketplace_package_versions.
- marketplace_publishers e publisher_keys.
- marketplace_installations e installation_history.
- marketplace_permissions e marketplace_security_reviews.
- marketplace_compatibility_results e marketplace_quarantine_events.

### Implementação

- Reutilizar plugins/packages, plugins/schemas/manifest.schema.json e operations.schema.json.
- Criar plugins/packages/sdk e schemas/manifest-v2.schema.json após ADR.
- Bundle determinístico; checksum e assinatura validados antes de extrair/executar.
- Execução com egress allowlist, limites de CPU/memória/tempo e API de secrets por binding.
- MarketplaceService nunca executa hook arbitrário no processo web durante instalação.

### API, UX, RBAC e aceite

- /api/v2/marketplace/packages, /versions, /installations e /security.
- Rota /integrations/marketplace com Installed, Updates, Catalog e Security.
- Permissões: marketplace.read, install, update, remove, publish e security.approve.
- Flags: marketplaceV2, thirdPartyPackages e pluginSandbox.
- Pacote com assinatura/checksum inválido é rejeitado.
- Update incompatível não é ativado e permite rollback.
- Manifest declara cada egress host e secret scope.
- Desinstalação com dependências retorna lista de impacto.

## 13. Módulo 8 — Feature Flags & Experiments

### Objetivo

Controlar rollout, kill switches e experimentos sem misturar flags operacionais com licença ou RBAC.

### Escopo

- Flags boolean, string, number e object.
- Ambientes, variantes, targeting, percentual e overrides.
- Avaliação determinística por targeting key.
- Kill switch com propagação rápida.
- Tracking de exposição e conversão.
- Experimentos com hipótese, métricas, janela e guardrails.
- API compatível conceitualmente com OpenFeature e provider interno.

### Entidades

- feature_flags, feature_flag_environments e feature_flag_variants.
- feature_flag_rules e feature_flag_overrides.
- feature_flag_changes e feature_flag_evaluation_aggregates.
- experiments, experiment_variants, experiment_metrics e experiment_assignments.
- experiment_observations e experiment_results.

Eventos brutos têm retenção curta; agregados preservam análise. PII não integra a targeting key.

### Backend e frontend

- Pasta: server/src/modules/feature-flags.
- FlagEvaluationService, InternalOpenFeatureProvider, TargetingService, ExperimentService e ExposureTracker.
- Cache Redis com invalidation por evento e fallback seguro.
- Rota /:workspaceId/feature-flags e /:workspaceId/experiments.
- Simulador mostra resultado, rule matched e reason sem revelar dados proibidos.
- SDK frontend recebe apenas flags client-safe; flags servidoras nunca são despejadas no browser.

### RBAC, flags e aceite

- Permissões: flags.read, create, update, rollout, override, audit e experiments.manage.
- Bootstrap flags: featureFlagsAdmin e experiments; evitar a própria flag controlar a resolução essencial.
- Licensing responde “pode existir”; flag responde “está em rollout”; RBAC responde “quem pode agir”.
- Mesma targeting key recebe variante estável.
- Default seguro é retornado quando provider falha.
- Mudança gera audit log, reason e autor.
- Métrica de conversão não é contabilizada sem exposição correspondente.

## 14. Módulo 9 — API/Event Gateway

### Objetivo

Publicar APIs, webhooks e eventos ToolJet com autenticação, políticas, contratos, observabilidade e entrega confiável.

### Escopo

- API products, routes, versions e lifecycle.
- API keys com hash, scopes, expiração e rotação.
- JWT/OIDC opcional; mTLS/workload identity futuro.
- Rate limit, quotas, request size, CORS, IP policy e schema validation.
- Webhooks assinados, retry, DLQ e replay.
- Event topics/subscriptions com CloudEvents.
- Documentação OpenAPI/AsyncAPI gerada.

### Entidades

- gateway_api_products, gateway_routes e gateway_policies.
- gateway_consumers, gateway_api_keys e gateway_subscriptions.
- event_topics, event_schemas e event_subscriptions.
- event_deliveries, event_delivery_attempts e event_dead_letters.
- gateway_usage_aggregates.

### Backend e execução

- Pasta: server/src/modules/api-event-gateway.
- RouteRegistry, AuthPolicyService, RateLimitService, SchemaRegistry, EventPublisher e DeliveryWorker.
- Redis para rate limit atômico; PostgreSQL para configuração e delivery state.
- Payload grande/artefato usa object storage e referência assinada.
- Assinatura webhook inclui timestamp, delivery_id e body hash; tolerância de replay configurável.

### API, UX, RBAC e aceite

- /api/v2/gateway/products, /routes, /consumers, /keys, /topics e /deliveries.
- Data plane separado em /gateway/v1 e /events/v1.
- Rota /:workspaceId/gateway com APIs, Consumers, Events, Webhooks, Schemas e Analytics.
- Permissões: gateway.read, configure, publish, keys.manage, replay e payload.inspect.
- Flags: apiGateway, eventGateway, webhookDelivery e asyncApiDocs.
- API key é exibida uma única vez e armazenada somente como hash.
- Quota funciona em múltiplas instâncias.
- Webhook duplicado mantém o mesmo delivery_id/idempotency context.
- Contrato inválido falha antes de chamar workflow/app.

## 15. Módulo 10 — FinOps & Usage Center

### Objetivo

Medir consumo, custo estimado, orçamento e eficiência por unidade sem confundir estimativa técnica com faturamento contábil.

### Escopo

- Medidores: API requests, query time, workflow task, agent token, model call, tool call, MCP call, storage e plugin execution.
- Price books versionados por provider/model/recurso.
- Alocação por workspace, app, workflow, agente, data source e cost center.
- Budgets, thresholds, anomaly alerts e forecasts simples.
- Unit economics: custo por run bem-sucedido, usuário ativo, transação ou resultado.
- Recomendações explicáveis de desperdício.
- Importação FOCUS opcional para custos externos.

### Entidades

- usage_events e usage_event_deduplication.
- usage_meters, usage_aggregates e usage_dimensions.
- price_books e price_book_rates.
- cost_allocations, cost_centers e allocation_rules.
- budgets, budget_alerts e anomaly_records.
- unit_metrics, unit_metric_values e optimization_recommendations.

### Backend e UX

- Pasta: server/src/modules/finops.
- MeteringService recebe eventos idempotentes; AggregationWorker gera buckets.
- PricingService escolhe rate pela data de uso; resultados guardam price_book_version.
- BudgetService e AnomalyService nunca bloqueiam execução sem policy explícita.
- Rota /:workspaceId/usage com Overview, Costs, Budgets, Units, Anomalies e Recommendations.
- Mostrar moeda, origem, frescor, cobertura e nível de confiança.

### RBAC, flags e aceite

- Permissões: usage.read, costs.read, budgets.manage, rates.manage, allocation.manage e recommendations.manage.
- Flags: usageCenter, costEstimates, budgets e finopsRecommendations.
- Reprocessar o mesmo usage event não duplica custo.
- Alterar rate futuro não reescreve custo histórico sem job explícito.
- Soma das alocações fecha em 100% ou mostra unallocated.
- Interface distingue “estimado” de “faturado”.
- Alertas respeitam cooldown e não geram tempestade.

## 16. RBAC, permissions e licensing

### 16.1 Modelo comum

Cada módulo registra subject e actions no sistema de ability/grupos existente. Controllers usam InitFeature/guards; services repetem checagem de escopo em operações sensíveis. Repositories sempre filtram organization_id obtido do contexto autenticado, nunca do body como fonte de verdade.

Papéis iniciais:

- Viewer: leitura não sensível.
- Builder: criar/editar recursos de execução.
- Operator: executar, cancelar, retry e operar incidentes.
- Approver: aprovar tool calls, publishers e políticas.
- Module admin: configuração dentro do workspace.
- Instance admin: providers globais, chaves raiz e políticas de instância.

### 16.2 Camadas independentes

| Camada | Pergunta | Falha esperada |
|---|---|---|
| Capability/build | O código e dependência existem? | 404/501 controlado |
| Licensing | A distribuição permite expor o recurso? | 402/403 conforme contrato local |
| Feature flag | O recurso está em rollout? | UI oculta e 404/403 controlado |
| RBAC/CASL | Este ator pode executar a ação? | 403 |
| Policy runtime | Este input/tool/destino é permitido agora? | 403/422 com reason |

Nunca usar nome de plano como autorização direta. Criar feature keys estáveis e mapear licença em um único adapter.

## 17. Segurança e threat model

### 17.1 Ativos

- Credenciais, chaves de API, tokens e encryption keys.
- Dados e metadata de workspaces.
- Instruções, memória, artefatos e outputs de agentes.
- Definições e estado durável de workflows.
- Pacotes, manifests e código de plugins.
- Eventos, webhooks e API keys.
- Telemetria e custos, que também podem revelar comportamento.

### 17.2 Fronteiras de confiança

- Browser ↔ API NestJS.
- API ↔ PostgreSQL/Redis/PostgREST.
- Web process ↔ worker.
- Worker ↔ plugin/código isolado.
- ToolJet ↔ LLM/MCP/API externa.
- Marketplace ↔ publisher/registry.
- Collector ↔ backend de observabilidade.

### 17.3 Principais ameaças e controles

| Ameaça | Controles obrigatórios |
|---|---|
| Prompt/goal injection | separar instrução de dados, tool allowlist, approval, output validation, limites de agência |
| Tool misuse/excessive agency | scopes mínimos, transações/compensações, dry-run, confirmação para impacto |
| SSRF e egress indevido | URL canonicalization, DNS/IP checks, allowlist, bloqueio metadata endpoints, proxy de egress |
| Vazamento de secret | write-only, envelope encryption, redaction, leases, rotação, sem secret em telemetry |
| Escalada cross-tenant | organization_id server-side, testes negativos, FK/índices, policy guard em cada query |
| Supply chain de plugin | assinatura, checksum, SBOM, publisher trust, quarantine, sandbox |
| Event replay/forgery | assinatura, timestamp, nonce/delivery_id, idempotency, janela de replay |
| Execução de código inesperada | isolated-vm/worker separado, limites, filesystem/network deny-by-default |
| DoS/cost explosion | quotas, rate limit, step/token/cost budgets, circuit breaker, kill switch |
| Memory/data poisoning | proveniência, namespace, retenção, confirmação de escrita, reindex seguro |
| Telemetry leakage | classificação, allowlist de atributos, sampling e redaction tests |
| Migration corruption | backup, dry-run, expand/contract, locks curtos e checksum |

### 17.4 Verificações mínimas

- Threat model por módulo antes do primeiro endpoint público.
- SAST, dependency scan, secret scan e SBOM no CI.
- DAST no Gateway, MCP e uploads de marketplace.
- Testes de autorização para cada action.
- Fuzz de schemas MCP/OpenAPI/AsyncAPI e payloads de plugin.
- Red team de agentes alinhado ao OWASP Agentic Top 10.
- Restore test de banco e rotação de chaves antes de produção.

## 18. Telemetria e SLOs

### 18.1 Convenções

- Todo request recebe trace_id e request_id.
- Todo run recebe run_id; toda tentativa, attempt.
- Mensagens BullMQ/outbox propagam traceparent e baggage aprovado.
- Error attributes usam classe/código, não mensagem com payload.
- Métricas de alta cardinalidade não usam email, URL completa, prompt ou query.

### 18.2 SLIs iniciais

| Área | SLIs |
|---|---|
| API | disponibilidade, p50/p95/p99, error rate |
| Workers | queue wait, execution duration, retry e stalled jobs |
| Workflow | completion rate, durable recovery, task failure, timer lag |
| Agent | successful runs, approval latency, tool failure, tokens e eval score |
| MCP/plugins | connect success, call latency, schema drift, circuit open |
| Gateway | authorized requests, throttling, delivery success, DLQ |
| Vault | resolve latency, rotation success, denied access |
| Catalog | scan freshness, coverage e quality pass rate |
| FinOps | ingestion lag, unallocated usage e price coverage |

SLOs começam como dashboards; enforcement e error budgets só depois de baseline real.

## 19. Estratégia de plugins e SDK

### Manifest v2

Campos propostos:

- id, name, version, publisher e minimumTooljetVersion.
- capabilities: query, action, trigger, schemaIntrospection, eventSource ou agentTool.
- permissions: network hosts, secret scopes, filesystem, runtime e data classification.
- schemas: config, operations, outputs e events.
- runtime: node compatibility, timeout, memory e concurrency.
- provenance: checksum, signature, SBOM e source commit.

### SDK

- Tipos TypeScript gerados dos JSON Schemas.
- BaseConnector, QueryOperation, Trigger, AgentTool e CatalogScanner.
- Context API mínima: logger redigido, secret resolver scoped, HTTP client policy-aware, metrics e abort signal.
- Test harness local com fixtures, fake secrets e contract tests.
- Compatibility matrix entre SDK, manifest e ToolJet.
- Deprecation policy com warning antes de breaking change.

### Publicação

1. Validar schema.
2. Executar lint/unit/contract/security tests.
3. Gerar bundle determinístico e SBOM.
4. Assinar checksum.
5. Publicar como candidate.
6. Security review automatizada/manual conforme scopes.
7. Promover e permitir rollout gradual.

## 20. Estratégia de rollout e migração

### Fases por recurso

1. Dark: tabelas/APIs presentes, sem navegação e sem tráfego.
2. Internal: somente instance admin/workspace allowlist.
3. Alpha: dados descartáveis, sem SLA de migração.
4. Beta: migração suportada, telemetria e rollback validados.
5. General availability local: documentação, backup/restore, SLO e suporte operacional definidos.

### Padrão de mudança de dados

1. Expandir schema.
2. Escrever antigo + novo quando necessário.
3. Backfill idempotente e observável.
4. Comparar invariantes.
5. Alternar leitura por flag.
6. Monitorar.
7. Contrair somente em release posterior.

### Rollback

- Desligar flag antes de rollback de código.
- Manter leitor compatível com nova coluna/tabela.
- Não apagar dados em rollback automático.
- Reprocessar outbox/inbox por identificador.
- Versionar manifests, APIs, workflows, agents e price books.

## 21. Cronograma por ondas

Não há datas fixadas. Cada onda só inicia rollout externo quando seus gates forem atendidos.

### Onda 0 — fundações

- ADRs de tenancy, outbox, flags, encryption e telemetry.
- domain_outbox/domain_inbox/idempotency_keys.
- Vault MVP.
- OTel conventions, propagation e redaction.
- Provider interno de feature flags sem experimentos.
- Contratos RBAC comuns.

Gate: testes de cross-tenant, restore, redaction e falha do worker.

### Onda 1 — execução inteligente

- Workflow 2.0 MVP sobre BullMQ.
- Agent Studio MVP com tools internas e aprovação.
- AgentOps/run explorer.
- MCP client HTTP com discovery e policy.

Gate: runs retomáveis, idempotência, approval enforcement e budgets.

### Onda 2 — plataforma de integração

- API/Event Gateway.
- Marketplace v2 e SDK.
- MCP server ToolJet controlado.
- Data Catalog scanner e lineage inicial.

Gate: assinatura, SSRF suite, webhook replay defense e impact analysis.

### Onda 3 — otimização e governança

- Data quality/governance.
- Experiments sobre flags.
- FinOps & Usage Center.
- Adapter Temporal, external vault/KMS e SPIFFE somente se requisitos reais justificarem.

Gate: cobertura de custo, validade estatística revisada, retention e operação documentada.

## 22. Estimativa relativa por MVP

| Entrega | Tamanho | Por quê |
|---|---:|---|
| Outbox, inbox e idempotência | M | fundação transacional transversal |
| Vault local | L | criptografia, bindings, rotação e auditoria |
| OTel/AgentOps base | L | propagação, redaction e UI de correlação |
| Flags sem experimentos | M | provider, cache, rules e admin |
| Workflow 2.0 MVP | XL | estado durável, retries, editor e migração |
| Agent Studio MVP | XL | runtime, tools, streaming, aprovação e avaliações |
| MCP client MVP | L | protocol adapter, auth, policy e SSRF |
| Gateway MVP | XL | data plane, auth, quotas, webhooks e schemas |
| Marketplace v2 | L | SDK, assinatura, lifecycle e sandbox |
| Catalog + lineage MVP | XL | scanners heterogêneos, grafo e UX |
| Experiments | L | assignments, exposures, métricas e análise |
| FinOps MVP | L | metering, pricing, aggregation e budgets |

XL deve ser quebrado em épicos menores antes da execução.

## 23. Estratégia de testes

### 23.1 Pirâmide

- Unit: policies, state machines, schema validation, pricing, targeting e redaction.
- Integration: PostgreSQL real, Redis/BullMQ, migrations, outbox, locks e repositories.
- Contract: OpenAPI, AsyncAPI, CloudEvents, MCP adapters e plugin manifests.
- E2E: browser + API + worker + banco, incluindo papéis diferentes.
- Load: gateway, flag evaluation, queue fan-out, agent streaming e catalog search.
- Security: RBAC, cross-tenant, SSRF, injection, replay, secret leakage e package tampering.
- Chaos: restart de worker/Redis/collector, timeout externo, duplicate events e clock skew.
- Migration: banco vazio, snapshot anterior, grande volume e rollback lógico.

### 23.2 Cenários obrigatórios por módulo

| Módulo | Cenário crítico |
|---|---|
| Agent Studio | tool pede aprovação; worker reinicia; run termina uma vez |
| MCP Hub | DNS rebinding/IP privado é bloqueado; schema drift suspende binding |
| Workflow 2.0 | sinal duplicado e retry não duplicam efeito |
| AgentOps | trace atravessa HTTP → queue → tool sem vazar secret |
| Vault | rotação concorrente e binding antigo permanecem consistentes |
| Catalog | scan metadata-only e lineage inferida mostra confidence |
| Marketplace | pacote adulterado é rejeitado e update faz rollback |
| Flags | rollout percentual estável e fallback retorna default |
| Gateway | rate limit distribuído, assinatura e replay defense |
| FinOps | evento duplicado não duplica custo e rate histórico é preservado |

### 23.3 Qualidade

- Cobertura numérica não substitui cenários; state machines e policies exigem branch coverage alta.
- Cada permission action tem teste allow e deny.
- Cada novo campo sensível entra no redaction test.
- Cada queue processor é testado com entrega at-least-once.
- Performance budgets ficam versionados e medidos no CI noturno.

## 24. Definition of Done global

Um módulo só está concluído quando:

- ADRs relevantes foram aprovados.
- API e eventos têm contrato versionado.
- Migrations rodam em banco vazio e banco atualizado.
- RBAC allow/deny e isolamento tenant têm testes.
- Audit logs cobrem mutações administrativas.
- OTel cobre caminho feliz, erro, retry e queue.
- Secrets e PII passam por redaction.
- Feature flag, kill switch e rollback foram exercitados.
- Unit, integration, E2E e security tests críticos estão verdes.
- UX inclui loading, empty, error, permission denied e accessibility básica.
- Documentação de uso, operação, backup/restore e troubleshooting existe.
- Métricas, alertas e runbook mínimo estão disponíveis.
- Dependências externas e modos degradados estão documentados.
- Não há promessa de Enterprise oficial.

## 25. Critérios de aceite resumidos por módulo

| Módulo | Definition of Done específica |
|---|---|
| Agent Studio | versão imutável, approval obrigatório, retomada e avaliação comparável |
| MCP Hub | version negotiation, policy enforcement, SSRF protection e audit de calls |
| Workflow 2.0 | durable state, idempotência, timers/signals, retry/DLQ e migração v1 |
| AgentOps | trace end-to-end, redaction, dashboards e exporter fail-open |
| Vault | write-only, versioning, bindings, rotation e key separation |
| Data Catalog | metadata scan, ownership, schema diff, lineage confidence e impact |
| Marketplace | manifest v2, assinatura, sandbox, compatibility e rollback |
| Flags | avaliação determinística, cache invalidation, audit e safe default |
| Gateway | hashed keys, quotas distribuídas, schema validation e reliable delivery |
| FinOps | dedupe, price versioning, allocation closure, budgets e confidence |

## 26. Backlog inicial

### Épico FND-1 — Outbox e idempotência

- Como service, quero gravar mudança e evento na mesma transação.
- Como consumer, quero deduplicar event_id.
- Como cliente, quero repetir comando com Idempotency-Key sem duplicar efeito.
- Como operador, quero reprocessar eventos falhos com audit trail.

### Épico SEC-1 — Vault

- Como admin, quero criar secret write-only.
- Como builder, quero vincular secret sem vê-lo.
- Como operador, quero rotacionar e acompanhar bindings.
- Como auditor, quero consultar access events redigidos.

### Épico OBS-1 — Telemetria correlacionada

- Como operador, quero seguir trace de API até worker.
- Como security admin, quero configurar redaction.
- Como SRE, quero alertar por queue lag e error rate.
- Como desenvolvedor, quero instrumentação helper padronizada.

### Épico WF2-1 — Runtime durável

- Como builder, quero retry policy por nó.
- Como sistema externo, quero enviar signal idempotente.
- Como operador, quero cancelar/retry/resume run.
- Como auditor, quero timeline de cada transição.

### Épico AGT-1 — Agente governado

- Como builder, quero registrar tools com schemas.
- Como approver, quero revisar argumentos redigidos.
- Como operador, quero limitar passos/tokens/custo.
- Como QA, quero comparar versões em uma eval suite.

### Épico MCP-1 — Cliente MCP

- Como admin, quero registrar e testar servidor.
- Como sistema, quero descobrir capabilities com versão.
- Como policy owner, quero exigir aprovação por tool.
- Como operador, quero inspecionar call/latência/erro.

### Épico GW-1 — APIs e eventos

- Como admin, quero publicar route com schema.
- Como consumer, quero API key scoped e rotacionável.
- Como subscriber, quero webhook assinado com retries.
- Como operador, quero replay controlado de DLQ.

### Épico MKT-1 — Marketplace seguro

- Como publisher, quero validar manifest localmente.
- Como admin, quero revisar scopes antes de instalar.
- Como sistema, quero validar assinatura e SBOM.
- Como operador, quero rollback de versão.

### Épico CAT-1 — Catálogo e linhagem

- Como data owner, quero pesquisar e classificar assets.
- Como builder, quero ver impacto de mudança.
- Como sistema, quero emitir lineage de query/workflow.
- Como steward, quero regra de qualidade agendada.

### Épico FLG-1 — Rollout e experimentos

- Como admin, quero rollout por workspace/percentual.
- Como developer, quero API compatível com OpenFeature.
- Como product owner, quero associar exposição a conversão.
- Como operador, quero kill switch imediato.

### Épico FIN-1 — Uso e custo

- Como owner, quero custo estimado por app/agente/workflow.
- Como admin, quero configurar price book e budget.
- Como operador, quero anomalia com evidência.
- Como finance partner, quero exportar agregados e allocations.

## 27. ADRs necessários

1. ADR-001 — Monólito modular versus serviços separados.
2. ADR-002 — Outbox/inbox, broker inicial e semântica at-least-once.
3. ADR-003 — Modelo tenant e enforcement de organization_id.
4. ADR-004 — Envelope encryption e providers de chave.
5. ADR-005 — Engine Workflow 2.0 e boundary do adapter Temporal.
6. ADR-006 — Versionamento e compatibilidade de workflow/agent/plugin.
7. ADR-007 — Protocolo MCP suportado e adapters de versão.
8. ADR-008 — Política de egress, SSRF e execução stdio.
9. ADR-009 — OpenTelemetry naming, sampling, redaction e retention.
10. ADR-010 — OpenFeature provider interno e separação de licensing/RBAC.
11. ADR-011 — Manifest v2, assinatura, SBOM e sandbox de plugin.
12. ADR-012 — OpenAPI/AsyncAPI/CloudEvents e schema registry.
13. ADR-013 — Modelo de linhagem e compatibilidade OpenLineage.
14. ADR-014 — Metering, price books e precisão de custo.
15. ADR-015 — Object storage para artefatos/payloads grandes.
16. ADR-016 — Política de memória, embeddings e retenção de agentes.
17. ADR-017 — Estratégia de busca do catálogo.
18. ADR-018 — API versioning e deprecation policy.

## 28. Estrutura de pastas sugerida

    server/src/modules/
      agent-studio/
        ability/ controllers/ dto/ entities/ processors/ repositories/ services/
      mcp-hub/
        adapters/ ability/ controllers/ dto/ processors/ services/ transports/
      workflows-v2/
        compiler/ engine/ processors/ state-machine/ services/
      observability-center/
        controllers/ dto/ exporters/ services/
      secrets-vault/
        key-providers/ resolvers/ rotation/ services/
      data-catalog/
        scanners/ lineage/ quality/ governance/
      integration-marketplace/
        registry/ security/ installers/ services/
      feature-flags/
        evaluation/ providers/ experiments/ services/
      api-event-gateway/
        auth/ policies/ delivery/ schemas/ services/
      finops/
        metering/ pricing/ allocation/ budgets/ recommendations/

    frontend/src/modules/
      AgentStudio/
      McpHub/
      WorkflowsV2/
      ObservabilityCenter/
      SecretsVault/
      DataCatalog/
      IntegrationMarketplace/
      FeatureFlags/
      ApiEventGateway/
      FinOps/

    server/migrations/
      timestamps-NewModuleStructuralMigration.ts

    server/data-migrations/
      timestamps-BackfillNewModuleData.ts

    plugins/
      packages/sdk/
      schemas/manifest-v2.schema.json

    docs/
      architecture/adrs/
      modules/
      runbooks/

Entidades TypeORM podem permanecer em server/src/entities se esse continuar sendo o padrão obrigatório do datasource; o ADR deve evitar dois mecanismos concorrentes de descoberta.

## 29. Requisitos externos e decisões pendentes

| Requisito | Obrigatório no MVP? | Alternativa local |
|---|---:|---|
| Provedor LLM/API key | Não | agentes desabilitados ou provider compatível local |
| Redis | Sim para execução | serviço já presente no Compose |
| PostgreSQL | Sim | serviço já presente no Compose |
| OTLP Collector/backend | Não | métricas/logs locais e exporter desligado |
| Temporal Server | Não | adapter BullMQ |
| Vault/KMS externo | Não | key provider local com segredo fora do banco |
| Object storage | Só para payload grande | volume local com interface de storage |
| Registry de plugins | Não | diretório/registry local |
| Broker Kafka/NATS | Não | outbox + Redis/HTTP |
| SPIFFE/SPIRE | Não | service identity interna e adapter futuro |
| Embedding/vector store | Não no primeiro MVP | memória de sessão e busca semântica desligada |

Decisões de produto pendentes:

- Quais tools exigem aprovação por padrão?
- Qual retenção por tipo de run/payload?
- Quais módulos entram na navegação principal?
- O usuário local aceita dependências adicionais no Docker Compose?
- Quais conectores terão scanner de catálogo primeiro?
- Qual backend OTLP local será suportado oficialmente pelo projeto?

## 30. Riscos e mitigações

| Risco | Probabilidade/impacto | Mitigação |
|---|---|---|
| Escopo simultâneo grande | Alto/Alto | ondas, MVPs, gates e uma fundação por vez |
| Duplicar módulos existentes | Médio/Alto | ADR e extensão por interface antes de criar tabela |
| Confundir desbloqueio com Enterprise oficial | Alto/Alto | linguagem e capability checks explícitos |
| Agente causar efeito destrutivo | Médio/Muito alto | scopes, approval, dry-run, budgets e compensação |
| Estado de workflow inconsistente | Médio/Muito alto | state machine, outbox, idempotência e chaos tests |
| Plugin comprometer host | Médio/Muito alto | assinatura, sandbox, egress deny e worker isolado |
| Telemetria vazar dados | Médio/Alto | allowlist, redaction tests e sampling |
| PostgreSQL virar trace store | Médio/Alto | OTLP backend externo e somente metadata operacional |
| Flags virarem dívida permanente | Alto/Médio | owner, expiry, stale report e cleanup policy |
| Métrica de experimento enganosa | Médio/Alto | hipótese prévia, guardrails e revisão estatística |
| Custo estimado incorreto | Alto/Médio | price version, coverage/confidence e rótulo estimado |
| Migration bloquear banco | Médio/Alto | expand/contract, lotes e índices concorrentes quando aplicável |

## 31. Comandos de validação

Executar a partir da raiz. Ajustar o teste focal conforme os arquivos criados.

    docker compose config
    npm --prefix server run build
    npm --prefix server run lint
    npm --prefix server run test -- --runInBand
    npm --prefix frontend run build
    npm run build:plugins
    npm run all

Para validar migrations em ambiente Docker:

    docker compose exec server npm run db:migrate
    docker compose exec server npm run db:migrate:data

Para validação operacional:

    docker compose ps
    docker compose logs -f server
    docker compose logs -f postgres redis

Checks adicionais que devem entrar no CI:

- validar OpenAPI/AsyncAPI/MCP/manifest JSON Schemas;
- executar banco limpo e upgrade de snapshot;
- gerar e verificar SBOM/assinatura de plugin;
- executar testes cross-tenant e permission matrix;
- executar redaction scanner nos logs de E2E;
- verificar bundle size das novas rotas;
- executar teste de restart do worker durante workflow/agent run;
- executar load test de flags e gateway.

## 32. Ordem recomendada para começar

1. Aprovar ADR-001 a ADR-005, ADR-009 e ADR-010.
2. Implementar outbox, inbox, idempotência e correlação.
3. Entregar Vault local e redaction helpers.
4. Padronizar OTel e criar run explorer mínimo.
5. Criar provider de flags e kill switch.
6. Construir Workflow 2.0 em slice vertical de um único activity type.
7. Construir Agent Studio usando apenas tools internas seguras.
8. Adicionar aprovação e MCP HTTP.
9. Expandir Gateway, Marketplace e Catalog.
10. Ligar experimentos e FinOps somente quando exposures/usage tiverem qualidade mensurável.

Esse sequenciamento reduz retrabalho: todos os módulos visíveis nas ondas seguintes reutilizam autorização, secrets, execução durável, eventos, flags e telemetria já estabilizados.
