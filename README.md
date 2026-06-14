# Toggle Master Microservices - Deploy de Infraestrutura na AWS



## **1. Identificação do Projeto**

- **Projeto:** Toggle Master Microservices
- **Fase:** 02 - Microserviços e Infraestrutura AWS
- **Integrantes:** Turma 3DLC - Grupo 53

## 2. Projeto

A arquitetura foi dividida nos em 5 microsserviços:

- **auth-service (Go)**: Gerencia chaves de API e autenticação. (Banco de Dados: PostgreSQL) 

- **flag-service (Python)**: CRUD das definições das feature flags. (Banco de Dados: PostgreSQL) 

- **targeting-service (Python)**: Gerencia regras complexas de segmentação. (Banco de Dados: PostgreSQL) 

- **evaluation-service (Go)**: O "caminho quente" (hot path) de alta performance que retorna a decisão final (true/false). (Cache: Redis) 

- **analytics-service (Python)**: Consome eventos de uma fila e salva dados de análise. (Fila: AWS SQS, Banco de Dados: AWS DynamoDB)

A missão de desse projeto é projetar e implementar a infraestrutura de contêineres e orquestração para colocar esse novo ecossistema em produção na AWS.

## 3. Teste Local e criação dos Dockerfiles

Preparação de cada microserviço, para rodar localmente, criando os DockerFiles e rodando através de Dockercompose.

toggle-master-microservices/
├── auth-service-main/
├── flag-service-main/
├── targeting-service-main/
├──  evaluation-service-main/
└── analytics-service-main/

### 3.1 auth-service

Aplicação em Go com banco PostgreSQL

Foi criado o DockerFile, para a aplicação:

```
# ==========================
# Build Stage
# ==========================
FROM golang:1.21 AS builder

WORKDIR /app

COPY go.mod .
COPY go.sum .

RUN go mod download

COPY . .

RUN CGO_ENABLED=0 GOOS=linux go build -o auth-service .

# ==========================
# Runtime Stage
# ==========================
FROM alpine:3.20

WORKDIR /app

RUN apk --no-cache add ca-certificates

COPY --from=builder /app/auth-service .

EXPOSE 8001

CMD ["./auth-service"]
```

[Dockerfile](auth-service-main/Dockerfile)

[ReadMe do Auth Service](auth-service-main/README.md)

Durante a ativação local, foram identificados alguns ajustes necessários para que a aplicação rodasse:

Imports não usados e removidos

```
./handlers.go:4:2: "crypto/sha256" imported and not used

./handlers.go:5:2: "encoding/hex" imported and not used

./key.go:7:2: "fmt" imported and not used

./main.go:5:2: "fmt" imported and not used

./main.go:10:2: "github.com/jackc/pgx/v4/stdlib" imported and not used
```

E incluído o:

_ "github.com/jackc/pgx/v4/stdlib" no main.go para registrar o drive do postgres

Foi necessário rodar manualmente o go mod tidy para criar o go sum.

Dentro do Docker Compose foi criadas as condições para que o app só rode após o banco estar ativo.

```
services:

  auth-service:
    build: ./auth-service-main
    ports:
      - "8001:8001"
    environment:
      DATABASE_URL: postgres://admin:123@postgres-auth:5432/auth_db?sslmode=disable
      PORT: 8001
      MASTER_KEY: admin-secreto-123
    depends_on:
      postgres-auth:
        condition: service_healthy
        
  postgres-auth:
    image: postgres:16
    environment:
      POSTGRES_USER: admin
      POSTGRES_PASSWORD: 123
      POSTGRES_DB: auth_db
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U admin -d auth_db"]
      interval: 5s
      timeout: 5s
      retries: 10
    volumes:
      - auth_data:/var/lib/postgresql/data
      - ./auth-service-main/db/init.sql:/docker-entrypoint-initdb.d/init.sql
```



### 3.2 flag-service

Aplicação em Python com banco PostgresSQL

Durante a importação das bibliotecas, verificamos erros de versão do Flask.

O requirements.txt foi ajustado para:

```
Flask==3.0.0
werkzeug==3.0.1
psycopg2-binary==2.9.5
gunicorn==20.1.0
python-dotenv==0.21.0
requests==2.28.1
```

Dockerfile: 

