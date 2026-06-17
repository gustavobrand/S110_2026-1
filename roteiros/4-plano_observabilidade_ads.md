# Plano de Observabilidade — ADS

## Plano de 4 aulas de observabilidade para disciplina de infraestrutura ágil, cobrindo métricas, logs, traces e troubleshooting

00 · Visão geral
01 · Métricas (Prometheus)
02 · Logs (Loki)
03 · Traces (Jaeger)
04 · Troubleshooting

1Os 3 pilares
2Plano de aulas
3Stack escolhida

Visão geral
Observabilidade: os 3 pilares

Observabilidade é a capacidade de entender o estado interno de um sistema a partir de suas saídas externas. No contexto do voteapp em Kubernetes, isso significa responder: o que está acontecendo, onde está falhando, e por quê?

📊

Métricas

Números ao longo do tempo. CPU, memória, requisições/s, latência, erros. Respondem "o quê está errado".

Prometheus + Grafana

📋

Logs

Eventos discretos com contexto. Mensagens de erro, stack traces, eventos de negócio. Respondem "o que aconteceu".

Loki + Grafana

🔍

Traces

Rastreamento de uma requisição através de múltiplos serviços. Respondem "onde está o gargalo".

Jaeger + OpenTelemetry

Conexão com o que já foi visto. No roteiro de evolução do k8s, os alunos instalaram Prometheus e Grafana. Métricas já estão no ar. Agora vamos completar os outros dois pilares — logs centralizados com Loki e traces distribuídos com Jaeger — e juntar tudo num cenário real de troubleshooting.

← anteriorpróximo →

Visão geral
Plano das 4 aulas

Aula 1

Métricas avançadas com Prometheus

- PromQL além do básico

- Alertas com Alertmanager

- Dashboard customizado no Grafana

- Métricas de negócio (votos/min)

lab prático

Aula 2

Logs centralizados com Loki

- Por que centralizar logs?

- Instalar Loki + Promtail

- Consultas com LogQL

- Correlacionar log + métrica no Grafana

lab prático

Aula 3

Rastreamento distribuído com Jaeger

- Conceito de trace e span

- OpenTelemetry como padrão

- Instrumentar o serviço vote

- Visualizar traces no Jaeger UI

lab prático

Aula 4

Troubleshooting real — cenários de falha

- Injeção de falhas controlada

- Investigar com métricas → logs → traces

- Runbook como entregável

- SLO / SLA / error budget (conceito)

cenário investigativo

← anteriorpróximo →

Visão geral
Stack escolhida — PLG

A stack PLG (Prometheus + Loki + Grafana) é totalmente open-source, roda bem no k3d, e é amplamente usada em produção. Um único Grafana serve como janela para os 3 pilares.

componentes e função

Prometheus coleta e armazena métricas (já instalado)
Grafana visualização — métricas, logs e traces (já instalado)
Loki armazena e indexa logs dos containers
Promtail agente que coleta logs dos pods e envia ao Loki
Jaeger backend de traces distribuídos
OpenTelemetry SDK/coletor padrão para instrumentar aplicações

Prometheus e Grafana já estão no ar desde o roteiro anterior.
Loki + Promtail → Aula 2
Jaeger + OTel → Aula 3

Tudo no mesmo Grafana. Um dos pontos mais poderosos dessa stack é que o Grafana conecta ao Prometheus, ao Loki e ao Jaeger como data sources separados. O aluno abre uma única ferramenta e navega entre métricas, logs e traces — exatamente como faz um SRE em produção.

← anteriorcomeçar aulas →

1PromQL
2Alertmanager
3Dashboard
4Métricas negócio

Aula 1 — Métricas
PromQL além do básico

No roteiro anterior os alunos viram queries simples. Aqui aprofundamos com as funções que aparecem em dashboards reais — taxa de erros, latência por percentil, disponibilidade.

queries progressivas — colar no Prometheus :9090copiar

# 1. taxa de requisições HTTP por segundo (últimos 2min)
rate(http_requests_total{namespace="voteapp"}[2m])

# 2. taxa de ERROS (status 5xx) por segundo
rate(http_requests_total{namespace="voteapp", status=~"5.."}[2m])

