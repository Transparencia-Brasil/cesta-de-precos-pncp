# Smoke test do classificador

Arquivos de exemplo:

- `catmat-sample.csv`: catálogo mínimo com PDM e códigos BR
- `itens-sample.csv`: itens com descrições de Paracetamol, Dipirona e um item não-medicamento

Como rodar (PowerShell, usando o venv configurado pelo workspace):

1) Garanta dependências instaladas (já fizemos, mas se precisar repetir):
   C:\Users\rdurl\OneDrive\Documentos\cesta-de-precos-pncp\.venv-pncp\Scripts\python.exe -m pip install -r requirements.txt

2) Execute o classificador com os CSVs de teste:
   C:\Users\rdurl\OneDrive\Documentos\cesta-de-precos-pncp\.venv-pncp\Scripts\python.exe src\ETL\classificador\filtra-medicamentos.py src\ETL\dados-de-teste\classificador\itens-sample.csv src\ETL\dados-de-teste\classificador\catmat-sample.csv

3) Verifique as saídas:

   - `src/ETL/dados-de-teste/classificador/catalogo-vetorizado.csv`
   - `src/ETL/dados-de-teste/classificador/medicamentos.csv`

Dicas:

- Você pode definir `EMBEDDING_MODEL` e/ou `CATALOGO_VETORIZADO_PATH` antes de rodar para testar outras combinações.
- O script revectoriza automaticamente se o cache não for compatível com o modelo atual.