```
FROM python:3.11-slim

WORKDIR /app

# dependências do sistema (opcional mas recomendado)
RUN apt-get update && apt-get install -y gcc

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

EXPOSE 8002

CMD ["gunicorn", "--bind", "0.0.0.0:8002", "app:app"]
```

Como o python não precisa compilar, não precisa das duas fases como no Go.

[Dockerfile](flag-service-main/Dockerfile)

[ReadMe do Flag Service](flag-service-main/README.md)

No docker-compose, foi necessário colocar as dependências do auth e banco:

```
flag-service:
    build: ./flag-service-main
    ports:
      - "8002:8002"
    environment:
      DATABASE_URL: postgres://admin:123@postgres-flags:5432/flags_db?sslmode=disable
      AUTH_SERVICE_URL: http://auth-service:8001
      PORT: 8002
    depends_on:
      auth-service:
        condition: service_started
      postgres-flags:
        condition: service_healthy
        
  postgres-flags:
    image: postgres:16
    environment:
      POSTGRES_USER: admin
      POSTGRES_PASSWORD: 123
      POSTGRES_DB: flags_db
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U admin -d flags_db"]
      interval: 5s
      timeout: 5s
      retries: 10
    volumes:
      - flags_data:/var/lib/postgresql/data
      - ./flag-service-main/db/init.sql:/docker-entrypoint-initdb.d/init.sql
```



### 3.3 targeting-service

Aplicação em Python com banco PostgresSQL

Durante a importação das bibliotecas, verificamos erros de versão do Flask.

O requirements.txt foi ajustado para:

```
Flask==3.0.0
werkzeug==3.0.1
psycopg2-binary==2.9.5
gunicorn==20.1.0
python-dotenv==0.21.0
requests==2.28.1
```

Dockerfile:

```
FROM python:3.11-slim

WORKDIR /app

# Dependências necessárias para psycopg2
RUN apt-get update && apt-get install -y gcc libpq-dev && \
    rm -rf /var/lib/apt/lists/*

COPY requirements.txt .

RUN pip install --no-cache-dir -r requirements.txt

COPY . .

EXPOSE 8003

CMD ["gunicorn", "--bind", "0.0.0.0:8003", "app:app"]
```
[Dockerfile](targeting-service-main/Dockerfile)

[ReadMe do Targeting Service](targeting-service-main/README.md)

No docker-compose, foi necessário colocar as dependências do auth e banco:

```
  targeting-service:
    build: ./targeting-service-main
    ports:
      - "8003:8003"
    environment:
      DATABASE_URL: postgres://admin:123@postgres-targeting:5432/targeting_db
      AUTH_SERVICE_URL: http://auth-service:8001
      PORT: 8003
    depends_on:
      auth-service:
        condition: service_started
      postgres-targeting:
        condition: service_healthy
  
  postgres-targeting:
    image: postgres:16
    environment:
      POSTGRES_USER: admin
      POSTGRES_PASSWORD: 123
      POSTGRES_DB: targeting_db
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U admin -d targeting_db"]
      interval: 5s
      timeout: 5s
      retries: 10
    volumes:
      - targeting_data:/var/lib/postgresql/data
      - ./targeting-service-main/db/init.sql:/docker-entrypoint-initdb.d/init.sql
```

### 3.4 evaluation-service

Aplicação em Go usando o Redis e o SQS da AWS

Para a aplicação em Go rodar, foram necessários alguns ajustes de pacotes:

```
0.241 main.go:10:2: missing go.sum entry for module providing package github.com/aws/aws-sdk-go/aws (imported by evaluation-service); to add:
0.241   go get evaluation-service
0.241 main.go:11:2: missing go.sum entry for module providing package github.com/aws/aws-sdk-go/aws/session (imported by evaluation-service); to add:
0.241   go get evaluation-service
0.241 main.go:12:2: missing go.sum entry for module providing package github.com/aws/aws-sdk-go/service/sqs (imported by evaluation-service); to add:
0.241   go get evaluation-service
0.241 main.go:13:2: missing go.sum entry for module providing package github.com/go-redis/redis/v8 (imported by evaluation-service); to add:
0.241   go get evaluation-service
0.241 main.go:14:2: missing go.sum entry for module providing package github.com/joho/godotenv (imported by evaluation-service); to add:
0.241   go get evaluation-service
```

Rodamos o go mod tidy para atualizar o go sum.