# 3. percentual de erros em relação ao total
rate(http_requests_total{status=~"5.."}[2m])
/ rate(http_requests_total[2m]) * 100

# 4. latência no percentil 95 (p95)
histogram_quantile(0.95,
rate(http_request_duration_seconds_bucket{namespace="voteapp"}[5m])
)

# 5. uso de memória em MiB
container_memory_working_set_bytes{namespace="voteapp"}
/ 1024 / 1024

# 6. quantos pods do vote estão prontos agora?
kube_deployment_status_replicas_ready{
namespace="voteapp", deployment="vote"
}

Os 4 sinais de ouro (Google SRE). Toda observabilidade de produção orbita esses quatro: latência (quanto tempo cada requisição leva), tráfego (quantas req/s), erros (taxa de falhas) e saturação (quão "cheio" está o sistema — CPU, memória, filas). PromQL consegue expressar todos os quatro.

← anteriorpróximo →

Aula 1 — Métricas
Alertas com Alertmanager

Prometheus detecta condições anormais via regras de alerta. O Alertmanager roteia e envia as notificações. Vamos habilitar o Alertmanager (que desabilitamos no roteiro anterior) e criar uma regra para o voteapp.

k8s/prometheus-rules.yamlcopiar

apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
name: voteapp-alerts
namespace: monitoring
labels:
release: kube-prometheus-stack
spec:
groups:
- name: voteapp
rules:

- alert: VotePodDown
expr: kube_deployment_status_replicas_ready{deployment="vote"}
for: 1m
labels:
severity: critical
annotations:
summary: "Nenhum pod do vote está pronto"

- alert: VoteHighCPU
expr: |
rate(container_cpu_usage_seconds_total{
namespace="voteapp", container="vote"}[2m]) > 0.25
for: 2m
labels:
severity: warning
annotations:
summary: "CPU do vote acima de 25% por 2 minutos"

terminal — aplicar e verificarcopiar

kubectl apply -f k8s/prometheus-rules.yaml

# verificar no Prometheus UI: Status → Rules
# http://localhost:9090/rules

# disparar o alerta VotePodDown manualmente para testar
kubectl scale deployment vote --replicas=0 -n voteapp
# aguardar ~1min → alerta dispara em Status → Alerts
kubectl scale deployment vote --replicas=2 -n voteapp

← anteriorpróximo →

Aula 1 — Métricas
Dashboard customizado no Grafana

Os alunos criam um dashboard do zero para o voteapp — não importado, mas construído painel a painel. O objetivo é entender como os painéis se conectam e contar uma história com os dados.

painéis sugeridos para o dashboard "VoteApp Overview"

Painel 1 — Stat: réplicas prontas do vote
query: kube_deployment_status_replicas_ready{deployment="vote"}

Painel 2 — Time series: CPU dos pods vote ao longo do tempo
query: rate(container_cpu_usage_seconds_total{container="vote"}[2m])

Painel 3 — Time series: memória usada (MiB)
query: container_memory_working_set_bytes{container="vote"} / 1048576

Painel 4 — Stat: número de pods no namespace voteapp
query: count(kube_pod_info{namespace="voteapp"})

Painel 5 — Alert list: alertas ativos do voteapp
(widget nativo do Grafana, sem query manual)

Dica de aula. Deixar os alunos montarem o dashboard enquanto o load-generator do HPA está rodando. Eles veem os painéis "mexendo" em tempo real enquanto constroem — muito mais motivador do que dados estáticos.

← anteriorpróximo →

Aula 1 — Métricas
Métricas de negócio — votos por minuto

Métricas de infra (CPU, memória) são importantes, mas métricas de negócio são o que realmente importa para o produto. Vamos adicionar um contador de votos ao serviço Python.

vote/app.py — adicionar counter Prometheuscopiar

# instalar: pip install prometheus-client
from prometheus_client import Counter, make_wsgi_app
from werkzeug.middleware.dispatcher import DispatcherMiddleware

# definir o contador por opção de voto
vote_counter = Counter(
'voteapp_votes_total',
'Total de votos registrados',
['option'] # label: "cats" ou "dogs"
)

