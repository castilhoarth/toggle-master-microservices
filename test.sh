#!/bin/bash

set -e

echo "========================================"
echo "1. Health Check"
echo "========================================"

curl http://localhost:8001/health
echo ""

curl http://localhost:8002/health
echo ""

curl http://localhost:8003/health
echo ""

echo ""
echo "========================================"
echo "2. Criando API Key"
echo "========================================"

API_KEY=$(curl -s -X POST http://localhost:8001/admin/keys \
-H "Content-Type: application/json" \
-H "Authorization: Bearer admin-secreto-123" \
-d '{"name":"teste-e2e"}' | jq -r '.key')

echo "API KEY:"
echo "$API_KEY"

echo ""
echo "========================================"
echo "3. Criando Flag"
echo "========================================"

curl -X POST http://localhost:8002/flags \
-H "Content-Type: application/json" \
-H "Authorization: Bearer $API_KEY" \
-d '{
  "name":"enable-new-dashboard",
  "description":"Teste automatizado",
  "is_enabled":true
}'
echo ""

echo ""
echo "========================================"
echo "4. Listando Flags"
echo "========================================"

curl http://localhost:8002/flags \
-H "Authorization: Bearer $API_KEY"

echo ""
echo ""

echo "========================================"
echo "5. Consultando Flag"
echo "========================================"

curl http://localhost:8002/flags/enable-new-dashboard \
-H "Authorization: Bearer $API_KEY"

echo ""
echo ""

echo "========================================"
echo "6. Atualizando Flag"
echo "========================================"

curl -X PUT http://localhost:8002/flags/enable-new-dashboard \
-H "Content-Type: application/json" \
-H "Authorization: Bearer $API_KEY" \
-d '{
  "is_enabled": false
}'

echo ""
echo ""

echo "========================================"
echo "7. Criando Regra de Targeting"
echo "========================================"

curl -X POST http://localhost:8003/rules \
-H "Content-Type: application/json" \
-H "Authorization: Bearer $API_KEY" \
-d '{
  "flag_name":"enable-new-dashboard",
  "is_enabled":true,
  "rules":{
      "type":"PERCENTAGE",
      "value":50
  }
}'

echo ""
echo ""

echo "========================================"
echo "8. Consultando Regra"
echo "========================================"

curl http://localhost:8003/rules/enable-new-dashboard \
-H "Authorization: Bearer $API_KEY"

echo ""
echo ""

echo "========================================"
echo "9. Atualizando Regra"
echo "========================================"

curl -X PUT http://localhost:8003/rules/enable-new-dashboard \
-H "Content-Type: application/json" \
-H "Authorization: Bearer $API_KEY" \
-d '{
  "rules":{
      "type":"PERCENTAGE",
      "value":75
  }
}'

echo ""
echo ""

echo "========================================"
echo "10. Deletando Flag"
echo "========================================"

curl -X DELETE \
http://localhost:8002/flags/enable-new-dashboard \
-H "Authorization: Bearer $API_KEY"

echo ""
echo ""
echo "TESTE FINALIZADO COM SUCESSO"