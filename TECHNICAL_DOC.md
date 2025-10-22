# 🧠 TECHNICAL_DOC.md — Linux Recycle Bin Simulation

## 📘 Introdução

O projeto **Linux Recycle Bin Simulation** implementa uma simulação funcional da Reciclagem do Windows, desenvolvida em **Bash** no âmbito da unidade curricular **Sistemas Operativos (SO-2526)**.

O sistema permite mover ficheiros para uma área segura de reciclagem, restaurá-los, removê-los permanentemente e consultar metadados e estatísticas.  
Todo o comportamento é reproduzido através de **operações de sistema de ficheiros**, **tratamento de erros** e **gestão de dados persistentes (CSV)**.

---

## ⚙️ Arquitetura do Sistema

A estrutura base é criada dentro da pasta do utilizador, em `~/.recycle_bin/`, contendo:

~/.recycle_bin/
├── files/ # Armazena os ficheiros eliminados
├── metadata.db # Base de dados CSV dos ficheiros
├── config # Ficheiro de configuração (quota e retenção)
└── recyclebin.log # Ficheiro de log de operações


**Ficheiro principal:** `recycle_bin.sh`  
**Ficheiros de apoio:** `test_suite.sh`, `README.md`, `TECHNICAL_DOC.md`, `TESTING.md`

Cada operação é modular e implementada como função Bash independente.

---

## 🧩 Fluxograma Geral do Programa

> **Imagem a adicionar:** `fluxograma_main.png`  
> _(Mostra o ciclo principal do programa: inicialização → leitura de argumentos → seleção da função → execução → saída.)_

---

## 🔧 Descrição Técnica das Funções

### 1. `initialize_recyclebin()`

**Função:** Cria toda a estrutura de diretórios e ficheiros necessários.  
**Comportamento:**
- Verifica se a pasta `.recycle_bin` já existe.
- Caso não exista, cria `files/`, `metadata.db`, `config` e `log`.
- Garante a presença do cabeçalho CSV no `metadata.db`.

**Entradas:** Nenhuma  
**Saídas:** Mensagem de confirmação no terminal  
**Complexidade:** O(1)  

> **Fluxograma:** `fluxograma_initialize_recyclebin.png`

---

### 2. `generate_unique_id()`

**Função:** Gera um identificador único com timestamp + string aleatória.  
**Utilização:** Evita colisões de nomes na reciclagem.  

**Método:**  
`id = $(date +%s%N)_$(cat /dev/urandom | tr -dc 'a-z0-9' | fold -w 6 | head -n 1)`

**Complexidade:** O(1)

> **Fluxograma:** `fluxograma_generate_unique_id.png`

---

### 3. `delete_file()`

**Função:** Move um ou mais ficheiros para a reciclagem.  
**Comportamento:**
1. Verifica se o ficheiro existe.  
2. Obtém metadados com `stat` e `realpath`.  
3. Gera um ID único.  
4. Move o ficheiro para `~/.recycle_bin/files/<ID>`.  
5. Guarda uma linha no `metadata.db`.  
6. Mostra mensagem colorida ao utilizador.  

**Campos registados no `metadata.db`:**
ID, ORIGINAL_NAME, ORIGINAL_PATH, DELETION_DATE, FILE_SIZE, FILE_TYPE, PERMISSIONS, OWNER


**Erros tratados:**
- Ficheiro inexistente  
- Falta de permissões  
- Diretório não acessível  

> **Fluxograma:** `fluxograma_delete_file.png`

---

### 4. `list_recycled()`

**Função:** Lista todos os ficheiros presentes na reciclagem.  
**Comportamento:**
- Lê o ficheiro `metadata.db` linha a linha.  
- Formata e apresenta os dados em tabela.  
- Mostra aviso se a reciclagem estiver vazia.  

**Complexidade:** O(n), onde n = número de entradas.  

> **Fluxograma:** `fluxograma_list_recycled.png`

---

### 5. `restore_file()`

**Função:** Restaura ficheiros para o caminho original.  
**Comportamento:**
1. Procura o ID ou nome no `metadata.db`.  
2. Garante que o diretório de destino existe.  
3. Se já existir um ficheiro com o mesmo nome → renomeia para `<nome>_restored_<timestamp>`.  
4. Restaura permissões e remove a linha do `metadata.db`.  

**Complexidade:** O(n) (procura no CSV)

> **Fluxograma:** `fluxograma_restore_file.png`

---

### 6. `search_recycled()`

**Função:** Pesquisa ficheiros no `metadata.db` por nome, extensão ou parte do caminho.  
**Implementação:** Utiliza `grep -i` para pesquisa insensível a maiúsculas/minúsculas.  