# na rota POST /:
@app.route("/", methods=['POST'])
def vote():
vote = request.form['vote']
vote_counter.labels(option=vote).inc() # incrementar
# ... resto da lógica

# expor /metrics
app.wsgi_app = DispatcherMiddleware(app.wsgi_app, {
'/metrics': make_wsgi_app()
})

PromQL — taxa de votos por minutocopiar

# votos por minuto por opção
rate(voteapp_votes_total[1m]) * 60

# proporção cats vs dogs em %
rate(voteapp_votes_total{option="cats"}[5m])
/ rate(voteapp_votes_total[5m]) * 100

Entregável da aula 1

- Dashboard "VoteApp Overview" com os 5 painéis funcionando

- Alerta `VotePodDown` disparado e capturado em print

- Métrica de negócio `voteapp_votes_total` aparecendo no Prometheus

← anteriorpróxima aula →

1Por que Loki
2Instalar stack
3LogQL
4Correlação

Aula 2 — Logs
Por que centralizar logs?

Com um único pod, `kubectl logs` basta. Com 5 serviços e 3 réplicas cada, você tem 15 streams de log separados — e quando um pod crasha, os logs somem junto com ele.

O problema do `kubectl logs` em produção. Ele lê logs do container atual. Se o pod foi reiniciado (OOMKilled, CrashLoop), os logs da falha se perdem. Se há 10 réplicas do mesmo serviço, você precisaria de um loop para agregar. Loki resolve os dois problemas: persiste e agrega.

comparação — kubectl logs vs Loki

kubectl logs
✗ perde logs quando pod crasha
✗ um stream por pod — sem agregação
✗ sem busca por conteúdo
✗ sem correlação com métricas

Loki + Grafana
✓ persiste logs independente do ciclo de vida do pod
✓ agrega todos os pods de um Deployment
✓ busca full-text com LogQL
✓ correlaciona com métricas e traces no mesmo Grafana

← anteriorpróximo →

Aula 2 — Logs
Instalar Loki + Promtail via Helm

O Promtail é um agente que roda como DaemonSet — um pod em cada nó do cluster — e coleta automaticamente os logs de todos os containers, enviando ao Loki.

terminalcopiar

helm repo add grafana https://grafana.github.io/helm-charts
helm repo update

# instalar Loki (modo monolítico, simples para lab)
helm install loki grafana/loki \
--namespace monitoring \
--set loki.commonConfig.replication_factor=1 \
--set loki.storage.type=filesystem \
--set singleBinary.replicas=1

# instalar Promtail (agente coletor de logs)
helm install promtail grafana/promtail \
--namespace monitoring \
--set config.lokiAddress=http://loki:3100/loki/api/v1/push

# verificar
kubectl get pods -n monitoring | grep -E "loki|promtail"

# Promtail deve ter 3 pods (1 por nó do cluster k3d)

adicionar Loki como data source no Grafana

1. Grafana → Connections → Data sources → Add
2. Tipo: Loki
3. URL: http://loki.monitoring.svc.cluster.local:3100
4. Save & Test → deve mostrar "Data source connected"

← anteriorpróximo →

Aula 2 — Logs
Consultas com LogQL

LogQL é a linguagem de query do Loki — parecida com PromQL mas para texto. A sintaxe base é um seletor de stream seguido de filtros.

LogQL — queries progressivas no Grafana (Explore)copiar

# 1. todos os logs do namespace voteapp
{namespace="voteapp"}

# 2. só logs do serviço vote
{namespace="voteapp", app="vote"}

# 3. filtrar por texto (linhas com "error")
{namespace="voteapp"} |= "error"

# 4. excluir linhas de health check
{namespace="voteapp", app="vote"}
|= "POST /"
!= "GET /health"

# 5. extrair campo do log com regex e contar
{namespace="voteapp", app="vote"}
| regexp `voted for (?P\w+)`
| count_over_time([1m])

# 6. taxa de linhas de erro por segundo
rate({namespace="voteapp"} |= "error" [1m])

LogQL vs PromQL. PromQL opera sobre séries numéricas. LogQL opera sobre streams de texto mas pode agregar para números (com `rate()`, `count_over_time()`). O resultado pode aparecer como time series no Grafana — isso é o que permite colocar "taxa de erros nos logs" no mesmo dashboard de métricas.

