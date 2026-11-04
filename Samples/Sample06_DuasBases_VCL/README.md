# Sample06 - Duas bases ao mesmo tempo (VCL + FireDAC: MySQL / PostgreSQL / SQLite)

Formulario com duas areas independentes, **Base A** e **Base B**. Em cada uma voce
escolhe o banco (MySQL, PostgreSQL ou SQLite), conecta, cria a estrutura e manipula os
dados. Com as duas conectadas, os botoes do meio copiam clientes de uma base
para a outra.

O objetivo e mostrar que a **mesma classe** (`TClienteDTO`) e o **mesmo codigo**
funcionam nos dois bancos ao mesmo tempo, cada um com sua conexao, executor e
`TRepository<T>`. O FluentORM gera o SQL de cada dialeto (aspas, `LIMIT/OFFSET`,
chave gerada com `LAST_INSERT_ID()` no MySQL e `RETURNING` no PostgreSQL, tipos
`TINYINT(1)` x `BOOLEAN`...).

## O que testar

1. **Base A = MySQL, Base B = PostgreSQL**: conecte as duas, clique em
   *Criar banco/tabela* em cada uma e depois em *Gerar 10 clientes*.
2. **Copiar A >> B / A << B**: copia o cliente selecionado (le com `FindById` na
   origem, grava com `Insert` no destino). O novo id aparece no log.
3. **Todos A >> B**: copia todos os clientes numa unica transacao no destino.
4. **Comparar**: conta os clientes nas duas bases.
5. Pesquisa (sem diferenca de maiusculas nos dois bancos), *Somente ativos*,
   paginacao, *Editar nome* e *Excluir* em cada lado.
6. Tambem funciona com os dois lados no mesmo banco (ex.: duas databases MySQL).
7. **SQLite**: escolha "SQLite" em um dos lados. Nao ha servidor, usuario nem
   senha: o campo *Arquivo* indica o arquivo `.db` (caminho relativo = pasta do
   exe), criado automaticamente ao conectar. Teste, por exemplo,
   *Base A = SQLite* e *Base B = PostgreSQL* e copie os clientes entre elas.

### SQLite

- Motor embutido no executavel (`FireDAC.Phys.SQLiteWrapper.Stat`): nao precisa de `sqlite3.dll`.
- Conexao aberta com `LockingMode=Normal`, para que as duas bases possam usar o mesmo arquivo ao mesmo tempo (o padrao do FireDAC, `Exclusive`, bloquearia a segunda).
- Chave gerada lida com `SELECT last_insert_rowid()` na mesma conexao.
- `TGUID` e gravado como texto de 36 caracteres (o SQLite nao tem tipo uuid).

O log da parte de baixo mostra todo o SQL executado, com o prefixo da base
(`[A/MySQL]`, `[B/PostgreSQL]`) e os valores dos parametros.

## Preparacao

- Compile em **Win64** (`build.bat` na raiz gera `Build\Win64\Sample06.exe`).
- O banco padrao e `fluentorm_sample06` (separado do `fluentorm_demo` do Sample04,
  porque a tabela `cliente` aqui tem outras colunas).
- O botao *Criar banco/tabela* cria o database e a tabela. Se preferir, rode
  `script-mysql.sql` / `script-postgresql.sql`.
- Usuarios padrao: `osmanito` (MySQL) e `postgres` (PostgreSQL). A senha e digitada na tela.
- SQLite: arquivo padrao `fluentorm_sample06.db`, na pasta do executavel.

## DLLs cliente

Ao abrir, o programa procura e carrega (resultado no log):

| Banco | Procura em |
|-------|------------|
| PostgreSQL | pasta do exe, subpasta `lib`, `C:\Program Files\PostgreSQL\<versao>\bin\libpq.dll` |
| MySQL | pasta do exe, subpasta `lib`, `C:\Program Files\MySQL\<versao>\lib\libmysql.dll` (dependencias em `bin`) |

As duas DLLs usam OpenSSL 3 (`libssl-3-x64.dll`); a libpq e carregada primeiro e
a libmysql reaproveita a mesma OpenSSL ja carregada.

## Detalhe: `Variant` nulo no PostgreSQL

`data_nascimento` e um `Variant` (pode ser NULL). O PostgreSQL rejeita um NULL
enviado como texto numa coluna `DATE`, por isso o DTO informa o tipo:

```pascal
[Column('data_nascimento', ftDate)]   // requer Data.DB no uses do DTO
property DataNascimento: Variant read FDataNascimento write FDataNascimento;
```

O MySQL aceita sem o tipo; o PostgreSQL precisa dele.

## Arquivos

| Arquivo | Conteudo |
|---------|----------|
| `uSample06.Model.pas` | `TClienteDTO`, DDL por banco, log por base, carga das DLLs |
| `uFraBase.pas/.dfm` | frame de uma base (conexao, estrutura, lista, edicao) |
| `uFrmPrincipal.pas/.dfm` | duas instancias do frame + copia/comparacao entre bases |