Retiramos do evaluation Go o "context" e inserimos o "os"

Dockerfile:

```
FROM golang:1.21 AS builder

WORKDIR /app

COPY go.mod .
COPY go.sum .

RUN go mod download

COPY . .

RUN CGO_ENABLED=0 GOOS=linux go build -o evaluation-service .

FROM alpine:3.20

WORKDIR /app

RUN apk --no-cache add ca-certificates

COPY --from=builder /app/evaluation-service .

EXPOSE 8004

CMD ["./evaluation-service"]
```

[Dockerfile](evaluation-service-main/Dockerfile)

[ReadMe do Evaluation Service](evaluation-service-main/README.md)

Foi criado também um .env para as variáveis de ambiente.

```
SERVICE_API_KEY=tm_key_112...
AWS_DYNAMODB_TABLE="ToggleMasterAnalytics"
aws_region=us-east-1
AWS_SQS_URL=https://sqs.us-east-1.amazonaws.com/XXXXX.../togglemaster-events
aws_access_key_id=ASI
aws_secret_access_key=aBrt...
aws_session_token=IQoJ...
```

No docker-compose, foram colocadas as dependências com os outros serviços e o redis:

```
  evaluation-service:
    build: ./evaluation-service-main
    ports:
      - "8004:8004"
    environment:
      PORT: 8004
      REDIS_URL: redis://redis:6379
      FLAG_SERVICE_URL: http://flag-service:8002
      TARGETING_SERVICE_URL: http://targeting-service:8003
      SERVICE_API_KEY: ${SERVICE_API_KEY}
      AWS_ACCESS_KEY_ID: ${aws_access_key_id}
      AWS_SECRET_ACCESS_KEY: ${aws_secret_access_key}
      AWS_SESSION_TOKEN: ${aws_session_token}
      AWS_REGION: ${aws_region}
      AWS_SQS_URL: ${AWS_SQS_URL}
    depends_on:
      redis:
        condition: service_healthy
      flag-service:
        condition: service_started
      targeting-service:
        condition: service_started
        
  redis:
    image: redis:7-alpine
    ports:
      - "6379:6379"
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 5s
      timeout: 3s
      retries: 5
```
### 3.5 analytics-service

Aplicação em Python

Durante a importação das bibliotecas, verificamos erros de versão do Flask.

O requirements.txt foi ajustado para:

```
Flask==3.0.0
gunicorn==20.1.0
python-dotenv==0.21.0
boto3>=1.34.0
```

Dockerfile:

```
FROM python:3.11-slim

ENV PYTHONUNBUFFERED=1

WORKDIR /app

RUN apt-get update && apt-get install -y \
    build-essential \
    curl \
    && rm -rf /var/lib/apt/lists/*

COPY requirements.txt .

RUN pip install --no-cache-dir -r requirements.txt

COPY . .

EXPOSE 8005

CMD ["gunicorn", "--bind", "0.0.0.0:8005", "app:app"]
```
[Dockerfile](analytics-service-main/Dockerfile)

[ReadMe do Analytics Service](analytics-service-main/README.md)

No docker-compose, foram colocadas as dependências com os outros serviços e as variáveis de ambiente:

```
analytics-service:
    build: ./analytics-service-main
    ports:
      - "8005:8005"
    environment:
      AWS_DYNAMODB_TABLE: ToggleMasterAnalytics
      AWS_ACCESS_KEY_ID: ${aws_access_key_id}
      AWS_SECRET_ACCESS_KEY: ${aws_secret_access_key}
      AWS_SESSION_TOKEN: ${aws_session_token}
      AWS_REGION: ${aws_region}
      AWS_SQS_URL: ${AWS_SQS_URL}
    depends_on:
          flag-service:
            condition: service_started
          targeting-service:
            condition: service_started
```

### 3.6 Testes Locais

Para o teste local, foi criado um dockercompose e uma rede local, assim como volumes para o auth, flags e targeting services.

[docker-compose](./docker-compose.yml)

Foi criado um plano de teste em bash para testar os serviços: auth, flags, targeting e evaluation.

Esse teste pode ser usado depois para Produção, só trocando as urls de acesso.

[Plano de Teste](./test.sh)

Testes realizados:

Ao startar o lab é necessário pegar as novas credenciais e colocar no .env