← anteriorpróximo →

Aula 2 — Logs
Correlacionar log + métrica no Grafana

O recurso mais poderoso da stack PLG: a partir de um pico de CPU no dashboard de métricas, navegar diretamente para os logs daquele período com um clique.

configurar derived fields no data source Loki

Grafana → Data sources → Loki → Derived Fields:

Name: TraceID
Regex: traceID=(\w+)
Query: ${__value.raw}
URL: http://localhost:16686/trace/${__value.raw}
# isso cria um link clicável de log → trace no Jaeger

configurar data link no painel de métricas

No painel de CPU do Grafana:
Edit → Data links → Add link:
Title: "Ver logs deste período"
URL: /explore?datasource=loki
&left={"queries":[{"expr":"{app=\"vote\"}"}],
"range":{"from":"${__from}","to":"${__to}"}}

Entregável da aula 2

- Loki + Promtail rodando — `kubectl get pods -n monitoring` mostra tudo Running

- Query LogQL filtrando logs de erro do voteapp no Grafana Explore

- Painel no dashboard com taxa de linhas de erro (LogQL → time series)

- Demonstrar navegação métrica → logs pelo data link

← anteriorpróxima aula →

1Conceito
2Instalar Jaeger
3Instrumentar
4Jaeger UI

Aula 3 — Traces
O que é rastreamento distribuído

Métricas dizem que algo está lento. Logs dizem o que aconteceu. Traces mostram exatamente onde o tempo foi gasto — através de todos os serviços que uma requisição atravessou.

Trace vs Span. Um trace é o registro completo de uma requisição do início ao fim. Ele é composto de spans — cada span representa uma operação dentro de um serviço (receber a requisição, consultar o Redis, responder). Os spans têm duração, status e podem ter spans filhos formando uma árvore.

exemplo de trace do voteapp

Requisição: POST /vote (usuário clica em "Cats")

Trace (total: 45ms):
├── vote-service: receber POST /vote [0ms → 45ms]
│ ├── redis: SET vote:user123 "cats" [2ms → 8ms]
│ └── redis: EXPIRE vote:user123 86400 [8ms → 12ms]
│
# o worker processa assincronamente:
└── worker: processar voto da fila [assíncrono]
└── postgres: INSERT INTO votes... [5ms → 18ms]

# o trace mostra: Redis está rápido (6ms), Postgres ok (13ms)
# se Postgres demorar 800ms → gargalo identificado

← anteriorpróximo →

Aula 3 — Traces
Instalar Jaeger no cluster

k8s/jaeger.yaml — modo all-in-one para labcopiar

apiVersion: apps/v1
kind: Deployment
metadata:
name: jaeger
namespace: monitoring
spec:
replicas: 1
selector:
matchLabels:
app: jaeger
template:
metadata:
labels:
app: jaeger
spec:
containers:
- name: jaeger
image: jaegertracing/all-in-one:latest
env:
- name: COLLECTOR_OTLP_ENABLED
value: "true"
ports:
- containerPort: 16686 # UI
- containerPort: 4317 # OTLP gRPC
- containerPort: 4318 # OTLP HTTP
---
apiVersion: v1
kind: Service
metadata:
name: jaeger
namespace: monitoring
spec:
selector:
app: jaeger
ports:
- name: ui
port: 16686
- name: otlp-grpc
port: 4317
- name: otlp-http
port: 4318

terminalcopiar

kubectl apply -f k8s/jaeger.yaml

# acessar UI do Jaeger
kubectl port-forward -n monitoring svc/jaeger 16686:16686 &
# http://localhost:16686

← anteriorpróximo →

Aula 3 — Traces
Instrumentar o serviço vote com OpenTelemetry

OpenTelemetry é o padrão aberto para instrumentação. Adicionamos algumas linhas ao `app.py` do vote e os traces aparecem automaticamente no Jaeger.

vote/requirements.txt — adicionar dependênciascopiar

opentelemetry-distro
opentelemetry-exporter-otlp
opentelemetry-instrumentation-flask
opentelemetry-instrumentation-redis

