## Plan: Observabilidade End-to-End VoteApp

Objetivo: fechar todas as lacunas entre o roteiro de observabilidade e o código em lab-voteapp-terraform para que as consultas de métricas, logs e traces funcionem de ponta a ponta em Prometheus, Grafana, Loki e Jaeger. Abordagem recomendada: manter provisionamento em Terraform (infra), instrumentar serviços vote e result para métricas/traces e validar com checklist de queries por pilar.

**Steps**
1. Fase 1 — Baseline e critérios de aceite
2. Definir critérios de pronto por pilar com base no roteiro: Prometheus (http_requests_total, http_request_duration_seconds_bucket, voteapp_votes_total), Grafana (datasources e painéis), Loki/Promtail (LogQL no namespace voteapp), Jaeger/OTel (traces do serviço vote/result). *bloqueia fases 2-5*
3. Fixar matriz de compatibilidade entre queries do roteiro e métricas reais no código atual para evitar divergência de nomes/labels (ex.: service, method, path, status). *depends on 1*
4. Fase 2 — Métricas de aplicação para Prometheus
5. Em [lab-voteapp-terraform/app/vote/app.py](lab-voteapp-terraform/app/vote/app.py), manter contador http_requests_total e adicionar histograma de duração (http_request_duration_seconds com bucket) e métrica de negócio voteapp_votes_total por opção. *depends on 1*
6. Em [lab-voteapp-terraform/app/result/server.js](lab-voteapp-terraform/app/result/server.js), adicionar histograma equivalente de duração de requisição para viabilizar p95/p99 no PromQL e padronizar labels com vote. *parallel with step 5*
7. Ajustar dependências de métricas em [lab-voteapp-terraform/app/vote/requirements.txt](lab-voteapp-terraform/app/vote/requirements.txt) e [lab-voteapp-terraform/app/result/package.json](lab-voteapp-terraform/app/result/package.json), garantindo versões compatíveis com o runtime atual. *parallel with step 5*
8. Confirmar que os endpoints /metrics continuam expostos em vote e result e que os ServiceMonitors existentes em [lab-voteapp-terraform/infra/app-observability.tf](lab-voteapp-terraform/infra/app-observability.tf) permanecem apontando para path /metrics e port http. *depends on 5-7*
9. Fase 3 — Logs com Loki/Promtail via Terraform
10. Expandir [lab-voteapp-terraform/infra/monitoring.tf](lab-voteapp-terraform/infra/monitoring.tf) para instalar Loki e Promtail via helm_release, alinhando com o roteiro (modo simples/lab e namespace monitoring). *depends on 1*
11. Incluir variáveis de versionamento/configuração em [lab-voteapp-terraform/infra/variables.tf](lab-voteapp-terraform/infra/variables.tf) e valores em [lab-voteapp-terraform/infra/terraform.tfvars](lab-voteapp-terraform/infra/terraform.tfvars) para manter upgrade controlado. *depends on 10*
12. Fase 4 — Traces com Jaeger + OpenTelemetry
13. Provisionar Jaeger all-in-one em Terraform (preferencialmente arquivo novo em infra para isolamento), expondo portas de UI e OTLP para ingestão de traces. *depends on 1*
14. Instrumentar vote para OpenTelemetry (Flask e Redis) com exportação OTLP para Jaeger e nome de serviço consistente. *depends on 13; parallel with step 15*
15. Instrumentar result para OpenTelemetry (Express/HTTP) e exportação OTLP com nome de serviço consistente. *depends on 13; parallel with step 14*
16. Fase 5 — Integração no Grafana e correlação
17. Configurar datasources de Loki e Jaeger no Grafana de forma reprodutível (via valores do chart ou provisionamento em Terraform), evitando passo manual em UI. *depends on 10 and 13*
18. Opcional recomendado: provisionar dashboard base e derived field TraceID (log para trace) para atender a etapa de correlação do roteiro. *depends on 17*
19. Fase 6 — Validação de aceite por ferramenta
20. Executar validação de infraestrutura com terraform fmt, terraform validate e terraform plan em [lab-voteapp-terraform/infra](lab-voteapp-terraform/infra). *depends on 10-18*
21. Validar Prometheus: targets up para vote/result, presença de séries http_requests_total, http_request_duration_seconds_bucket e voteapp_votes_total no namespace voteapp. *depends on 8 and 20*
22. Validar Loki: pods Loki/Promtail running e consultas LogQL do roteiro retornando linhas para voteapp. *depends on 10 and 20*
23. Validar Jaeger: traces visíveis para vote/result após geração de tráfego e busca por serviço na UI/API. *depends on 13-15 and 20*
24. Validar Grafana: datasources Prometheus/Loki/Jaeger conectados, consultas básicas funcionais e navegação métrica para logs/traces conforme roteiro. *depends on 17 and 21-23*
25. Fase 7 — Documentação e alinhamento com roteiro
26. Atualizar roteiro/guia de execução com comandos e queries realmente suportadas pelo código final, incluindo troubleshooting conhecido de ambiente k3d (ex.: nodeExporter desabilitado). *depends on 21-24*
27. Publicar checklist final de pronto por aula (Métricas, Logs, Traces, Troubleshooting) para uso em sala. *depends on 26*

