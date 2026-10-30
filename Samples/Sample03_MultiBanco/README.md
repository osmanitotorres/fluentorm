# Sample03 - CRUD multi-banco (console)

Mesmo codigo rodando em **MySQL** e **PostgreSQL** (FireDAC) e **SQL Server** (ADO, via `TADOSQLExecutor`).

O SQL Server usa ADO porque o driver `FireDAC.Phys.MSSQL` so existe nas edicoes Enterprise/Architect do Delphi.
Quem tem essas edicoes pode trocar `CreateADOExecutor` por `CreateFireDACExecutor` com `DriverID=MSSQL`
(adicione `FireDAC.Phys.MSSQL` ao `uses` e use `Server=host,porta`).

O que o exemplo mostra:

1. `TRepository<T>`: Insert/Update/Delete/Count dentro de `TSQLTransaction.ExecuteInTransaction`
   (a chave gerada volta para a propriedade `[Key]` em todos os bancos).
2. Rollback automatico quando o bloco da transacao gera excecao.
3. Mapeamento de tipos: `Int64`, `TGUID`, `Currency`, `Double`, `TDate`, `TBytes` e `Variant` nulo.
4. `TSQLBuilder` com filtro, paginacao (`LIMIT/OFFSET` ou `OFFSET/FETCH`) e `ToSQLCount`,
   lido com `OpenQuery(SQL, Builder.ToSQLParams)` do executor em uso (FireDAC ou ADO).

## Preparacao

Rode o script do seu banco em `scripts/` (`mysql.sql`, `mssql.sql`, `postgresql.sql`).
O script do SQL Server cria uma trigger em `produto` para demonstrar que o insert funciona com triggers.

Bibliotecas cliente necessarias (mesma arquitetura do executavel, 32 ou 64 bits):

- MySQL: `libmysql.dll` (ou `libmariadb.dll`) ao lado do exe.
- PostgreSQL: `libpq.dll` e dependencias ao lado do exe (pasta `bin` do PostgreSQL).
- SQL Server: "Microsoft OLE DB Driver for SQL Server" (`MSOLEDBSQL`) instalado, ou `--provider=SQLOLEDB` (legado, ja vem no Windows).

## Execucao

```bat
Sample03.exe --db=mysql    --server=localhost --database=fluentorm_demo --user=root     --password=admin
Sample03.exe --db=mssql    --server=localhost --database=fluentorm_demo --user=sa       --password=senha
Sample03.exe --db=postgres --server=localhost --database=fluentorm_demo --user=postgres --password=admin
```

Opcoes: `--port=N`, `--keep` (nao apaga os registros criados), `--pause`.
SQL Server: `--provider=MSOLEDBSQL|MSOLEDBSQL19|SQLOLEDB`, `--encrypt=Yes`; com `--user=` vazio usa autenticacao do Windows.
