
**Ficheiro principal:** `recycle_bin.sh`  
**Ficheiros de apoio:** `test_suite.sh`, `README.md`, `TECHNICAL_DOC.md`, `TESTING.md`

Cada operação é modular e implementada como função Bash independente.

---

##  Fluxograma Geral do Programa

![Fluxograma main](fluxogramas/main().png)

---

##  Descrição Técnica das Funções

### 1. `main()`

**Função:** Ponto de entrada do script.  
**Comportamento:**
- Chama `initialize_recyclebin()` caso o sistema ainda não esteja configurado.  
- Lê argumentos de linha de comandos e invoca a função correspondente.  
- Mostra mensagens de ajuda ou erro quando necessário.  

**Entradas:** Argumentos do utilizador  
**Saídas:** Código de retorno (0 ou 1)  
**Complexidade:** O(1)

![Fluxograma main](fluxogramas/main().png)

---

### 2. `main_menu()`

**Função:** Apresenta um menu interativo no terminal.  
**Comportamento:**
- Mostra opções como “Listar”, “Eliminar”, “Restaurar”, etc.  
- Lê a escolha do utilizador e invoca a função correspondente.  
- Permite sair com `0` ou `q`.  

**Entradas:** Input do utilizador  
**Saídas:** Execução das funções selecionadas  
**Complexidade:** O(n) (n = número de opções)

![Fluxograma main_menu](fluxogramas/main_menu().drawio.png)

---

### 3. `initialize_recyclebin()`

**Função:** Cria toda a estrutura de diretórios e ficheiros necessários.  
**Comportamento:**
- Verifica se a pasta `.recycle_bin` já existe.  
- Caso não exista, cria `files/`, `metadata.db`, `config` e `log`.  
- Garante a presença do cabeçalho CSV no `metadata.db`.

**Entradas:** Nenhuma  
**Saídas:** Mensagem de confirmação no terminal  
**Complexidade:** O(1)

![Fluxograma initialize_recyclebin](fluxogramas/initialize_recyclebin().png)

---

### 4. `generate_unique_id()`

**Função:** Gera um identificador único com timestamp + string aleatória.  
**Utilização:** Evita colisões de nomes na reciclagem.  

**Método:**  
`id=$(date +%s%N)_$(cat /dev/urandom | tr -dc 'a-z0-9' | fold -w 6 | head -n 1)`

**Complexidade:** O(1)

![Fluxograma generate_unique_id](fluxogramas/generate_unique_id().drawio.png)

---

### 5. `delete_file()`

**Função:** Move um ou mais ficheiros para a reciclagem.  
**Comportamento:**
1. Verifica se o ficheiro existe.  
2. Obtém metadados com `stat` e `realpath`.  
3. Gera um ID único.  
4. Move o ficheiro para `~/.recycle_bin/files/<ID>`.  
5. Guarda uma linha no `metadata.db`.  
6. Mostra mensagem colorida ao utilizador.  

**Campos registados no `metadata.db`:**  
`ID, ORIGINAL_NAME, ORIGINAL_PATH, DELETION_DATE, FILE_SIZE, FILE_TYPE, PERMISSIONS, OWNER`

**Erros tratados:**  
- Ficheiro inexistente  
- Falta de permissões  
- Diretório não acessível  

**Complexidade:** O(n), n = número de ficheiros  

![Fluxograma delete_file](fluxogramas/delete_file().drawio.png)

---

### 6. `list_recycled()`

**Função:** Lista todos os ficheiros presentes na reciclagem.  
**Comportamento:**
- Lê o ficheiro `metadata.db` linha a linha.  
- Formata e apresenta os dados em tabela.  
- Mostra aviso se a reciclagem estiver vazia.  

**Complexidade:** O(n)  

![Fluxograma list_recycled](fluxogramas/list_recycled().drawio.png)

---

### 7. `restore_file()`

**Função:** Restaura ficheiros para o caminho original.  
**Comportamento:**
1. Procura o ID ou nome no `metadata.db`.  
2. Garante que o diretório de destino existe.  
3. Se já existir um ficheiro com o mesmo nome → renomeia para `<nome>_restored_<timestamp>`.  
4. Restaura permissões e remove a linha do `metadata.db`.  

**Complexidade:** O(n)  

![Fluxograma restore_file](fluxogramas/restore_file().drawio.png)

---

### 8. `search_recycled()`

**Função:** Pesquisa ficheiros no `metadata.db` por nome, extensão ou parte do caminho.  
**Implementação:** Utiliza `grep -i` para pesquisa insensível a maiúsculas/minúsculas.  

**Complexidade:** O(n)

![Fluxograma search_recycled](fluxogramas/search_recycled().drawio.png)

---

### 9. `empty_recyclebin()`

