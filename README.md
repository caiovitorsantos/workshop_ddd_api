# Sistema Integrado de Atendimento e Execução de Serviços

MVP do back-end de uma oficina mecânica de médio porte — gestão de ordens de
serviço, clientes, veículos, serviços e estoque de peças — construído com
**Domain-Driven Design** sobre um monolito Rails em arquitetura de camadas.

Tech Challenge — Fase 1, 15SOAT / FIAP Pós-Tech.

> **Idioma:** o código-fonte é escrito em inglês; a documentação e a linguagem
> exibida ao usuário (rótulos de status, mensagens de negócio) permanecem em
> português. O glossário PT↔EN da linguagem ubíqua está em
> [Linguagem ubíqua](#linguagem-ubíqua).

---

## Como rodar

Pré-requisitos: Docker e Docker Compose. Nada mais precisa estar instalado.

```bash
git clone <url-do-repositorio> && cd oficina_api
docker compose up --build
```

Isso sobe PostgreSQL e a API. O banco é criado e migrado automaticamente na
subida (`bin/docker-entrypoint`). Para popular com dados de demonstração:

```bash
docker compose exec api bin/rails db:seed
```

| Recurso            | URL                                |
| ------------------ | ---------------------------------- |
| API                | http://localhost:3000/api/v1       |
| Swagger UI         | http://localhost:3000/api-docs     |
| Health check       | http://localhost:3000/up           |

Se as portas 3000 ou 5432 já estiverem ocupadas por outro projeto:

```bash
API_PORT=3010 POSTGRES_PORT=5433 docker compose up --build
```

Usuários criados pelo seed (senha `oficina123`, configurável via `SEED_PASSWORD`):

| E-mail                    | Papel        |
| ------------------------- | ------------ |
| `gerente@oficina.local`   | `manager`    |
| `atendente@oficina.local` | `front_desk` |
| `mecanico@oficina.local`  | `mechanic`   |

### Primeira chamada

```bash
# 1. Autentique-se e guarde o token
TOKEN=$(curl -s -X POST http://localhost:3000/api/v1/session \
  -H 'Content-Type: application/json' \
  -d '{"email":"gerente@oficina.local","password":"oficina123"}' \
  | ruby -rjson -e 'puts JSON.parse(STDIN.read)["token"]')

# 2. Use o token nas rotas administrativas
curl -s http://localhost:3000/api/v1/customers -H "Authorization: Bearer $TOKEN"

# 3. Cadastre um cliente (o CPF é validado no domínio)
curl -s -X POST http://localhost:3000/api/v1/customers \
  -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' \
  -d '{"customer":{"tax_id":"529.982.247-25","name":"Maria Souza"}}'
```

### Rodando sem Docker

Requer Ruby 3.3.8 e um PostgreSQL acessível.

```bash
bundle install
bin/rails db:prepare db:seed
bin/rails server
```

---

## Comandos de desenvolvimento

```bash
bundle exec rspec                        # suíte completa + relatório de cobertura
bundle exec rspec spec/domain            # só o domínio (sem banco, ~0.1s)
bundle exec rspec spec/domain/workshop/service_order_spec.rb:68   # um exemplo

bundle exec rubocop                      # lint (rubocop-rails-omakase)
bundle exec rubocop -a                   # lint com autocorreção

bin/security-scan                        # Brakeman + bundler-audit -> tmp/security/
bundle exec rake rswag:specs:swaggerize  # regenera swagger/v1/swagger.yaml
```

Dentro do Docker, prefixe com `docker compose exec api`.

---

## Arquitetura

Monolito em **quatro camadas**, com a regra de dependência apontando sempre para
dentro: o domínio não conhece ninguém.

```
                     ┌──────────────────────────────────────────┐
   HTTP  ──────────► │  Interface        app/controllers        │
                     │  Traduz HTTP ↔ caso de uso. Sem regra.   │
                     └────────────────────┬─────────────────────┘
                                          │
                     ┌────────────────────▼─────────────────────┐
                     │  Aplicação        app/layers/application │
                     │  Orquestra: busca agregado, comanda,     │
                     │  persiste, devolve Result. Sem regra.    │
                     └────────────────────┬─────────────────────┘
                                          │
                     ┌────────────────────▼─────────────────────┐
                     │  Domínio          app/layers/domain      │
                     │  O coração. Entidades, objetos de valor, │
                     │  agregados, eventos. Zero Rails aqui.    │
                     └────────────────────▲─────────────────────┘
                                          │ implementa as portas
                     ┌────────────────────┴─────────────────────┐
   PostgreSQL ◄──────│  Infraestrutura  app/layers/infrastructure│
                     │  ActiveRecord, JWT, adaptadores.         │
                     └──────────────────────────────────────────┘
```

O domínio define **portas** (`Domain::Registry::CustomerRepository`) e a
infraestrutura fornece os **adaptadores**
(`Infrastructure::Persistence::Repositories::CustomersInActiveRecord`). Por isso
os testes de domínio rodam sem banco nenhum — e trocar o ActiveRecord não
encostaria em uma linha de regra de negócio.

### Contextos delimitados

| Contexto        | Tipo de subdomínio | Agregados                  |
| --------------- | ------------------ | -------------------------- |
| **Workshop**    | **Principal**      | `ServiceOrder`             |
| Registry        | Suporte            | `Customer`, `Vehicle`      |
| Catalog         | Suporte            | `Service`                  |
| Inventory       | Suporte            | `Part`                     |
| Identity        | Genérico           | `User`                     |

O investimento em DDD tático é proporcional: `ServiceOrder` recebe agregado
completo, objetos de valor, máquina de estados e eventos de domínio; `Part`
também é um agregado de verdade, porque o ciclo de estoque de duas fases
(reserva → baixa → liberação) tem invariantes a proteger; os demais contextos de
suporte ficam mais enxutos, porque padronizar um CRUD com sete camadas seria
cerimônia sem retorno.

O mapa de contextos completo, o Event Storming e o Domain Storytelling estão na
[documentação DDD](../docs/) do repositório de planejamento.

### O agregado ServiceOrder

O ciclo de vida da OS vive em `Domain::Workshop::OrderStatus`, e as transições
só acontecem por **comandos de negócio**:

```
received ──► in_diagnosis ──► awaiting_approval ──┬──► in_progress ──► completed ──► delivered
                                                  │
                                                  └──► cancelled
```

Não existe endpoint que escreva `status` diretamente. A OS muda de estado porque
alguém executou uma ação real no pátio (`POST /service_orders/:id/approve_quote`),
e o agregado decide se aquilo é legítimo. É assim que a "alteração automática dos
status conforme ações no sistema" fica garantida por construção, e não por
disciplina de quem chama a API.

---

## Linguagem ubíqua

O negócio fala português; o código, inglês. O mapeamento é explícito e único:

| Negócio (PT)          | Código (EN)      | Onde vive                              |
| --------------------- | ---------------- | -------------------------------------- |
| Ordem de Serviço (OS) | `ServiceOrder`   | `Domain::Workshop` — agregado raiz     |
| Orçamento             | `Quote`          | `Domain::Workshop` — objeto de valor   |
| Diagnóstico           | `diagnosis`      | atributo de `ServiceOrder`             |
| Cliente               | `Customer`       | `Domain::Registry`                     |
| Veículo               | `Vehicle`        | `Domain::Registry`                     |
| CPF / CNPJ            | `TaxId`          | `Domain::Registry` — objeto de valor   |
| Placa                 | `LicensePlate`   | `Domain::Registry` — objeto de valor   |
| Serviço (catálogo)    | `Service`        | `Domain::Catalog`                      |
| Peça / Insumo         | `Part`           | `Domain::Inventory`                    |
| Estoque em mãos       | `quantity_on_hand` | atributo de `Part`                   |
| Estoque reservado     | `quantity_reserved` | atributo de `Part`                  |
| Saldo disponível      | `available_quantity` | consulta de `Part` (mãos − reservado) |
| Reserva de estoque    | `reserve!` / `StockReserved` | comando/evento de `Part` (peça entra na OS) |
| Baixa de estoque      | `consume_reserved!` / `StockDeducted` | comando/evento de `Part` (aprovação) |
| Liberação de reserva  | `release!` / `StockReleased` | comando/evento de `Part` (reprovação / cancelamento) |
| Entrada de estoque    | `restock!` / `StockReplenished` | comando/evento de `Part` (fornecedor) |
| Estoque insuficiente  | `InsufficientStockDetected` | evento de `Part`                |
| Reabastecimento solicitado | `ReplenishmentRequested` | evento de `Part` (na travessia do mínimo) |
| Usuário / Papel       | `User` / `role`  | `Domain::Identity`                     |

Status da OS: `received` (Recebida), `in_diagnosis` (Em diagnóstico),
`awaiting_approval` (Aguardando aprovação), `in_progress` (Em execução),
`completed` (Finalizada), `delivered` (Entregue), `cancelled` (Cancelada).
Os rótulos em português vivem em `OrderStatus::LABELS` e são o que aparece na
tela e nas mensagens de erro.

---

## Escolha do banco de dados: PostgreSQL

O desafio pede a justificativa. São quatro razões, em ordem de peso:

1. **Transações ACID.** Cada movimento de estoque cruza dois contextos numa só
   transação: adicionar peça reserva *e* grava o item da OS; aprovar baixa o
   reservado *e* muda o status; reprovar/cancelar libera a reserva *e* muda o
   status. Sem atomicidade a oficina promete peça que não tem. É o requisito que
   elimina a maioria das alternativas NoSQL.
2. **O modelo é genuinamente relacional.** Cliente 1-N Veículo 1-N OS N-N Peça.
   Modelar isso como documentos exigiria duplicar dados e reconciliá-los à mão.
3. **Compatibilidade de primeira classe com a stack Rails.** O Active Record
   trata PostgreSQL como cidadão de primeira classe: `SELECT ... FOR UPDATE`
   para o lock da aprovação, CHECK constraints e chaves estrangeiras expressos
   direto na migração, e o mesmo adaptador em desenvolvimento, teste e produção
   — sem a divergência entre um SQLite local e o Postgres de produção que
   costuma esconder bug até o deploy.
4. **`bigint` para dinheiro.** Todo valor monetário é guardado em centavos
   (`Domain::Shared::Money`). Nenhum float encosta em um orçamento que o cliente
   aprovou juridicamente.

---

## Testes e cobertura

```bash
bundle exec rspec
```

A suíte é dividida por camada, e a divisão importa:

- `spec/domain/` — POROs puros. Sem banco, sem HTTP, sem fixtures. Roda em
  milissegundos e é onde mora a maior parte das asserções de regra de negócio.
- `spec/application/` — casos de uso. Os simples contra um repositório falso em
  memória; os que cruzam dois contextos numa transação (`ApproveQuote`,
  `AddPartToOrder`, `RejectQuote`, `CancelServiceOrder`) contra PostgreSQL real,
  porque um repositório falso não prova que o rollback desfez as duas metades.
- `spec/infrastructure/` — adaptadores de porta contra o banco.
- `spec/requests/` — integração de verdade (controller → caso de uso →
  repositório → PostgreSQL), escrita no DSL do **rswag**.

O gate de cobertura está em `spec/rails_helper.rb`: **mínimo de 80% de linha** —
o exigido pela Fase 1 — mais 70% de branch. O relatório separa as camadas, então
dá para verificar a cobertura do domínio crítico isoladamente em
`coverage/index.html`.

---

## Documentação da API (Swagger)

A documentação **é gerada a partir dos testes de integração**, não escrita à
parte. Isso resolve o problema clássico da documentação de API: ela não pode
divergir do comportamento real, porque se divergir o teste quebra.

```bash
bundle exec rake rswag:specs:swaggerize   # regenera swagger/v1/swagger.yaml
```

A UI fica em http://localhost:3000/api-docs. Um endpoint novo não é considerado
pronto até ter um spec em `spec/requests/` — é o spec que o documenta.

---

## Segurança

| Requisito                        | Implementação                                                        |
| -------------------------------- | -------------------------------------------------------------------- |
| JWT nas APIs administrativas     | `Authenticatable` + `Infrastructure::Auth::JwtToken` (HS256, 8h)      |
| Validação de CPF/CNPJ            | `Domain::Registry::TaxId` — dígitos verificadores, no domínio         |
| Validação de placa               | `Domain::Registry::LicensePlate` — padrão antigo e Mercosul           |
| Senhas                           | BCrypt via `has_secure_password`; o domínio só vê o digest            |
| Enumeração de usuários           | login devolve a mesma mensagem para e-mail inexistente e senha errada |
| CORS                             | allowlist explícita em `ALLOWED_ORIGINS`, nunca `*`                   |
| Container                        | imagem de produção roda como usuário sem privilégios (uid 1000)       |
| Rota pública de acompanhamento   | payload mínimo + rate limit de 30 req/min por IP                      |
| Análise estática                 | `bin/security-scan` (Brakeman + bundler-audit)                        |

Autenticação é **opt-out explícito**: `BaseController` exige JWT por padrão, e
uma rota pública precisa declarar `skip_authentication`. "Aberto ao público"
nunca acontece por esquecimento.

### A única rota sem token

`GET /api/v1/tracking/:number` existe porque o cliente tem um número num papel,
não uma conta. Como os números de OS são **sequenciais**, qualquer um percorre
`OS-000001` para cima — então a pergunta não é "quem está perguntando", e sim
*o que é seguro responder a alguém que adivinhou um número*.

Devolve número, status, rótulo e datas dos marcos. Retém valores do orçamento,
diagnóstico, dados do cliente e **a placa** — devolver a placa deixaria um
enumerador colher toda placa que a oficina já atendeu. Um teste fixa o conjunto
exato de chaves da resposta: alargar o payload sem pensar quebra a suíte.

---

## Estrutura

```
app/
├── controllers/                 Camada de Interface
│   ├── api/v1/                  endpoints versionados
│   └── concerns/authenticatable.rb
└── layers/
    ├── domain/                  Camada de Domínio — zero Rails
    │   ├── shared/              Entity, ValueObject, Money, Errors
    │   ├── workshop/            ServiceOrder (agregado raiz), Quote, OrderStatus, Events
    │   ├── registry/            Customer, Vehicle, TaxId, LicensePlate
    │   ├── catalog/             Service
    │   ├── inventory/           Part (agregado raiz), Events
    │   └── identity/            User
    ├── application/             Camada de Aplicação — casos de uso, Result
    └── infrastructure/          Camada de Infraestrutura
        ├── persistence/records/       modelos ActiveRecord (só tabelas)
        ├── persistence/repositories/  adaptadores das portas
        └── auth/jwt_token.rb

db/migrate/                      uma migração por contexto (+ colunas evolutivas)
spec/                            domain/ · application/ · infrastructure/ · requests/
swagger/v1/swagger.yaml          gerado a partir dos specs
```

---

## Endpoints

Todos exigem `Authorization: Bearer <token>`, exceto o acompanhamento.

| Método | Rota | O que faz |
| --- | --- | --- |
| `POST` | `/session` | Troca e-mail + senha por um JWT |
| `GET POST PATCH DELETE` | `/customers` · `/customers/:id` | CRUD de clientes |
| `GET POST` | `/customers/:id/vehicles` | Veículos de um cliente |
| `GET PATCH DELETE` | `/vehicles/:id` | Veículo |
| `GET POST PATCH DELETE` | `/services` · `/services/:id` | Catálogo |
| `POST` | `/services/:id/retire` | Tira de linha, preservando histórico |
| `GET POST PATCH DELETE` | `/parts` · `/parts/:id` | Peças (`?below_minimum=1`); resposta traz `quantity_on_hand`, `quantity_reserved` e `available` |
| `POST` | `/parts/:id/restock` | Entrada de estoque |
| `GET POST` | `/service_orders` | Abre e lista OS (`?status=`) |
| `GET` | `/service_orders/:id` | OS com itens e orçamento |
| `POST` | `/service_orders/:id/add_service` | Monta a OS |
| `POST` | `/service_orders/:id/add_part` | Monta a OS **+ reserva estoque** (422 se faltar saldo disponível) |
| `POST` | `/service_orders/:id/start_diagnosis` | → Em diagnóstico |
| `POST` | `/service_orders/:id/send_quote` | → Aguardando aprovação |
| `POST` | `/service_orders/:id/approve_quote` | → Em execução **+ baixa do reservado** |
| `POST` | `/service_orders/:id/reject_quote` · `cancel` | → Cancelada **+ libera reserva** |
| `POST` | `/service_orders/:id/complete` · `deliver` | → Finalizada → Entregue |
| `GET` | `/indicators/average_execution_time` | Tempo médio (`?since=`) |
| `GET` | **`/tracking/:number`** | **Acompanhamento público, sem token** |

---

## Estado atual

Implementado e testado ponta a ponta — **200 exemplos, 0 falhas, 96,39% de
cobertura de linha**. Os cinco contextos delimitados estão completos, do domínio
ao endpoint. O estoque segue o ciclo de duas fases do Event Storming: a peça é
**reservada** ao entrar na OS, **baixada** na aprovação e **liberada** se a OS
for reprovada ou cancelada antes da aprovação.

Fora do escopo desta fase, com a justificativa registrada no
[plano do projeto](../PLANO_TECH_CHALLENGE.md):

- **Aprovação parcial de orçamento** — o MVP é tudo-ou-nada (PA-4)
- **Cancelar OS já em execução** — a máquina de estados proíbe; permitir isso
  exige, junto, o estorno da **baixa** já feita (PA-6; a liberação de reserva,
  PA-3, já existe)
- **Média de execução por serviço** — não é derivável: uma OS com três serviços
  tem uma duração só. Exigiria copiar `estimated_minutes` para o `ServiceItem`
- **Canal de notificação ao cliente** — modelado como sistema externo; a OS muda
  de status e o cliente consulta pela rota pública
