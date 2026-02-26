# FluentORM DTO Generator

Gerador automatico de DTOs no padrao do FluentORM para tabelas de:

- MySQL
- SQL Server (MSSQL)

## Objetivo

Ler metadata de tabelas via `INFORMATION_SCHEMA` e gerar units Delphi com:

- `[Table('...')]`
- `[Column('...')]`
- `[Key(True/False)]` para chaves primarias
- propriedades e tipos Delphi basicos mapeados automaticamente

Regras adicionais implementadas:

- MySQL `tinyint(1)` -> `Boolean`
- Colunas nullable de tipos escalares com `--nullable_mode=native` (padrao) mantem tipo Delphi nativo
- Opcional: `--nullable_mode=variant` para representar nullable escalar como `Variant`
- Colunas de auditoria (`data_criacao`, `data_atualizacao`, `created_at`, `updated_at`) recebem `[ReadOnly]`

Conexao usada:

- MySQL: ADO
- SQL Server: ADO

## Arquivos

- `FluentORM.DtoGenerator.dpr`
- `uGenerator.Main.pas`

## Uso

Executando sem argumentos:

```bash
FluentORM.DtoGenerator.exe
```

Mostra ajuda dos parametros.

### MySQL (uma tabela)

```bash
FluentORM.DtoGenerator.exe --db=mysql --server=localhost --port=3306 --database=chat_database --user=root --password=admin --ado_provider_mysql=MSDASQL --mysql_odbc_driver="MySQL ODBC 8.0 Unicode Driver" --table=usuario --output=.\GeneratedDTOs
```

### MySQL (todas as tabelas)

```bash
FluentORM.DtoGenerator.exe --db=mysql --server=localhost --port=3306 --database=chat_database --user=root --password=admin --ado_provider_mysql=MSDASQL --mysql_odbc_driver="MySQL ODBC 8.0 Unicode Driver" --output=.\GeneratedDTOs
```

### SQL Server (uma tabela)

```bash
FluentORM.DtoGenerator.exe --db=sqlserver --server=localhost --port=57436 --database=MinhaBase --schema=dbo --user=sa --password=senha --ado_provider=SQLOLEDB --table=usuario --output=.\GeneratedDTOs
```

### SQL Server (todas as tabelas)

```bash
FluentORM.DtoGenerator.exe --db=sqlserver --server=localhost --port=57436 --database=MinhaBase --schema=dbo --user=sa --password=senha --ado_provider=SQLOLEDB --output=.\GeneratedDTOs
```

## Parametros

- `--db=mysql|sqlserver`
- `--server=...`
- `--port=...` (opcional, padrao 3306 MySQL / 1433 SQL Server)
- `--database=...`
- `--user=...`
- `--password=...`
- `--schema=...` (opcional; padrao: nome do banco no MySQL e `dbo` no SQL Server)
- `--table=...` (opcional; se omitido, gera todas as tabelas)
- `--output=...` (opcional; padrao `.\GeneratedDTOs`)
- `--ado_provider=...` (opcional para SQL Server; padrao `SQLOLEDB`)
- `--ado_provider_mysql=...` (opcional para MySQL; padrao `MSDASQL`)
- `--mysql_odbc_driver=...` (opcional para MySQL; padrao `MySQL ODBC 8.0 Unicode Driver`)
- `--connstr=...` (opcional; sobrescreve a string de conexao inteira)
- `--nullable_mode=native|variant` (opcional; padrao `native`)

## Dependencias

- ADO disponivel no Windows.
- Para MySQL via `MSDASQL`, driver ODBC do MySQL instalado.
- Para SQL Server, provider OLE DB instalado (`SQLOLEDB` ou `MSOLEDBSQL`).
