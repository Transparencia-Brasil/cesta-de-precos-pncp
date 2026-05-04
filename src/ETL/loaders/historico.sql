use medicamentos_transparentes;

-- Teste de conex?o e visualiza??o de dados
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

-- Pr?-atualiza??o: 8.295 registros
-- P?s Qui1-Janeiro: 8.346 (+51)
-- P?s Qui2-Janeiro: 8.491
-- P?s Qui1-Fevereiro: 8.637
-- P?s Qui2-Fevereiro: 8.820
-- P?s Qui1-Mar?o: 8.962
-- P?s Qui2-Mar?o: 9.249
-- P?s Qui1-Abril: 9.493
-- P?s Qui2-Abril: 9.663
-- P?s Qui1-Maio: 9.838
-- P?s Qui2-Maio: 10.044
-- P?s Qui1-Junho: 10.229
-- P?s Qui2-Junho: 10.472
-- P?s Qui1-Julho: 10.553
-- P?s Qui2-Julho: 10.732
-- P?s Qui1-Agosto: 10.914
-- P?s Qui2-Agosto: 11.054
-- P?s Qui1-Setembro: 11.226
-- P?s Qui2-Setembro: 11.445
-- P?s Qui1-Outubro: 11.550
-- P?s Qui2-Outubro: 11.668
-- P?s Qui1-Novembro: 11.822
-- P?s Qui2-Novembro: 11.935
-- P?s Qui1-Dezembro: 12.066
-- P?s Qui2-Dezembro: 12.190
-- 2026
-- P?s Qui1-Janeiro: 12.257
-- P?s Qui2-Janeiro: 12.320
-- P?s Qui1-Fevereiro: 12.417
-- P?s Qui2-Fevereiro: 12.497
-- P?s Qui1-Mar?o: 12.588
-- P?s Qui2-Mar?o: 12.783


select *
from contratante
order by data_insercao desc
limit 10;


-- FORNECEDOR ------------------------------------------------------------------
SELECT COUNT(*)
FROM medicamentos_transparentes.public.fornecedor;

-- Pr?-atualiza??o: 6.135 registros
-- P?s Qui1-Janeiro: 6.313
-- P?s Qui2-Janeiro: 6.498
-- P?s Qui1-Fevereiro: 6.673
-- P?s Qui2-Fevereiro: 6.874
-- P?s Qui1-Mar?o: 7.076
-- P?s Qui2-Mar?o: 7.426
-- P?s Qui1-Abril: 7.651
-- P?s Qui2-Abril: 7.800
-- P?s Qui1-Maio: 7.968
-- P?s Qui2-Maio: 8.149
-- P?s Qui1-Junho: 8.340
-- P?s Qui2-Junho: 8.505
-- P?s Qui1-Julho: 8.569
-- P?s Qui2-Julho: 8.744
-- P?s Qui1-Agosto: 8.897
-- P?s Qui2-Agosto: 9.043
-- P?s Qui1-Setembro: 9.155 -> recoleta itens homologados
-- P?s Qui2-Setembro: 9.172 -> recoleta itens homologados
-- P?s Qui1-Setembro: 9.312
-- P?s Qui2-Setembro: 9.486
-- P?s Qui1-Outubro: 9.715 -> Recoleta itens homologados
-- P?s Qui1-Outubro: 9.810
-- P?s Qui2-Outubro: 9.904
-- P?s Qui1-Novembro: 10.015
-- P?s Qui2-Novembro: 10.136
-- P?s Qui1-Dezembro: 10.284
-- P?s Qui2-Dezembro: 10.400
-- 2026
-- P?s Qui1-Janeiro: 10.437
-- P?s Qui2-Janeiro: 10.489
-- P?s Qui1-Fevereiro: 10.590
-- P?s Qui2-Fevereiro: 10.680
-- P?s Qui1-Mar?o: 10.793
-- P?s Qui2-Mar?o: 10.962


select *
from fornecedor
order by data_insercao desc
limit 10;


-- CONTRATACAO -----------------------------------------------------------------
SELECT COUNT(*)
FROM medicamentos_transparentes.public.contratacao;