**Função:** Apaga permanentemente os ficheiros da reciclagem.  
**Comportamento:**
- Pede confirmação do utilizador (`yes/NO`).  
- Se confirmado, remove todos os ficheiros da pasta `files/` e recria o cabeçalho do `metadata.db`.  
- Regista a operação no log.

![Fluxograma empty_recyclebin](fluxogramas/empty_recyclebin().drawio.png)

---

### 10. `show_statistics()`

**Função:** Calcula estatísticas sobre os ficheiros armazenados.  
**Dados exibidos:**
- Número total de itens  
- Tamanho total (bytes e legível)  
- Ficheiros vs diretórios  
- Média de tamanho  
- Datas mais antiga e mais recente  

![Fluxograma show_statistics](fluxogramas/show_statistics().drawio.png)

---

### 11. `auto_cleanup()`

**Função:** Elimina automaticamente ficheiros antigos de acordo com o valor `RETENTION_DAYS` do ficheiro `config`.  
**Comportamento:**
- Lê a configuração.  
- Percorre o `metadata.db` e compara a data de eliminação com a data atual.  
- Remove entradas antigas e atualiza o log.

![Fluxograma auto_cleanup](fluxogramas/auto_cleanup().drawio.png)

---

### 12. `check_quota()`

**Função:** Verifica se o tamanho total da reciclagem ultrapassa `MAX_SIZE_MB`.  
**Comportamento:**
- Calcula o tamanho atual com `du -sm`.  
- Mostra percentagem de uso.  
- Caso ultrapasse, alerta o utilizador e sugere `auto_cleanup`.

![Fluxograma check_quota](fluxogramas/check_quota().drawio.png)

---

### 13. `preview_file()`

**Função:** Permite ver o conteúdo de ficheiros texto dentro da reciclagem.  
**Comportamento:**
- Verifica o tipo de ficheiro com `file`.  
- Se for texto → mostra as primeiras 10 linhas (`head -n 10`).  
- Caso contrário → mostra o tipo MIME.

![Fluxograma preview_file](fluxogramas/preview_file().drawio.png)

---

### 14. `display_help()`

**Função:** Mostra as opções disponíveis e o formato correto de utilização.  
**Comportamento:**  
- Exibe um texto com todas as funções e exemplos de uso.  
- É chamada quando não há argumentos ou quando o utilizador pede `--help`.

**Complexidade:** O(1)

![Fluxograma display_help](fluxogramas/display_help().drawio.png)

---

### 15. `verbose_echo()`

**Função:** Mostra mensagens apenas se o modo `VERBOSE` estiver ativo.  
**Comportamento:**
- Verifica a variável global `VERBOSE`.  
- Caso seja `true`, imprime mensagens coloridas com timestamps.  

**Complexidade:** O(1)

![Fluxograma verbose_echo](fluxogramas/verbose_echo().drawio.png)

---

### 16. `log_message()`

**Função:** Regista eventos no ficheiro `recyclebin.log`.  
**Comportamento:**
- Recebe mensagem como argumento.  
- Acrescenta linha com data e hora formatadas.  
- Usada por várias funções (`delete_file`, `auto_cleanup`, etc.).  

**Complexidade:** O(1)

![Fluxograma log_message](fluxogramas/log_message().drawio.png)

---

##  Estrutura de Dados

O ficheiro `metadata.db` atua como uma **base de dados CSV**, onde cada linha representa um ficheiro eliminado.  
O formato é:

ID, ORIGINAL_NAME, ORIGINAL_PATH, DELETION_DATE, FILE_SIZE, FILE_TYPE, PERMISSIONS, OWNER

Exemplo:
1696234567_ab12cd,document.txt,/home/user/Documents/document.txt,2025-10-21 14:30:22,4096,file,644,user:user


---

##  Módulos Auxiliares

### Ficheiro `config`
- **MAX_SIZE_MB** — tamanho máximo da reciclagem  
- **RETENTION_DAYS** — dias antes de autoeliminação  

### Ficheiro `recyclebin.log`
- Guarda operações com timestamp:  
  `2025-10-22 14:15:07 | Deleted '/home/user/file.txt' -> ID: 1696234890_abc123`

---

##  Tratamento de Erros

O sistema deteta e trata as seguintes situações:
- Ficheiro inexistente ou sem permissões  
- Diretórios inacessíveis  
- Erros de escrita no `metadata.db`  
- Caminhos inválidos durante restauro  
- Input incorreto do utilizador  

Cada função devolve **código 0 (sucesso)** ou **1 (erro)**, permitindo automação e testes programáticos.

---

##  Conclusões

O projeto implementa um sistema de reciclagem modular, robusto e seguro.  
Todas as funções cumprem os requisitos do guião, com:
- Tratamento completo de erros;  
- Registo persistente em `metadata.db`;  
- Estrutura escalável e extensível;  
- Compatibilidade com testes automatizados e documentação técnica.

---

##  Autores

- **Diogo Ruivo**  
- **David Cálix**
