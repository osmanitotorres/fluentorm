# Sample05 - FluentORM com UniDAC

Exemplo de console que mostra, passo a passo, como usar o FluentORM com o
**Devart UniDAC** em vez do FireDAC. O mesmo codigo roda em **MySQL**,
**SQL Server** e **PostgreSQL**; so muda o `ProviderName` da conexao.

> **Requer o UniDAC instalado.** Por isso este projeto nao entra no `build.bat`
> da raiz. Sem o UniDAC, o resto do FluentORM continua compilando normalmente:
> apenas `uFluentORM.Executor.UniDAC.pas` depende dele.

## Por que usar UniDAC

- **SQL Server em qualquer edicao do Delphi**: o driver FireDAC MSSQL so existe nas
  edicoes Enterprise/Architect.
- **Sem DLL cliente**: no modo Direct, MySQL e PostgreSQL conectam sem
  `libmysql.dll`/`libpq.dll`.
- **Mesma API para varios bancos**: troca-se o provider, nao o codigo.

## Como o FluentORM se encaixa

```
TSQLBuilder ----------------------------> SQL + parametros (:nome)
TRepository<T> --> ISQLExecutor --> TUniDACSQLExecutor --> TUniConnection / TUniQuery
                                    (uFluentORM.Executor.UniDAC.pas)
```

O builder e o repositorio nao conhecem o UniDAC. Eles falam com `ISQLExecutor`;
o `TUniDACSQLExecutor` traduz para `TUniQuery`/`TUniConnection`.

## Passo a passo

### 1. Units no projeto

```pascal
uses
  Uni,                    // TUniConnection, TUniQuery
  MySQLUniProvider,       // um provider por banco usado (obrigatorio!)
  SQLServerUniProvider,
  PostgreSQLUniProvider,
  uFluentORM.Types, uFluentORM, uFluentORM.Attributes, uFluentORM.Metadata,
  uFluentORM.Executor, uFluentORM.Executor.UniDAC, uFluentORM.Repository;
```

Sem a unit do provider, o UniDAC gera *"Provider is not defined"*.

### 2. Criar o executor (duas formas)

**A) O executor cria e e dono da conexao** (mais simples):

```pascal
var
  Exec: ISQLExecutor;
begin
  Exec := TUniDACSQLExecutor.CreateConnected(
    'MySQL', 'localhost', 3306, 'fluentorm_demo', 'usuario', 'senha');
  // SQL Server: CreateConnected('SQL Server', 'localhost,1433', 0, ...)
  // PostgreSQL: CreateConnected('PostgreSQL', 'localhost', 5432, ...)
```

No MySQL ele liga `MySQL.Direct=True` (sem `libmysql.dll`). Ao ser liberado,
desfaz transacao pendente e fecha a conexao.

**B) Usar uma `TUniConnection` que ja existe** (DataModule, por exemplo):

```pascal
Exec := TUniDACSQLExecutor.Create(DM.UniConnection1);            // dialeto pelo ProviderName
Exec := TUniDACSQLExecutor.Create(DM.UniConnection1, dbMSSQL);   // ou explicito
```

Aqui o executor **nao** libera a conexao. Libere o executor (zere a interface)
antes de liberar a conexao.

O dialeto vem de `ProviderName`: `MySQL` -> `dbMySQL`, `SQL Server` -> `dbMSSQL`,
`PostgreSQL` -> `dbPostgreSQL`, `InterBase` -> `dbFirebird`, `SQLite` -> `dbSQLite`.

### 3. CRUD com `TRepository<T>`

```pascal
Repo := TRepository<TUsuarioDTO>.Create(Exec);
try
  TSQLTransaction.ExecuteInTransaction(Exec,
    procedure
    begin
      Repo.Insert(U);     // id gerado volta para U.Id (nos 3 bancos)
      Repo.Update(U);
    end);                 // commit; excecao = rollback
  Repo.Delete(U);
finally
  Repo.Free;
end;
```

### 4. Leitura

```pascal
U := Repo.FindById(10);          // nil se nao existir; quem chama libera
Lista := Repo.FindAll('nome');   // TObjectList<T> (dona dos objetos)
```

### 5. SQL Builder lido com `TUniQuery`

```pascal
SQL.SetDatabaseType(ExecObj.GetDatabaseType);
SQL.Select.Fields(['id', 'email']).From('usuario').WhereLike('email', '@').Paginate(1, 10);

SQLText := SQL.ToSQL;                                   // gera SQL e parametros
Q := ExecObj.OpenQuery(SQLText, SQL.ToSQLParams);       // TUniQuery; quem chama libera
Total := ExecObj.ExecuteScalar(SQL.ToSQLCount, SQL.ToSQLParams);
```

Para usar um `TUniQuery` seu (ligado a um grid, por exemplo), basta copiar o SQL
e os parametros:

```pascal
UniQuery1.SQL.Text := SQL.ToSQL;
for P in SQL.ToSQLParams do
  UniQuery1.ParamByName(P.Name).Value := P.Value;
UniQuery1.Open;
```

## Executando o exemplo

1. Crie as tabelas com o script do Sample03:
   `..\Sample03_MultiBanco\scripts\mysql.sql`, `mssql.sql` ou `postgresql.sql`.
2. Abra `Sample05.dpr` na IDE (com o UniDAC instalado) e compile.
3. Rode:

```bat
Sample05.exe --db=mysql    --server=localhost --database=fluentorm_demo --user=root     --password=SENHA
Sample05.exe --db=mssql    --server=localhost --database=fluentorm_demo --user=sa       --password=SENHA
Sample05.exe --db=postgres --server=localhost --database=fluentorm_demo --user=postgres --password=SENHA
```

Opcoes: `--port=N`, `--mode=component` (usa uma `TUniConnection` da aplicacao,
forma B), `--keep` (nao apaga os registros), `--pause`.

## Diferencas em relacao ao FireDAC

| | FireDAC | UniDAC |
|--|---------|--------|
| Executor | `TFireDACSQLExecutor` | `TUniDACSQLExecutor` |
| Escolha do banco | `DriverID` (`MySQL`, `MSSQL`, `PG`) | `ProviderName` (`MySQL`, `SQL Server`, `PostgreSQL`) |
| Driver | `FireDAC.Phys.MySQL`... | `MySQLUniProvider`... |
| Cliente MySQL | `libmysql.dll` | nenhum (modo Direct) |
| SQL Server no Delphi Professional | indisponivel | disponivel |
| Pool de conexoes | `TFireDACPooledConnectionFactory` | `TUniConnection.Pooling := True` |

## Problemas comuns

- **"Provider is not defined"**: falta a unit do provider no `uses`.
- **Unit `Uni` nao encontrada**: o UniDAC nao esta instalado ou o *Library path*
  da plataforma (Win32/Win64) nao inclui as pastas do UniDAC.
- **Insert no SQL Server**: o repositorio envia um bloco com
  `SET NOCOUNT ON; DECLARE @fluent_ids TABLE(...); INSERT ... OUTPUT ... INTO @fluent_ids; SELECT ...`.
  Se o UniDAC reclamar do bloco, informe o erro: e o ponto que mais vale validar.

> O executor e este exemplo foram escritos sem o UniDAC instalado e ainda nao
> foram compilados. Ao instalar o UniDAC, compile e rode este exemplo primeiro.
