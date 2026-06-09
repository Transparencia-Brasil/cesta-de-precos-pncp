---
name: github-pr-flow
description: "Automatiza fluxo GitHub de branch, commit, push, pull request, assign e reviewer opcional. Use quando o usuario pedir para criar branch, commitar, subir alteracoes, abrir PR, atribuir responsavel, pedir review ou concluir fluxo de contribuicao."
argument-hint: "Descreva: branch base (padrao coleta-orquestrada), nome da branch, escopo de arquivos, mensagem de commit, titulo/corpo do PR, assignee e reviewer opcional."
user-invocable: true
---

# GitHub PR Flow

## Quando usar

Use esta skill quando o usuario quiser evitar repetir instrucoes operacionais do fluxo de contribuicao no GitHub, especialmente para:

- criar branch de trabalho
- registrar commits das alteracoes
- abrir pull request
- fazer assign para um usuario
- adicionar reviewer apenas quando solicitado

## Objetivo

Executar o fluxo de colaboracao de forma padronizada e segura, priorizando o uso de MCP do GitHub e ferramentas Git disponiveis no ambiente.

Antes de executar o fluxo, leia `AGENTS.md` na raiz do repositorio. Ele e a fonte canonica para convencoes de Git, cuidados com artefatos gerados, dados sensiveis, idioma e escopo seguro neste projeto.

## Ordem recomendada do fluxo

A ordem abaixo e a mais robusta para evitar PR sem commit, branch incorreta ou atribuicoes incompletas:

1. Confirmar entradas minimas
2. Criar e trocar para branch a partir da branch base informada (padrao: coleta-orquestrada)
3. Revisar alteracoes e fazer commit
4. Publicar branch no remoto
5. Criar pull request
6. Fazer assign do usuario
7. Adicionar reviewer (somente se solicitado)

## Entradas esperadas

- branch base (padrao: `coleta-orquestrada`)
- nome da nova branch (ex.: `fix/encoding-floripa`)
- escopo dos arquivos para commit (`todos` ou lista)
- mensagem de commit (imperativo, em PT-BR, formato `tipo: descricao breve`)
- titulo e descricao do PR
- usuario para assign
- reviewers (opcional)

Se faltarem campos obrigatorios, solicitar apenas o minimo necessario antes de executar.

## Convencoes deste repositorio

- fonte canonica: `AGENTS.md` na raiz do repositorio
- branch base padrao: `coleta-orquestrada`
- prefira nomes de branch com prefixo: `feat/`, `fix/`, `docs/`, `chore/`
- commits em PT-BR no formato: `feat: ...`, `fix: ...`, `docs: ...`, `refactor: ...`, `chore: ...`
- evitar incluir artefatos gerados sem pedido explicito (ex.: `coleta/**`, `coleta/data-package/**`, logs e CSVs de execucao)
- se houver alteracoes nao relacionadas na arvore de trabalho, commitar apenas o escopo autorizado

## Procedimento passo a passo

1. Validacao inicial

- Verificar repositorio alvo e branch base.
- Se branch base nao for informada, assumir `coleta-orquestrada`.
- Verificar se existe alteracao para commit.
- Se nao houver alteracao, interromper com orientacao objetiva.

2. Criar branch

- Criar branch a partir da base informada.
- Trocar para a nova branch.
- Se a branch atual nao estiver na base esperada, voltar para a base antes de criar a branch (exceto quando o usuario pedir outra origem).

3. Commit das alteracoes

- Adicionar arquivos definidos para commit.
- Criar commit com mensagem clara no formato `tipo: descricao breve`.
- Se houver mudancas nao relacionadas, nao incluir sem autorizacao explicita.

4. Publicar branch

- Fazer push da branch para o remoto.
- Garantir configuracao de upstream para permitir atualizacoes posteriores do PR.

5. Criar PR

- Criar PR da branch nova para a base.
- Confirmar URL/numero do PR na resposta.

6. Assign

- Atribuir o usuario solicitado ao PR.

7. Reviewer (opcional)

- So executar se o usuario pedir explicitamente.
- Se nao houver pedido, finalizar sem reviewer.

## Mapeamento de ferramentas (preferencia)

1. GitHub MCP

- criar branch: `mcp_io_github_git_create_branch`
- criar PR: `mcp_io_github_git_create_pull_request`
- automacao completa opcional: `mcp_io_github_git_create_pull_request_with_copilot`

2. Git local / integracao Git

- add/commit: `mcp_gitkraken_git_add_or_commit`
- push: `mcp_gitkraken_git_push`

3. Fallback

- quando MCP especifico nao estiver disponivel, usar comandos Git nao interativos no terminal.

## Regras de decisao

- Se branch ja existir: perguntar se deve reutilizar ou criar outro nome.
- Se nao houver commit pronto: nao criar PR.
- Se assign nao for informado: perguntar antes de concluir.
- Se reviewer nao for solicitado: pular etapa sem perguntar em excesso.
- Se houver mudancas volumosas de dados coletados, confirmar explicitamente antes de incluir no commit.

## Criterios de conclusao

So considerar concluido quando todos os itens abaixo forem verdadeiros:

- branch criada e publicada
- pelo menos um commit realizado
- PR criado com base e head corretas
- assign aplicado
- reviewer aplicado apenas quando solicitado
- resposta final inclui numero/link do PR e resumo curto do que foi feito

## Exemplo de invocacao

`/github-pr-flow base=coleta-orquestrada branch=fix/caminho-windows commit="fix: corrige caminho com here" pr_title="fix: ajusta caminhos no transform-orgao" assignee=@usuario reviewer=@colega`

## Saida esperada

Resumo objetivo contendo:

- branch criada
- commit(s) criado(s)
- PR aberto (numero e link)
- usuario atribuido
- reviewer adicionado (ou informacao de que foi omitido por nao solicitacao)