vote/app.py — inicializar OpenTelemetrycopiar

from opentelemetry import trace
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import BatchSpanProcessor
from opentelemetry.exporter.otlp.proto.http.trace_exporter import OTLPSpanExporter
from opentelemetry.instrumentation.flask import FlaskInstrumentor
from opentelemetry.instrumentation.redis import RedisInstrumentor

# inicializar provider e exporter
provider = TracerProvider()
exporter = OTLPSpanExporter(
endpoint="http://jaeger.monitoring.svc.cluster.local:4318/v1/traces"
)
provider.add_span_processor(BatchSpanProcessor(exporter))
trace.set_tracer_provider(provider)

# instrumentar Flask e Redis automaticamente
FlaskInstrumentor().instrument_app(app)
RedisInstrumentor().instrument()

# agora TODA requisição Flask e chamada Redis
# gera spans automaticamente — sem mudar mais nada

Auto-instrumentação. O `FlaskInstrumentor` e o `RedisInstrumentor` "envolvem" as bibliotecas existentes e geram spans sem modificar o código de negócio. Para spans customizados (ex: "processar voto"), usa-se `tracer.start_as_current_span("processar-voto")`.

← anteriorpróximo →

Aula 3 — Traces
Explorar traces no Jaeger UI e Grafana

gerar tráfego e explorarcopiar

# gerar alguns votos para ter traces
for i in $(seq 1 20); do
curl -s -X POST http://vote.local/ -d "vote=cats" > /dev/null
curl -s -X POST http://vote.local/ -d "vote=dogs" > /dev/null
done

# Jaeger UI: http://localhost:16686
# Service: vote → Find Traces
# ver waterfall dos spans por requisição

adicionar Jaeger como data source no Grafana

Grafana → Connections → Data sources → Add → Jaeger
URL: http://jaeger.monitoring.svc.cluster.local:16686
Save & Test

# agora em Grafana Explore, selecionar Jaeger
# buscar por service: vote
# clicar em um trace → ver a árvore de spans

Entregável da aula 3

- Print do Jaeger UI mostrando um trace completo do serviço vote

- Identificar qual span (Redis ou Flask) tem maior latência

- Trace visível também no Grafana Explore via data source Jaeger

← anteriorpróxima aula →

1Metodologia
2Cenários de falha
3Runbook
4SLO / Error budget

Aula 4 — Troubleshooting
Metodologia de investigação

A aula de troubleshooting é o grand finale — os alunos usam tudo que aprenderam para investigar falhas injetadas intencionalmente no voteapp. A dupla recebe um sintoma e precisa chegar à causa raiz.

O fluxo padrão de investigação. Sempre parte do sintoma mais visível e vai afunilando: métricas (o quê e quando?) → logs (o que aconteceu?) → traces (onde na cadeia de serviços?). Cada pilar estreita o espaço de busca até chegar à linha de código ou configuração responsável.

metodologia USE + RED

USE (para recursos de infraestrutura)
Utilization → qual % do recurso está sendo usado?
Saturation → há fila/espera? o recurso está sobrecarregado?
Errors → há erros nesse recurso?

RED (para serviços / APIs)
Rate → quantas requisições por segundo?
Errors → qual a taxa de erros?
Duration → qual a latência (p50, p95, p99)?

# USE para Redis, Postgres, nós k8s
# RED para vote service, result service, worker

← anteriorpróximo →

Aula 4 — Troubleshooting
Cenários de falha para investigação em dupla

O professor injeta uma das falhas abaixo sem revelar qual. A dupla tem 20 minutos para diagnosticar usando métricas, logs e traces, e apresentar a causa raiz.

cenário A — OOMKilled (pod morto por falta de memória)copiar

# injetar: limit de memória muito baixo no vote
kubectl patch deployment vote -n voteapp \
--type=json \
-p='[{"op":"replace","path":"/spec/template/spec/containers/0/resources/limits/memory","value":"10Mi"}]'

# sintoma: pods reiniciando constantemente (CrashLoopBackOff)
# pista métrica: kube_pod_container_status_restarts_total subindo
# pista log: "Killed" nos logs do pod anterior (kubectl logs --previous)
# causa raiz: memory limit abaixo do necessário