-- Pr?-atualiza??o: 46.652 registros
-- P?s Qui1-Janeiro: 47.141
-- P?s Qui2-Janeiro: 48.186
-- P?s Qui1-Fevereiro: 49.658
-- P?s Qui2-Fevereiro: 51.311
-- P?s Qui1-Mar?o: 52.456
-- P?s Qui2-Mar?o: 55.183
-- P?s Qui1-Abril: 57.317
-- P?s Qui2-Abril: 58.843
-- P?s Qui1-Maio: 60.536
-- P?s Qui2-Maio: 62.611
-- P?s Qui1-Junho: 64.666
-- P?s Qui2-Junho: 67.373
-- P?s Qui1-Julho: 68.221
-- P?s Qui2-Julho: 70.297
-- P?s Qui1-Agosto: 72.082
-- P?s Qui2-Agosto: 73.808
-- P?s Qui1-Setembro: 76.326
-- P?s Qui2-Setembro: 79.778
-- P?s Qui1-Outubro: 81.256
-- P?s Qui2-Outubro: 82.723
-- P?s Qui1-Novembro: 84.317
-- P?s Qui2-Novembro: 85.890
-- P?s Qui1-Dezembro: 87.771
-- P?s Qui2-Dezembro: 89.922
-- 2026
-- P?s Qui1-Janeiro: 90.837
-- P?s Qui2-Janeiro: 91.577
-- P?s Qui1-Fevereiro: 92.566
-- P?s Qui2-Fevereiro: 93.556
-- P?s Qui1-Mar?o: 94.943
-- P?s Qui2-Mar?o: 97.193

select *
from contratacao
order by data_insercao desc
limit 10;


-- ITEM HOMOLOGADO -------------------------------------------------------------
SELECT COUNT(*)
FROM medicamentos_transparentes.public.item_homologado;

-- Pr?-atualiza??o: 88.709 registros
-- P?s Qui1-Janeiro: 89.567
-- P?s Qui2-Janeiro: 90.861
-- P?s Qui1-Fevereiro: 93.201
-- P?s Qui2-Fevereiro: 95.637
-- P?s Qui1-Mar?o: 97.318
-- P?s Qui2-Mar?o: 101.836
-- P?s Qui1-Abril: 106.069
-- P?s Qui2-Abril: 109.259
-- P?s Qui1-Maio: 112.949
-- P?s Qui2-Maio: 117.125
-- P?s Qui1-Junho: 120.774
-- P?s Qui2-Junho: 124.794
-- P?s Qui1-Julho: 127.249
-- P?s Qui2-Julho: 131.383
-- P?s Qui1-Agosto: 135.053
-- P?s Qui2-Agosto: 139.164
-- P?s Qui1-Setembro: 142.919 -> recoleta itens homologados
-- P?s Qui2-Setembro: 143.344 -> recoleta itens homologados
-- P?s Qui1-Setembro: 146.556
-- P?s Qui2-Setembro: 150.930
-- P?s Qui1-Outubro: 161.400
-- P?s Qui2-Outubro: 162.289
-- P?s Qui1-Novembro: 164.979
-- P?s Qui2-Novembro: 168.170
-- P?s Qui1-Dezembro: 172.282
-- P?s Qui2-Dezembro: 175.634
-- 2026
-- P?s Qui1-Janeiro: 177.191
-- P?s Qui2-Janeiro: 179.079
-- P?s Qui1-Fevereiro: 181.580
-- P?s Qui2-Fevereiro: 184.138
-- P?s Qui1-Mar?o: 187.257
-- P?s Qui2-Mar?o: 191.947


-- ITEM LICITADO ---------------------------------------------------------------
SELECT COUNT(*)
FROM medicamentos_transparentes.public.item_licitado;

-- Pr?-atualiza??o: 73.683 registros
-- P?s Qui1-Janeiro: 74.760
-- P?s Qui2-Janeiro: 75.628 // 77.202 (4 registros inconsistentes, verificar motivo)
-- P?s Qui1-Fevereiro: 80.162
-- P?s Qui2-Fevereiro: 83.869
-- P?s Qui1-Mar?o: 86.726
-- P?s Qui2-Mar?o: 92.580
-- P?s Qui1-Abril: 96.275
-- P?s Qui2-Abril: 99.237
-- P?s Qui1-Maio: 102.737
-- P?s Qui2-Maio: 107.414
-- P?s Qui1-Junho: 112.656
-- P?s Qui2-Junho: 119.635
-- P?s Qui1-Julho: 122.751
-- P?s Qui1-Julho: 128.029
-- P?s Qui1-Agosto: 131.884
-- P?s Qui2-Agosto: 133.247
-- P?s Qui1-Setembro: 118.704 -> recoleta itens homologados
-- P?s Qui2-Setembro: 118.279 -> recoleta itens homologados
-- P?s Qui1-Setembro: 124.329
-- P?s Qui2-Setembro: 133.758
-- P?s Qui1-Outubro: 137.383
-- P?s Qui2-Outubro: 140.167
-- P?s Qui1-Novembro: 143.188
-- P?s Qui2-Novembro: 146.321
-- P?s Qui1-Dezembro: 139.789
-- P?s Qui2-Dezembro: 144.217
-- 2026
-- P?s Qui1-Janeiro: 146.385
-- P?s Qui2-Janeiro: 149.113
-- P?s Qui1-Fevereiro: 151.055
-- P?s Qui2-Fevereiro: 152.780
-- P?s Qui1-Mar?o: 155.295
-- P?s Qui2-Mar?o: 159.744