**Relevant files**
- /workspaces/S110_2026-1/lab-voteapp-terraform/infra/monitoring.tf — stack de observabilidade principal (Prometheus/Grafana e novos releases Loki/Promtail/Jaeger)
- /workspaces/S110_2026-1/lab-voteapp-terraform/infra/app-observability.tf — deployments vote/result e ServiceMonitors já existentes
- /workspaces/S110_2026-1/lab-voteapp-terraform/infra/variables.tf — variáveis de chart/version/flags de observabilidade
- /workspaces/S110_2026-1/lab-voteapp-terraform/infra/terraform.tfvars — seleção de versões e parâmetros por ambiente
- /workspaces/S110_2026-1/lab-voteapp-terraform/app/vote/app.py — métricas Prometheus e instrumentação OTel no serviço vote
- /workspaces/S110_2026-1/lab-voteapp-terraform/app/vote/requirements.txt — dependências de métricas e tracing Python
- /workspaces/S110_2026-1/lab-voteapp-terraform/app/result/server.js — métricas Prometheus e instrumentação OTel no serviço result
- /workspaces/S110_2026-1/lab-voteapp-terraform/app/result/package.json — dependências de métricas e tracing Node
- /workspaces/S110_2026-1/roteiros/4-plano_observabilidade_ads.html — origem das queries e critérios pedagógicos a cumprir

**Verification**
1. Infra: terraform fmt, terraform validate, terraform plan sem erro em lab-voteapp-terraform/infra
2. Runtime monitoring: kubectl get pods -n monitoring e kubectl get servicemonitor,podmonitor -A mostrando recursos esperados
3. Prometheus: query de taxa HTTP, histogram_quantile p95 e métrica de negócio retornando séries não vazias para voteapp
4. Loki: query {namespace="voteapp"} e filtros por app retornando logs
5. Jaeger: trace de requisição de voto visível por service em Jaeger
6. Grafana: Save and Test de datasources e consulta funcional em Explore para Prometheus/Loki/Jaeger
7. Correlação: link de logs para trace ou navegação equivalente funcionando

**Decisions**
- Incluir Loki, Promtail e Jaeger no Terraform para manter governança única de infraestrutura.
- Manter ServiceMonitor em Terraform (já aderente ao padrão atual do projeto).
- Garantir que nomes de métricas e labels usados no roteiro reflitam exatamente o que os serviços exportam.
- Tratar dashboard/derived fields como parte recomendada para completude pedagógica, não como pré-requisito mínimo de ingestão.

