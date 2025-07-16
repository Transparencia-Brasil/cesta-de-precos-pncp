import requests
import pandas as pd
import json
import os
from typing import List, Dict, Optional
import time
from urllib.parse import quote


url_base = "https://medicamentos-api.transparencia.org.br/dados-abertos"

response = requests.get(url_base)
response_data = response.json()

records = response_data['response']['records']
total_count = response_data['response']['count']

skip = 0
take = 10

# Loop para buscar todos os registros
for skip in range(take, total_count, take):  # Começa do 'take' pois já temos os primeiros registros
    url = f"{url_base}?skip={skip}&take={take}"  # Usa '?' para iniciar parâmetros

    try:
        response = requests.get(url)
        response.raise_for_status()

        response_data = response.json()
        new_records = response_data['response']['records']
        records.extend(new_records)

        print(f"Coletados {len(records)} de {total_count} registros")

    except requests.exceptions.RequestException as e:
        print(f"Erro na requisição: {e}")
        break
    except KeyError as e:
        print(f"Erro ao acessar dados da resposta: {e}")
        break

print(f"Coleta finalizada. Total de registros obtidos: {len(records)}")

# Filtrar apenas os campos necessários
records_filtered = []
for record in records:
    filtered_record = {
        'uf' : record.get('uf'),
        'ano_coleta': record.get('ano_coleta'),
        'mes_coleta': record.get('mes_coleta'),
        'url': record.get('files', [{}])[0].get('url') if record.get('files') else None
    }
    records_filtered.append(filtered_record)

# Aqui o usuário deverá setar para seu próprio diretório
base_dir = "C:/Users/rdurl/OneDrive/Documentos/cesta-de-precos-pncp/tasks/mapeamento-ocds/output"

# Salvar os registros filtrados em um arquivo JSON
filename = 'dados-abertos-medicamentos-transparentes.json'

try:
    with open(os.path.join(base_dir, filename), 'w', encoding='utf-8') as f:
        json.dump(records_filtered, f, ensure_ascii=False, indent=2)
    print(f"Dados filtrados salvos com sucesso em '{filename}'")
    print(f"Total de registros salvos: {len(records_filtered)}")
except Exception as e:
    print(f"Erro ao salvar arquivo: {e}")
