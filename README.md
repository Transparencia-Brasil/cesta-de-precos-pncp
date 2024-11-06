
# Objetivo 

Descrever o objetivo do projeto sendo versionado neste repositório (qual o produto final do repo?).

# Replicação

Escrever aqui anotações importantes para replicação do projeto. Incluindo a ordem em que as tasks devem ser executadas. 

* Task1 - Descrição breve.
* Task2 - Descrição breve.

# Responsável 

Deixar o link para o perfil no git do responsável principal pelo projeto.

--- 

# repo-template-tb

A estrutura de pastas proposta nesse repositório segue o conceito de modularização. 

 * Modularizar o código significa dividir um programa em partes menores e independentes, chamadas módulos. Cada módulo é responsável por uma função específica ou conjunto de funcionalidades relacionadas. Essa abordagem de design de software facilita a manutenção, o desenvolvimento e a compreensão do código, pois torna o programa mais organizado e coeso.
 
 * No nosso caso, os módulos são as tasks. "Tasks should be small enough to understand easily, without having to trace too many different scripts. Transparency is facilitated by standard task naming and task organization so that any analyst can assist any project, with minimal time learning where each piece should be."

## Organização do repositório 

* Setup: Contém arquivos que definem configurações no projeto. Além do setup para o R pode conter um arquivo yaml também que defina macros do projeto, entre outros exemplos que se mostrem necessários.

* Tasks
  
  * Pastas para execução de tarefas específicas.
  
  * Cada pasta `task` possui necessariamente a pasta `src` e a pasta `outputs`. Ela utiliza o código em `src` para executar a tarefa e salvar o objeto modificado em `outputs`. 
  
  * A pasta `inputs` não é obrigatória, pois a tarefa pode puxar dados de uma outra tarefa executada anteriormente ou puxar dados da pasta `data`. 

  * A pasta `tmp` não é obrigatória, mas pode ser útil dependendo da tarefa executada.

  * Cada pasta `task` pode conter subpastas que executam tasks menores, conforme a necessidade do projeto. Por exemplo, uma pasta que executa a task `data wrangling` pode ser composta por subpastas como `clean`, `filter`, `join`. Nesse caso, a pasta de cada subtarefa também conterá as pastas `src` e `outputs`.

* Data
  
  * Dados que vieram de fora do projeto, não foram processados por scripts nossos. Esses dados podem ser usados em diferentes tasks do projeto.
  
  * Crie subdiretórios dentro de `/data` a fim de facilitar a organização. Por exemplo, se o projeto usa um arquivo de mapa dos estados brasileiros, use uma pasta `source` para armazenar tais arquivos. 
  
  * Cada pasta `source` contém necessariamente um arquivo `info.md` indicando a fonte do arquivo. Isso é essencial já que os arquivos em `data` não são criados pelo projeto.

* Docs: coloque o html de versões para publicação em `docs/` e eles estarão disponíveis na página do projeto que terá endereço em https://transparencia-brasil.github.io/nome-do-projeto/. A pasta contém templates para arquivos `rmd` e `qmd` para facilitar.

```
.
├── setup              -> Contém arquivos que definem configurações, dependências, e macros no projeto.
├── data/              -> Armeza dados de uma fonte externa que não foi processada por script do projeto
│   ├── source1        
│   └── source2        
├── tasks/        
│   ├── task1/         -> Executa uma tarefa específica
│   │   ├── inputs     -> Não é obrigatório
│   │   ├── outputs    -> Objeto resultado da execução da tarefa
│   │   ├── src        -> Códigos que executam a tarefa
│   │   └── tmp        -> Não é obrigatório
│   ├── task2/         
│   │   ├── inputs     
│   │   ├── outputs    
│   │   ├── src        
│   │   └── tmp        
├── docs               -> Contém html de relatórios para que fiquem disponíveis no github.io
├── project.rproj      -> Indica a raiz do projeto e informações prévias
├── .gitignore         -> Arquivos ou extensões a serem ignoradas no envio ao GitHub
├── LICENSE            -> Licença utilizada para o repositório
└── README             -> Info sobre o projeto e guia para sua replicação 
```

## Dicas para desenvolver

* Não é aconselhável numerar arquivos e pastas, pois conforme o projeto acontece pode ser necessário criar um script ou pasta no meio de outros e será preciso renumerar todos os subsequentes. Isso pode ser trabalhoso em projetos grandes além de gerar quebras em comandos de source dentro de scripts.

* Lembre sempre de refatorar o seu código antes de todo commit, pois cada código precisará ser revisado por outras pessoas do time. Refatorar inclui fazer melhorias específicas no código existente, tornando-o mais legível, mais eficiente e mais fácil de manter, sem alterar sua funcionalidade.

### Referências 

https://github.com/vm-wylbur/pdp-poc 

https://web.stanford.edu/~gentzkow/research/CodeAndData.pdf

https://hrdag.org/2016/06/14/the-task-is-a-quantum-of-workflow/

https://www.amazon.com.br/Software-Engineering-Data-Scientists-Notebooks/dp/1098136209