**Further Considerations**
1. Estratégia de imagens para vote/result instrumentados: publicar em registry acessível ao cluster ou build local com import no k3d.
2. Persistência de Loki/Jaeger: em ambiente de aula pode ser efêmero, mas definir explicitamente para evitar expectativa de retenção longa.
3. Manter nodeExporter desabilitado no k3d atual para evitar timeout no helm_release do kube-prometheus-stack.

**Passo a passo completo em ambiente novo (bootstrap ate roteiro de observabilidade)**
1. Pre-requisitos locais
2. Instalar ferramentas: docker, kubectl, helm, terraform, k3d e git.
3. Confirmar versoes minimas sugeridas: kubectl 1.29+, helm 3.13+, terraform 1.6+, k3d 5.6+.
4. Clonar repositorio e entrar no projeto
5. git clone <repo-url>
6. cd S110_2026-1/lab-voteapp-terraform
7. Criar cluster k3d limpo
8. k3d cluster delete voteapp || true
9. k3d cluster create voteapp --agents 2
10. kubectl cluster-info
11. kubectl get nodes
12. Garantir namespaces base
13. kubectl create namespace voteapp --dry-run=client -o yaml | kubectl apply -f -
14. kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f -
15. Provisionar infraestrutura com Terraform
16. cd infra
17. terraform init
18. terraform fmt -recursive
19. terraform validate
20. terraform plan -out tfplan
21. terraform apply -auto-approve tfplan
22. Observacao para k3d: manter nodeExporter desabilitado no kube-prometheus-stack para evitar timeout.
23. Validar recursos de infraestrutura
24. kubectl get pods -n monitoring
25. kubectl get svc -n monitoring
26. kubectl get servicemonitor,podmonitor -A
27. Subir stack da aplicacao (vote/result/worker/redis/postgres)
28. cd ../app
29. docker compose -f docker-compose-javaworker.yml up -d --build
30. docker compose -f docker-compose-javaworker.yml ps
31. Verificar saude basica da aplicacao
32. curl -fsS http://localhost:5000/ >/dev/null
33. curl -fsS http://localhost:5001/ >/dev/null
34. Gerar trafego para popular metricas, logs e traces
35. python3 random_vote_traffic.py --url http://localhost:5000 --rate 2 --duration 120
36. Validar metricas Prometheus expostas pelos apps
37. curl -fsS http://localhost:5000/metrics | head
38. curl -fsS http://localhost:5001/metrics | head
39. Abrir acessos locais para ferramentas de observabilidade
40. Em terminal separado, executar:
41. kubectl -n monitoring port-forward svc/kube-prometheus-stack-prometheus 9090:9090
42. kubectl -n monitoring port-forward svc/kube-prometheus-stack-grafana 3000:80
43. kubectl -n monitoring port-forward svc/loki 3100:3100
44. kubectl -n monitoring port-forward svc/jaeger-query 16686:16686
45. Executar roteiro de observabilidade (validacao guiada)
46. Prometheus: testar consultas do roteiro para taxa HTTP, p95 e metrica de negocio em namespace voteapp.
47. Grafana: validar datasources Prometheus/Loki/Jaeger e consultas no Explore.
48. Loki: rodar LogQL por namespace voteapp e por app (vote/result/worker).
49. Jaeger: buscar traces por servico vote e result apos geracao de trafego.
50. Correlacao: validar navegacao de metrica para logs/traces (ou link por TraceID quando provisionado).
51. Checklist final de aceite
52. Todos os pods em monitoring e voteapp em Running/Ready.
53. Targets de scraping Up para vote e result.
54. Series nao vazias para http_requests_total, http_request_duration_seconds_bucket e voteapp_votes_total.
55. Logs retornando no Loki para namespace voteapp.
56. Traces visiveis no Jaeger para requests recentes.
57. Painel/Explore no Grafana funcionando com os 3 pilares.
58. Encerramento e limpeza opcional
59. docker compose -f docker-compose-javaworker.yml down
60. cd ../infra && terraform destroy -auto-approve
61. k3d cluster delete voteapp