Ativando o docker-compose:

<img src="./img/image-20260614123043349.png" alt="image-20260614123043349" style="zoom:200%;" />

Rodando o teste automatizado:

```
========================================
AMBIENTE DE TESTE
========================================
AUTH      : http://localhost:8001
FLAG      : http://localhost:8002
TARGETING : http://localhost:8003
EVALUATION : http://localhost:8004
ANALYTICS : http://localhost:8005

========================================
1. Health Check
========================================
{"status":"ok"}

{"status":"ok"}

{"status":"ok"}

{"status":"ok"}

{"status":"ok"}

========================================
2. Criando API Key
========================================
API KEY:
tm_key_ba5215d39245bf92cfa8be3dff38a8a79c87c962f7e25d2763ad6f6fac0dd8a9

========================================
3. Criando Flag
========================================
{"created_at":"Sun, 14 Jun 2026 15:32:02 GMT","description":"Teste automatizado","id":12,"is_enabled":true,"name":"enable-new-dashboard-1781451120","updated_at":"Sun, 14 Jun 2026 15:32:02 GMT"}

========================================
4. Listando Flags
========================================
Flags encontradas:
enable-new-dashboard-1780855960
enable-new-dashboard-1781451120

========================================
5. Consultando Flag
========================================
{"created_at":"Sun, 14 Jun 2026 15:32:02 GMT","description":"Teste automatizado","id":12,"is_enabled":true,"name":"enable-new-dashboard-1781451120","updated_at":"Sun, 14 Jun 2026 15:32:02 GMT"}

========================================
6. Atualizando Flag
========================================
{"created_at":"Sun, 14 Jun 2026 15:32:02 GMT","description":"Teste automatizado","id":12,"is_enabled":false,"name":"enable-new-dashboard-1781451120","updated_at":"Sun, 14 Jun 2026 15:32:02 GMT"}

========================================
7. Criando Regra de Targeting
========================================
{"created_at":"Sun, 14 Jun 2026 15:32:02 GMT","flag_name":"enable-new-dashboard-1781451120","id":12,"is_enabled":true,"rules":{"type":"PERCENTAGE","value":50},"updated_at":"Sun, 14 Jun 2026 15:32:02 GMT"}

========================================
8. Consultando Regra
========================================
{"created_at":"Sun, 14 Jun 2026 15:32:02 GMT","flag_name":"enable-new-dashboard-1781451120","id":12,"is_enabled":true,"rules":{"type":"PERCENTAGE","value":50},"updated_at":"Sun, 14 Jun 2026 15:32:02 GMT"}

========================================
9. Atualizando Regra
========================================
{"created_at":"Sun, 14 Jun 2026 15:32:02 GMT","flag_name":"enable-new-dashboard-1781451120","id":12,"is_enabled":true,"rules":{"type":"PERCENTAGE","value":75},"updated_at":"Sun, 14 Jun 2026 15:32:02 GMT"}

========================================
10. Testando a fila SQS e o processamento
========================================
user 1 - user-1781451120
=== Request 1 ===
{"flag_name":"enable-new-dashboard-1781451120","user_id":"user-1781451120","result":false}

=== Request 2 ===
{"flag_name":"enable-new-dashboard-1781451120","user_id":"user-1781451120","result":false}

user 2 - user-1781451122
=== Request 1 ===
{"flag_name":"enable-new-dashboard-1780855960","user_id":"user-1781451122","result":false}

=== Request 2 ===
{"flag_name":"enable-new-dashboard-1780855960","user_id":"user-1781451122","result":false}

========================================
11. Deletando Flag
========================================
FLAG_NAME=enable-new-dashboard-1781451120
Flag removida com sucesso.

TESTE FINALIZADO COM SUCESSO
```

Verificando nos logs o Evaluation:

<img src="./img/image-20260614124109034.png" alt="image-20260614124109034" style="zoom:200%;" />

Verificando na AWS: No Dynamo DB

<img src="./img/image-20260614124423795.png" alt="image-20260614124423795" style="zoom:200%;" />

E no SQS tá zerado.

<img src="./img/image-20260614124825626.png" alt="image-20260614124825626" style="zoom:150%;" />

O Fluxo está rodando corretamente:

<img src="./img/image-20260614124731715.png" alt="image-20260614124731715" style="zoom:150%;" />

