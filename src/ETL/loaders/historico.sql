use medicamentos_transparentes;

select * from contratacao limit 1;
-- Listar todas as tabelas do schema public (PostgreSQL)
SELECT table_schema, table_name
FROM information_schema.tables
WHERE table_schema = 'public'
  AND table_type = 'BASE TABLE'
ORDER BY table_name;

select * from temp_ids;

-- CONTRATANTES ----------------------------------------------------------------
SELECT COUNT(*)
FROM medicamentos_transparentes.public.contratante;

-- Pré-atualização: 8.295 registros
-- Pós Qui1-Janeiro: 8.346 (+51)
-- Pós Qui2-Janeiro: 8.491
-- Pós Qui1-Fevereiro: 8.637
-- Pós Qui2-Fevereiro: 8.820
-- Pós Qui1-Março: 8.962
-- Pós Qui2-Março: 9.249
-- Pós Qui1-Abril: 9.493
-- Pós Qui2-Abril: 9.663
-- Pós Qui1-Maio: 9.838
-- Pós Qui2-Maio: 10.044
-- Pós Qui1-Junho: 10.229
-- Pós Qui2-Junho: 10.472
-- Pós Qui1-Julho: 10.553
-- Pós Qui2-Julho: 10.732
-- Pós Qui1-Agosto: 10.914
-- Pós Qui2-Agosto: 11.054
-- Pós Qui1-Setembro: 11.226
-- Pós Qui2-Setembro: 11.445
-- Pós Qui1-Outubro: 11.550
-- Pós Qui2-Outubro: 11.668


select *
from contratante
order by data_insercao desc
limit 10;


-- FORNECEDOR ------------------------------------------------------------------
SELECT COUNT(*)
FROM medicamentos_transparentes.public.fornecedor;

-- Pré-atualização: 6.135 registros
-- Pós Qui1-Janeiro: 6.313
-- Pós Qui2-Janeiro: 6.498
-- Pós Qui1-Fevereiro: 6.673
-- Pós Qui2-Fevereiro: 6.874
-- Pós Qui1-Março: 7.076
-- Pós Qui2-Março: 7.426
-- Pós Qui1-Abril: 7.651
-- Pós Qui2-Abril: 7.800
-- Pós Qui1-Maio: 7.968
-- Pós Qui2-Maio: 8.149
-- Pós Qui1-Junho: 8.340
-- Pós Qui2-Junho: 8.505
-- Pós Qui1-Julho: 8.569
-- Pós Qui2-Julho: 8.744
-- Pós Qui1-Agosto: 8.897
-- Pós Qui2-Agosto: 9.043
-- Pós Qui1-Setembro: 9.155 -> recoleta itens homologados
-- Pós Qui2-Setembro: 9.172 -> recoleta itens homologados
-- Pós Qui1-Setembro: 9.312
-- Pós Qui2-Setembro: 9.486
-- Pós Qui1-Outubro: 9.715 -> Recoleta itens homologados
-- Pós Qui1-Outubro: 9.810
-- Pós Qui2-Outubro: 9.904


select *
from fornecedor
order by data_insercao desc
limit 10;


-- CONTRATACAO -----------------------------------------------------------------
SELECT COUNT(*)
FROM medicamentos_transparentes.public.contratacao;

-- Pré-atualização: 46.652 registros
-- Pós Qui1-Janeiro: 47.141
-- Pós Qui2-Janeiro: 48.186
-- Pós Qui1-Fevereiro: 49.658
-- Pós Qui2-Fevereiro: 51.311
-- Pós Qui1-Março: 52.456
-- Pós Qui2-Março: 55.183
-- Pós Qui1-Abril: 57.317
-- Pós Qui2-Abril: 58.843
-- Pós Qui1-Maio: 60.536
-- Pós Qui2-Maio: 62.611
-- Pós Qui1-Junho: 64.666
-- Pós Qui2-Junho: 67.373
-- Pós Qui1-Julho: 68.221
-- Pós Qui2-Julho: 70.297
-- Pós Qui1-Agosto: 72.082
-- Pós Qui2-Agosto: 73.808
-- Pós Qui1-Setembro: 76.326
-- Pós Qui2-Setembro: 79.778
-- Pós Qui1-Outubro: 81.256
-- Pós Qui2-Outubro: 82.723

select *
from contratacao
order by data_insercao desc
limit 10;


-- ITEM HOMOLOGADO -------------------------------------------------------------
SELECT COUNT(*)
FROM medicamentos_transparentes.public.item_homologado;

-- Pré-atualização: 88.709 registros
-- Pós Qui1-Janeiro: 89.567
-- Pós Qui2-Janeiro: 90.861
-- Pós Qui1-Fevereiro: 93.201
-- Pós Qui2-Fevereiro: 95.637
-- Pós Qui1-Março: 97.318
-- Pós Qui2-Março: 101.836
-- Pós Qui1-Abril: 106.069
-- Pós Qui2-Abril: 109.259
-- Pós Qui1-Maio: 112.949
-- Pós Qui2-Maio: 117.125
-- Pós Qui1-Junho: 120.774
-- Pós Qui2-Junho: 124.794
-- Pós Qui1-Julho: 127.249
-- Pós Qui2-Julho: 131.383
-- Pós Qui1-Agosto: 135.053
-- Pós Qui2-Agosto: 139.164
-- Pós Qui1-Setembro: 142.919 -> recoleta itens homologados
-- Pós Qui2-Setembro: 143.344 -> recoleta itens homologados
-- Pós Qui1-Setembro: 146.556
-- Pós Qui2-Setembro: 150.930
-- Pós Qui1-Outubro: 161.400
-- Pós Qui2-Outubro: 162.289


-- ITEM LICITADO ---------------------------------------------------------------
SELECT COUNT(*)
FROM medicamentos_transparentes.public.item_licitado;

-- Pré-atualização: 73.683 registros
-- Pós Qui1-Janeiro: 74.760
-- Pós Qui2-Janeiro: 75.628 // 77.202 (4 registros inconsistentes, verificar motivo)
-- Pós Qui1-Fevereiro: 80.162
-- Pós Qui2-Fevereiro: 83.869
-- Pós Qui1-Março: 86.726
-- Pós Qui2-Março: 92.580
-- Pós Qui1-Abril: 96.275
-- Pós Qui2-Abril: 99.237
-- Pós Qui1-Maio: 102.737
-- Pós Qui2-Maio: 107.414
-- Pós Qui1-Junho: 112.656
-- Pós Qui2-Junho: 119.635
-- Pós Qui1-Julho: 122.751
-- Pós Qui1-Julho: 128.029
-- Pós Qui1-Agosto: 131.884
-- Pós Qui2-Agosto: 133.247
-- Pós Qui1-Setembro: 118.704 -> recoleta itens homologados
-- Pós Qui2-Setembro: 118.279 -> recoleta itens homologados
-- Pós Qui1-Setembro: 124.329
-- Pós Qui2-Setembro: 133.758
-- Pós Qui1-Outubro: 137.383
-- Pós Qui2-Outubro: 140.167