cenário B — Redis indisponívelcopiar

# injetar: escalar Redis para 0 réplicas
kubectl scale deployment redis --replicas=0 -n voteapp

# sintoma: votos não funcionam, página carrega mas dá erro ao votar
# pista métrica: taxa de erros 5xx no vote sobe
# pista log: "Connection refused" ou "redis.exceptions.ConnectionError"
# pista trace: span Redis com status ERROR e duração alta (timeout)
# causa raiz: Redis indisponível

cenário C — worker com bug (image quebrada)copiar

# injetar: image inexistente no worker (simula deploy com bug)
kubectl set image deployment/worker \
worker=dockersamples/examplevotingapp_worker:broken \
-n voteapp

# sintoma: votos somem — aparecem na fila mas não chegam ao Postgres
# pista métrica: pods do worker em ImagePullBackOff
# pista log: worker sem logs novos (pod não iniciou)
# kubectl get events -n voteapp → "Failed to pull image"
# causa raiz: image inválida no worker

← anteriorpróximo →

Aula 4 — Troubleshooting
Runbook como entregável

Um runbook é um documento que descreve como diagnosticar e resolver um problema específico. É o entregável da aula 4 — cada dupla documenta o cenário que investigou.

template de runbook — runbook-redis-down.mdcopiar

# Runbook: Redis indisponível

## Sintoma
Votos não são registrados. Usuário recebe erro 500 ao clicar.

## Detecção
- Alerta: VotePodDown dispara (ou taxa de 5xx > threshold)
- Dashboard: painel de erros mostra pico repentino

## Diagnóstico

### 1. verificar pods
```bash
kubectl get pods -n voteapp
# worker e vote podem estar em CrashLoopBackOff
```

### 2. verificar logs do vote
```bash
kubectl logs -l app=vote -n voteapp --tail=50
# procurar: "ConnectionError", "redis", "ECONNREFUSED"
```

### 3. verificar Redis
```bash
kubectl get deployment redis -n voteapp
kubectl describe pod -l app=redis -n voteapp
```

## Resolução
```bash
kubectl scale deployment redis --replicas=1 -n voteapp
kubectl rollout status deployment/redis -n voteapp
```

## Prevenção
- Adicionar healthcheck no Redis (já feito no roteiro base)
- Configurar readinessProbe no vote apontando para conexão Redis
- Alerta: redis_connected_clients == 0

← anteriorpróximo →

Aula 4 — Troubleshooting
SLO, SLA e Error Budget — conceito de fechamento

Uma forma elegante de fechar a disciplina: conectar tudo que foi visto (métricas, alertas, disponibilidade) ao vocabulário que os alunos vão encontrar em vagas de SRE e DevOps.

SLI → SLO → SLA. SLI (Service Level Indicator) é a métrica medida — ex: "% de requisições com status 2xx". SLO (Objective) é a meta — ex: "99,5% das requisições bem-sucedidas". SLA (Agreement) é o contrato com penalidades se o SLO não for atingido. O Prometheus mede o SLI; o Grafana alerta quando o SLO está em risco.

PromQL — calcular SLI de disponibilidade do voteappcopiar

# SLI: % de requisições bem-sucedidas nos últimos 30 dias
(
sum(increase(http_requests_total{
namespace="voteapp", status!~"5.."}[30d]))
/
sum(increase(http_requests_total{namespace="voteapp"}[30d]))
) * 100

# Error budget: quanto "espaço" ainda temos para erros?
# Se SLO = 99.5% e SLI atual = 99.8%:
# error budget consumido = (100 - 99.8) / (100 - 99.5) = 40%
# ainda temos 60% do budget disponível

Checklist final das 4 aulas de observabilidade

- Prometheus com alertas customizados para o voteapp

- Loki centralizando logs — query LogQL filtrando erros

- Jaeger recebendo traces do serviço vote instrumentado

- Grafana unificando métricas + logs + traces em um único painel

- Runbook documentando um cenário de falha investigado pela dupla

- SLI calculado em PromQL e exibido no dashboard

← anteriorfim do roteiro