**Complexidade:** O(n)

> **Fluxograma:** `fluxograma_search_recycled.png`

---

### 7. `empty_recyclebin()`

**Função:** Apaga permanentemente os ficheiros da reciclagem.  
**Comportamento:**
- Pede confirmação do utilizador (`yes/NO`).  
- Se confirmado, remove todos os ficheiros da pasta `files/` e recria o cabeçalho do `metadata.db`.  
- Regista a operação no log.

> **Fluxograma:** `fluxograma_empty_recyclebin.png`

---

### 8. `show_statistics()`

**Função:** Calcula estatísticas sobre os ficheiros armazenados.  
**Dados exibidos:**
- Número total de itens  
- Tamanho total (bytes e legível)  
- Ficheiros vs diretórios  
- Média de tamanho  
- Datas mais antiga e mais recente  

> **Fluxograma:** `fluxograma_show_statistics.png`

---

### 9. `auto_cleanup()`

**Função:** Elimina automaticamente ficheiros antigos de acordo com o valor `RETENTION_DAYS` do ficheiro `config`.  
**Comportamento:**
- Lê a configuração.  
- Percorre o `metadata.db` e compara a data de eliminação com a data atual.  
- Remove entradas antigas e atualiza o log.

> **Fluxograma:** `fluxograma_auto_cleanup.png`

---

### 10. `check_quota()`

**Função:** Verifica se o tamanho total da reciclagem ultrapassa `MAX_SIZE_MB`.  
**Comportamento:**
- Calcula o tamanho atual com `du -sm`.  
- Mostra percentagem de uso.  
- Caso ultrapasse, alerta o utilizador e sugere `auto_cleanup`.

> **Fluxograma:** `fluxograma_check_quota.png`

---

### 11. `preview_file()`

**Função:** Permite ver o conteúdo de ficheiros texto dentro da reciclagem.  
**Comportamento:**
- Verifica o tipo de ficheiro com `file`.  
- Se for texto → mostra as primeiras 10 linhas (`head -n 10`).  
- Caso contrário → mostra o tipo MIME.

> **Fluxograma:** `fluxograma_preview_file.png`

---

## 🧠 Estrutura de Dados

O ficheiro `metadata.db` atua como uma **base de dados CSV**, onde cada linha representa um ficheiro eliminado.  
O formato é:
ID, ORIGINAL_NAME, ORIGINAL_PATH, DELETION_DATE, FILE_SIZE, FILE_TYPE, PERMISSIONS, OWNER


Exemplo:
1696234567_ab12cd,document.txt,/home/user/Documents/document.txt,2025-10-21 14:30:22,4096,file,644,user:user


---

## 🧩 Módulos Auxiliares

### Ficheiro `config`
- **MAX_SIZE_MB** — tamanho máximo da reciclagem  
- **RETENTION_DAYS** — dias antes de autoeliminação  

### Ficheiro `recyclebin.log`
- Guarda operações com timestamp:
2025-10-22 14:15:07 | Deleted '/home/user/file.txt' -> ID: 1696234890_abc123


---

## ⚠️ Tratamento de Erros

O sistema deteta e trata as seguintes situações:
- Ficheiro inexistente ou sem permissões  
- Diretórios inacessíveis  
- Erros de escrita no `metadata.db`  
- Caminhos inválidos durante restauro  
- Input incorreto do utilizador  

Cada função devolve **código 0 (sucesso)** ou **1 (erro)**, permitindo automação e testes programáticos.

---

## 🧮 Complexidade Global

| Categoria | Complexidade |
|------------|---------------|
| Inicialização e Configuração | O(1) |
| Deleção e Restauro | O(n) |
| Pesquisa e Listagem | O(n) |
| Estatísticas | O(n) |
| Auto-cleanup e Quota | O(n) |
| Pré-visualização | O(1) |

---

## 📊 Conclusões

O projeto implementa um sistema de reciclagem modular, robusto e seguro.  
Todas as funções cumprem os requisitos do guião, com:
- Tratamento completo de erros;  
- Registo persistente em `metadata.db`;  
- Estrutura escalável e extensível;  
- Compatibilidade com testes automatizados e documentação técnica.

> **Imagens pendentes:** adicionar os fluxogramas listados acima (`.png` ou `.jpg`) após desenharem no diagrams.net / Lucidchart.

---

## ✍️ Autores

- [Teu Nome]  
- [Colega de Grupo]  
- Universidade de Aveiro — Sistemas Operativos 2025/2026
