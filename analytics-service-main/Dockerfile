FROM python:3.11-slim

# Evita buffering de logs
ENV PYTHONUNBUFFERED=1

# Diretório da aplicação
WORKDIR /app

# Dependências do sistema (necessário para alguns pacotes AWS/Python)
RUN apt-get update && apt-get install -y \
    build-essential \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Copia requirements primeiro (cache de build melhor)
COPY requirements.txt .

# Instala dependências Python
RUN pip install --no-cache-dir -r requirements.txt

# Copia o código da aplicação
COPY . .

# Porta do Flask (health check)
EXPOSE 8005

# Sobe com gunicorn (produção)
CMD ["gunicorn", "--bind", "0.0.0.0:8005", "app:app"]