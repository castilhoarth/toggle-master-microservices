#!/bin/bash

ENDPOINT="http://localhost:8000"
TABLE_NAME="ToggleMasterAnalytics"

echo "Verificando se a tabela '$TABLE_NAME' já existe no DynamoDB Local..."

# Tenta listar a tabela para verificar a existência
aws dynamodb describe-table --table-name "$TABLE_NAME" --endpoint-url "$ENDPOINT" > /dev/null 2>&1

if [ $? -eq 0 ]; then
    echo "A tabela '$TABLE_NAME' já existe. Nenhuma ação necessária."
else
    echo "Tabela não encontrada. Iniciando a criação..."
    
    aws dynamodb create-table \
        --table-name "$TABLE_NAME" \
        --attribute-definitions \
            AttributeName=event_id,AttributeType=S \
        --key-schema \
            AttributeName=event_id,KeyType=HASH \
        --provisioned-throughput \
            ReadCapacityUnits=1,WriteCapacityUnits=1 \
        --endpoint-url "$ENDPOINT"
    
    if [ $? -eq 0 ]; then
        echo "Tabela '$TABLE_NAME' criada com sucesso externamente!"
    else
        echo "Erro ao tentar criar a tabela. Verifique se o container está rodando na porta correta."
        exit 1
    fi
fi