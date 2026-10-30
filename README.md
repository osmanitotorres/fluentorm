                                                                              
  ## FluentORM                                                                  
  --------------------------------------------------------------------------  
  Minimalist and high-performance Micro ORM for Delphi                       
                                                                              
  Author: Osmanito Torres (Brazil)                                                    
                                                                              
  Description:                                                                
    FluentORM is a lightweight and efficient micro-ORM designed to provide   
    type-safe CRUD operations, SQL generation, and metadata-based mapping    
    for Delphi applications. It emphasizes simplicity, performance, and      
    explicit behavior over hidden abstractions.                               
                                                                              
    The framework includes:                                                   
      - Fluent SQL Builder                                                    
      - Generic Repository pattern                                            
      - Metadata caching via RTTI                                             
      - Transaction support                                                    
      - Multi-database dialect handling                                       
                                                                              
  Disclaimer:                                                                 
    This software is provided "as is", without warranty of any kind,         
    express or implied, including but not limited to the warranties of        
    merchantability, fitness for a particular purpose and noninfringement.   
                                                                              
    The author assumes no responsibility or liability for any damages         
    arising from the use of this component in any environment, including     
    production systems. Use at your own risk.                                 
                                                                             
  Notes:                                                                      
    This component was designed with a minimalist philosophy and does not    
    aim to replicate the complexity of full-scale ORM frameworks. 
            
                                                                              
 LANGUAGE BRAZILIAN PORTUGUESE

 ## FluentORM (Delphi/Pascal)

FluentORM e um builder SQL fluente para Delphi que permite montar consultas de forma encadeada, legivel e com menos concatenacao manual de strings.

O foco da biblioteca e:
- gerar SQL de forma simples e previsivel;
- facilitar consultas complexas (`JOIN`, `GROUP BY`, `HAVING`, paginação);
- manter compatibilidade com multiplos bancos via `TSQLDatabaseType`;
- oferecer saida de SQL bruto e SQL formatado/indentado.

## Recursos

- API fluente (`Select`, `From`, `Where`, `AndWhere`, `OrWhere`, etc.).
- Suporte a `JOIN` (`INNER`, `LEFT`, `RIGHT`, `FULL` - este ultimo nao existe no MySQL).
- `WHERE` com operadores (`=`, `<>`, `>`, `<`, `>=`, `<=`, `LIKE`, `BETWEEN`, `IN`).
- `GROUP BY` e `HAVING`.
- Ordenacao (`ORDER BY`) e paginacao (`Limit`, `Offset`, `Paginate`).
- Geracao de SQL de contagem (`ToSQLCount`).
- Formatacao e indentacao do SQL final (`ToFormattedSQL`, `ToFormattedSQLCount`).
- Tratamento automatico de `NULL` (`opEqual` -> `IS NULL`, `opNotEqual` -> `IS NOT NULL`).
- Modo estrito opcional para bloquear SQL raw (`StrictMode`).
- Hook de observabilidade com evento `OnSQLGenerated`.
- SQL parametrizado opcional com nomes (`UseNamedParams`).
- Marcador de parametro `:` por padrao em todos os bancos (configuravel em `ParamPrefix`).
- Quoting de identificadores por dialeto: `[x]` (SQL Server), `` `x` `` (MySQL), `"x"` (PostgreSQL/Firebird/SQLite).
- Suporte nativo a `IN`/`NOT IN` sem `Raw` (compativel com `StrictMode` e `UseNamedParams`).
- Quoting opcional de identificadores por banco (`QuoteIdentifiers`).
- Quoting consistente tambem em `Fields`, `Field`, alias (`AS`) e `FromSQL(..., Alias)`.
- `HAVING` expandido com `AndHaving`, `OrHaving`, `AndHavingRaw`, `OrHavingRaw`.
- Grupos logicos com parenteses sem `Raw` em `WHERE` e `HAVING`.
- Suporte nativo a `EXISTS`/`NOT EXISTS` no `WHERE` (incluindo `AND`/`OR`) sem usar `Raw`.
- Suporte nativo a `EXISTS`/`NOT EXISTS` tambem no `HAVING` (incluindo `AND`/`OR`).
- Suporte a `UNION` e `UNION ALL` com SQL literal ou com outro `TSQLBuilder`.
- Suporte a `INTERSECT` e `EXCEPT` com SQL literal ou com outro `TSQLBuilder`.
- Suporte a CTE (`WITH` e `WITH RECURSIVE`) com SQL literal ou com outro `TSQLBuilder`.
- Defaults de seguranca ativados: `StrictMode=True` e `UseNamedParams=True`.
- Camada ORM minima com DTO/RTTI: atributos, metadados em cache, executor desacoplado e `Repository<T>`.
- `TRepository<T>` com chave gerada devolvida para a entidade nos tres bancos (inclusive SQL Server com trigger) e parametros tipados (`Int64`, `Currency`, `TDate`, `TGUID`, `TBytes`, `Variant`...).
- Leitura de consultas do builder com `TFireDACSQLExecutor.OpenQuery(SQL, Builder.ToSQLParams)`.

## Estrutura do projeto

- `uFluentORM.pas`: unit principal do builder SQL.
- `uFluentORM.Types.pas`: tipos compartilhados (`TSQLParam`, `TSQLParams`, `TSQLDatabaseType`, `TSQLDialect`).
- `uFluentORM.Attributes.pas`: atributos DTO (`Table`, `Column`, `Key`, `Ignore`, `ReadOnly`).
- `uFluentORM.Metadata.pas`: leitura RTTI e cache de metadados de entidades.
- `uFluentORM.Executor.pas`: contrato de execucao SQL desacoplado (`ISQLExecutor`, `ISQLDialectInfo`, `ISQLIdentityExecutor`).
- `uFluentORM.Executor.FireDAC.pas`: executor pronto para FireDAC (`TFireDACSQLExecutor`).
- `uFluentORM.Executor.ADO.pas`: executor ADO (`TADOSQLExecutor`), para SQL Server em edicoes do Delphi sem o driver FireDAC MSSQL.
- `uFluentORM.Executor.UniDAC.pas`: executor Devart UniDAC (`TUniDACSQLExecutor`). Requer o UniDAC instalado; por isso nao entra no `build.bat`.
- `uFluentORM.ConnectionPool.FireDAC.pas`: factory de conexoes com pool do FireDAC.
- `uFluentORM.Repository.pas`: CRUD minimo com `TRepository<T>`.
- `Samples/`: exemplos de uso (VCL em `Sample01`/`Sample02`; console multi-banco em `Sample03_MultiBanco`).
- `Tests/`: testes de console sem dependencia de servidor.
- `build.bat`: compila biblioteca, testes, gerador e exemplos com o Delphi instalado e roda os testes (saida em `build.log`).
- `Tools/FluentORM.DtoGenerator/`: gerador de DTOs a partir do banco (MySQL, SQL Server e PostgreSQL).

## Bancos suportados

O mesmo codigo (builder e `TRepository<T>`) funciona em **MySQL**, **SQL Server** e **PostgreSQL**; Firebird e SQLite tambem sao tratados pelo builder.
As diferencas de dialeto (quoting, literais, paginacao, chave gerada, tipos de parametro) sao resolvidas automaticamente:

- no builder, por `SQL.SetDatabaseType(dbMySQL | dbMSSQL | dbPostgreSQL ...)`;
- no repositorio, pelo `DriverID` da conexao FireDAC (`MySQL`, `MSSQL`, `PG`, inclusive drivers customizados como `MySQL80` ou `MSSQL2019`), inclusive quando a conexao vem do pool (`ConnectionDefName`).

Bibliotecas cliente do FireDAC (mesma arquitetura do executavel, 32 ou 64 bits):

| Banco | DriverID | Unit do driver | Cliente necessario |
|-------|----------|----------------|--------------------|
| MySQL / MariaDB | `MySQL` | `FireDAC.Phys.MySQL` | `libmysql.dll` ou `libmariadb.dll` |
| SQL Server | `MSSQL` | `FireDAC.Phys.MSSQL` (*somente Enterprise/Architect*) | ODBC Driver 17/18 for SQL Server |
| PostgreSQL | `PG` | `FireDAC.Phys.PG` | `libpq.dll` (+ dependencias da pasta `bin` do PostgreSQL) |

No SQL Server, informe a porta junto do servidor (`Server=host,1433`) e, com o ODBC Driver 18 e certificado local, use `Encrypt=No`.

**SQL Server sem FireDAC (Delphi Professional):** o driver `FireDAC.Phys.MSSQL` nao vem nas edicoes Professional/Community. Para elas existe o `TADOSQLExecutor` (`uFluentORM.Executor.ADO.pas`, ADO/OLE DB), com o mesmo contrato do executor FireDAC (`Execute`, `ExecuteScalar`, `OpenQuery`, transacoes) e o mesmo comportamento no `TRepository<T>`:

```pascal
uses Winapi.ActiveX, uFluentORM.Executor, uFluentORM.Executor.ADO, uFluentORM.Repository;

// Em aplicacoes console: CoInitialize(nil) antes de usar ADO.
Exec := TADOSQLExecutor.CreateFromConnectionString(
  TADOSQLExecutor.MSSQLConnectionString('localhost,1433', 'MinhaBase', 'sa', 'senha'),
  dbMSSQL);
Repo := TRepository<TUsuarioDTO>.Create(Exec);
```

Provider recomendado: `MSOLEDBSQL` (Microsoft OLE DB Driver for SQL Server, suporta `date`/`time`/`datetime2` nativos). O `SQLOLEDB` ja vem no Windows, mas devolve `date`/`datetime2` como texto.

## Tutorial rapido

## 1. Adicione a unit no `uses`

```pascal
uses
  uFluentORM;
```

## 2. Crie uma instancia do builder

```pascal
var
  SQL: TSQLBuilder;
begin
  SQL := TSQLBuilder.Create;
  try
    SQL.SetDatabaseType(dbMySQL); // ou dbPostgreSQL, dbFirebird, dbSQLite, dbMSSQL
    // ...
  finally
    SQL.Free;
  end;
end;
```

## Exemplo simples real (MySQL localhost)

Base informada:
- servidor: `localhost`
- porta: `3306`
- usuario: `root`
- senha: `admin`
- banco: `chat_database`
- tabela: `usuario` (`id`, `email`, `cpf`, `senha`)

```pascal
uses
  System.SysUtils,
  System.Classes,
  FireDAC.Comp.Client,
  FireDAC.Stan.Def,
  FireDAC.Phys,
  FireDAC.Phys.MySQL,
  FireDAC.Phys.MySQLDef,
  FireDAC.UI.Intf,
  FireDAC.VCLUI.Wait,
  uFluentORM.Attributes,
  uFluentORM.Repository,
  uFluentORM.Executor,
  uFluentORM.Executor.FireDAC,
  uFluentORM.ConnectionPool.FireDAC;

type
  [Table('usuario')]
  TUsuarioDTO = class
  private
    FId: Integer;
    FEmail: string;
    FCpf: string;
    FSenha: string;
  public
    [Key(True)]
    [Column('id')]
    property Id: Integer read FId write FId;

    [Column('email')]
    property Email: string read FEmail write FEmail;

    [Column('cpf')]
    property Cpf: string read FCpf write FCpf;

    [Column('senha')]
    property Senha: string read FSenha write FSenha;
  end;

procedure ExemploPersistenciaMySQL;
var
  Params: TStringList;
  PoolFactory: IFireDACConnectionFactory;
  PoolOptions: TFireDACPoolOptions;
  Repo: TRepository<TUsuarioDTO>;
  Exec: ISQLExecutor;
  Usuario: TUsuarioDTO;
begin
  Params := TStringList.Create;
  try
    Params.Values['DriverID'] := 'MySQL';
    Params.Values['Server'] := 'localhost';
    Params.Values['Port'] := '3306';
    Params.Values['Database'] := 'chat_database';
    Params.Values['User_Name'] := 'root';
    Params.Values['Password'] := 'admin';

    PoolOptions := TFireDACPoolOptions.Default;
    PoolFactory := TFireDACPooledConnectionFactory.Create(Params, PoolOptions);
    Exec := TFireDACSQLExecutor.CreateFromFactory(PoolFactory);
    Repo := TRepository<TUsuarioDTO>.Create(Exec);
    Usuario := TUsuarioDTO.Create;
    try
      // INSERT
      Usuario.Email := 'joao@exemplo.com';
      Usuario.Cpf := '12345678901';
      Usuario.Senha := 'hash_da_senha'; // use hash, nunca senha em texto puro
      Repo.Insert(Usuario);

      // UPDATE
      Usuario.Email := 'joao.novo@exemplo.com';
      Repo.Update(Usuario);

      // DELETE (opcional)
      // Repo.Delete(Usuario);
    finally
      Usuario.Free;
      Repo.Free;
    end;
  finally
    Params.Free;
  end;
end;
```

Observacao:
- `TSQLTransaction.ExecuteInTransaction` aceita `ISQLExecutor`.
- Se o executor tambem implementar `ISQLTransactionalExecutor`, usa transacao real.
- Caso contrario, executa o bloco sem transacao (fallback seguro, sem excecao).
- Os exemplos acima ja usam pool via `TFireDACSQLExecutor.CreateFromFactory(...)`.

Diagnostico opcional:

```pascal
if not TSQLTransaction.HasTransactionSupport(Exec) then
  ShowMessage('Executor atual sem suporte transacional.');
```

### Exemplo simples de UPDATE (tabela `usuario`)

```pascal
procedure ExemploUpdateUsuarioSimples;
var
  Params: TStringList;
  PoolFactory: IFireDACConnectionFactory;
  PoolOptions: TFireDACPoolOptions;
  Repo: TRepository<TUsuarioDTO>;
  Exec: ISQLExecutor;
  Usuario: TUsuarioDTO;
begin
  Params := TStringList.Create;
  try
    Params.Values['DriverID'] := 'MySQL';
    Params.Values['Server'] := 'localhost';
    Params.Values['Port'] := '3306';
    Params.Values['Database'] := 'chat_database';
    Params.Values['User_Name'] := 'root';
    Params.Values['Password'] := 'admin';

    PoolOptions := TFireDACPoolOptions.Default;
    PoolFactory := TFireDACPooledConnectionFactory.Create(Params, PoolOptions);
    Exec := TFireDACSQLExecutor.CreateFromFactory(PoolFactory);
    Repo := TRepository<TUsuarioDTO>.Create(Exec);
    Usuario := TUsuarioDTO.Create;
    try
      Usuario.Id := 1; // id existente
      Usuario.Email := 'novo_email@dominio.com';
      Usuario.Cpf := '12345678901';
      Usuario.Senha := 'novo_hash_de_senha';
      Repo.Update(Usuario);
    finally
      Usuario.Free;
      Repo.Free;
    end;
  finally
    Params.Free;
  end;
end;
```

### Exemplo simples de DELETE (tabela `usuario`)

```pascal
procedure ExemploDeleteUsuarioSimples;
var
  Params: TStringList;
  PoolFactory: IFireDACConnectionFactory;
  PoolOptions: TFireDACPoolOptions;
  Repo: TRepository<TUsuarioDTO>;
  Exec: ISQLExecutor;
begin
  Params := TStringList.Create;
  try
    Params.Values['DriverID'] := 'MySQL';
    Params.Values['Server'] := 'localhost';
    Params.Values['Port'] := '3306';
    Params.Values['Database'] := 'chat_database';
    Params.Values['User_Name'] := 'root';
    Params.Values['Password'] := 'admin';

    PoolOptions := TFireDACPoolOptions.Default;
    PoolFactory := TFireDACPooledConnectionFactory.Create(Params, PoolOptions);
    Exec := TFireDACSQLExecutor.CreateFromFactory(PoolFactory);
    Repo := TRepository<TUsuarioDTO>.Create(Exec);
    try
      Repo.DeleteById(1); // remove usuario com id = 1
    finally
      Repo.Free;
    end;
  finally
    Params.Free;
  end;
end;
```

## 3. Monte a consulta

```pascal
var
  QuerySQL: string;
begin
  QuerySQL := SQL.Select
                 .Fields(['id', 'nome', 'email'])
                 .From('clientes')
                 .Where('ativo', True)
                 .OrderByAsc('nome')
                 .ToSQL;
end;
```

## 4. Gere SQL formatado (indentado)

```pascal
QuerySQL := SQL.Select
               .Fields(['id', 'nome', 'email'])
               .From('clientes')
               .Where('ativo', True)
               .ToFormattedSQL;      // indentacao padrao: 2 espacos

QuerySQL := SQL.Select
               .All
               .From('clientes')
               .ToFormattedSQL(4);   // indentacao customizada
```

## 5. (Opcional) Ative quoting de identificadores

```pascal
SQL.QuoteIdentifiers := True;

// Exemplo de impacto:
// .From('order')                -> FROM "order"         (ou [order] no MSSQL)
// .Where('user.status', 'ATIVO') -> "user"."status" = ...
```

## Exemplos de uso

## Exemplo 1: Consulta simples

```pascal
var
  QuerySQL: string;
begin
  QuerySQL := SQL.Select
                 .Fields(['id', 'nome', 'email'])
                 .From('pessoas')
                 .Where('ativo', True)
                 .OrderByDesc('nome')
                 .ToSQL;
end;
```

## Exemplo 2: Filtros compostos

```pascal
var
  QuerySQL: string;
begin
  QuerySQL := SQL.Select
                 .All
                 .From('clientes')
                 .Where('cidade', 'Sao Paulo')
                 .AndWhere('idade', 18, opGreaterOrEqual)
                 .OrWhere('uf', 'SP')
                 .Limit(100)
                 .ToSQL;
end;
```

## Exemplo 3: JOIN + GROUP BY + HAVING

```pascal
var
  QuerySQL: string;
  DataInicio, DataFim: TDate;
begin
  DataInicio := EncodeDate(2024, 1, 1);
  DataFim := EncodeDate(2024, 12, 31);

  QuerySQL := SQL.Select
                 .Fields([
                   'v.id as vendedor_id',
                   'v.nome as vendedor',
                   'c.id as cliente_id',
                   'c.nome as cliente',
                   'SUM(iv.quantidade * iv.preco_unitario) as valor_total'
                 ])
                 .From('vendedores v')
                 .Join('pedidos pe', 'pe.vendedor_id = v.id')
                 .Join('clientes c', 'c.id = pe.cliente_id')
                 .Join('itens_venda iv', 'iv.pedido_id = pe.id')
                 .Where('pe.data_pedido', DataInicio, opGreaterOrEqual)
                 .AndWhere('pe.data_pedido', DataFim, opLessOrEqual)
                 .AndWhere('pe.status', 'CONCLUIDO')
                 .GroupBy(['v.id', 'v.nome', 'c.id', 'c.nome'])
                 .Having('valor_total', 1000, opGreaterOrEqual)
                 .OrderByDesc('valor_total')
                 .ToFormattedSQL;
end;
```

## Exemplo 4: Paginacao

```pascal
var
  QuerySQL: string;
begin
  QuerySQL := SQL.Select
                 .All
                 .From('produtos')
                 .Where('categoria_id', 5)
                 .OrderByAsc('nome')
                 .Paginate(2, 20) // pagina 2, 20 itens por pagina
                 .ToSQL;
end;
```

## Exemplo 5: SQL de contagem

```pascal
var
  CountSQL: string;
begin
  CountSQL := SQL.Select
                 .From('clientes')
                 .Where('ativo', True)
                 .ToFormattedSQLCount;
end;
```

## Exemplo 6: StrictMode e observabilidade  (GRUPO 1)

```pascal
procedure TForm1.SQLGenerated(Sender: TObject; const ASQL: string);
begin
  Memo1.Lines.Add(ASQL); // log simples
end;

var
  QuerySQL: string;
begin
  SQL.StrictMode := True;          // bloqueia WhereRaw/AndWhereRaw/OrWhereRaw/HavingRaw
  SQL.OnSQLGenerated := SQLGenerated;

  QuerySQL := SQL.Select
                 .All
                 .From('clientes')
                 .Where('deleted_at', Null) // gera: deleted_at IS NULL
                 .ToSQL;
end;
```

## Exemplo 7: SQL parametrizado (GRUPO 2)

```pascal
var
  QuerySQL: string;
  ParamName: string;
begin
  SQL.UseNamedParams := True;

  QuerySQL := SQL.Select
                 .All
                 .From('clientes')
                 .Where('cidade', 'Sao Paulo')
                 .AndWhere('idade', 18, opGreaterOrEqual)
                 .AndWhere('ativo', True)
                 .ToSQL;

  // Exemplo de SQL gerado (PostgreSQL/MySQL/SQLite/Firebird):
  // SELECT * FROM clientes WHERE cidade = :cidade AND idade >= :idade AND ativo = :ativo;
  //
  // Exemplo de SQL gerado (MSSQL):
  // SELECT * FROM clientes WHERE cidade = :cidade AND idade >= :idade AND ativo = :ativo;
  //
  // Todos os bancos usam ":" por padrao: FireDAC, Zeos, UniDAC, dbExpress e
  // ADO reconhecem ":" como marcador de parametro em qualquer driver. Para
  // emitir o marcador nativo do SQL Server, use SQL.ParamPrefix := '@'.

  for ParamName in SQL.GetParameters do
  begin
    // Envie nome + valor para o componente de acesso (FireDAC, etc.)
    Memo1.Lines.Add(ParamName + ' = ' + VarToStr(SQL.GetParamValue(ParamName)));
  end;
end;
```

## Exemplo 8: IN/NOT IN (GRUPO 3)

```pascal
var
  QuerySQL: string;
begin
  SQL.UseNamedParams := True;
  SQL.StrictMode := True;

  QuerySQL := SQL.Select
                 .All
                 .From('pedidos')
                 .WhereIn('status', ['ABERTO', 'PAGO', 'ENVIADO'])
                 .AndWhereNotNull('cliente_id')
                 .ToSQL;

  // Exemplo (PostgreSQL/SQLite/Firebird):
  // SELECT * FROM pedidos
  // WHERE status IN (:status_in, :status_in1, :status_in2)
  //   AND cliente_id IS NOT NULL;
end;
```

## Exemplo 9: Between sem Raw no StrictMode (GRUPO 3)

```pascal
var
  QuerySQL: string;
  DataInicio, DataFim: TDate;
begin
  DataInicio := EncodeDate(2025, 1, 1);
  DataFim := EncodeDate(2025, 12, 31);

  SQL.StrictMode := True;
  SQL.UseNamedParams := True;

  QuerySQL := SQL.Select
                 .Fields(['id', 'data_pedido', 'valor_total'])
                 .From('pedidos')
                 .WhereBetween('data_pedido', DataInicio, DataFim)
                 .AndWhereBetween('valor_total', 100, 1000)
                 .ToFormattedSQL;
end;
```

## Exemplo 10: QuoteIdentifiers (GRUPO 4)

```pascal
var
  QuerySQL: string;
begin
  SQL.SetDatabaseType(dbPostgreSQL);
  SQL.QuoteIdentifiers := True;
  SQL.UseNamedParams := True;

  QuerySQL := SQL.Select
                 .Fields(['id', 'status'])
                 .From('order')
                 .Where('user.status', 'ACTIVE')
                 .ToSQL;

  // Exemplo de SQL gerado:
  // SELECT id, status FROM "order" WHERE "user"."status" = :user_status;
end;
```

## Exemplo 11: QuoteIdentifiers em SELECT e alias (GRUPO 5)

```pascal
var
  QuerySQL: string;
begin
  SQL.SetDatabaseType(dbPostgreSQL);
  SQL.QuoteIdentifiers := True;

  QuerySQL := SQL.Select
                 .Fields('id, user.status AS status_usuario')
                 .From('order')
                 .ToSQL;

  // Exemplo de SQL gerado:
  // SELECT "id", "user"."status" AS "status_usuario" FROM "order";
end;
```

## Exemplo 12: FromSQL com alias quoted (GRUPO 5)

```pascal
var
  QuerySQL: string;
begin
  SQL.SetDatabaseType(dbMSSQL);
  SQL.QuoteIdentifiers := True;

  QuerySQL := SQL.Select
                 .Fields(['sub.id', 'sub.total'])
                 .FromSQL('SELECT id, total FROM vendas', 'sub')
                 .Where('sub.total', 1000, opGreaterOrEqual)
                 .ToSQL;

  // Exemplo de SQL gerado:
  // SELECT [sub].[id], [sub].[total]
  // FROM (SELECT id, total FROM vendas) [sub]
  // WHERE [sub].[total] >= 1000;
end;
```

## Exemplo 13: HAVING com AND/OR (GRUPO 6)

```pascal
var
  QuerySQL: string;
begin
  SQL.UseNamedParams := True;
  SQL.StrictMode := True;

  QuerySQL := SQL.Select
                 .Fields([
                   'vendedor_id',
                   'SUM(valor_total) AS total_vendas',
                   'COUNT(*) AS qtd_pedidos'
                 ])
                 .From('pedidos_resumo')
                 .GroupBy('vendedor_id')
                 .Having('SUM(valor_total)', 5000, opGreaterOrEqual)
                 .AndHaving('COUNT(*)', 10, opGreaterOrEqual)
                 .OrHaving('MAX(valor_total)', 2000, opGreaterOrEqual)
                 .ToFormattedSQL;
end;
```

## Exemplo 14: HAVING Raw com OR (GRUPO 6)

```pascal
var
  QuerySQL: string;
begin
  SQL.StrictMode := False; // necessario para metodos Raw

  QuerySQL := SQL.Select
                 .Fields(['categoria', 'SUM(valor) AS total'])
                 .From('vendas')
                 .GroupBy('categoria')
                 .HavingRaw('SUM(valor) > 1000')
                 .OrHavingRaw('AVG(valor) > 200')
                 .ToSQL;
end;
```

## Exemplo 15: Grupo logico em WHERE (GRUPO 7)

```pascal
var
  QuerySQL: string;
begin
  SQL.UseNamedParams := True;
  SQL.StrictMode := True;

  QuerySQL := SQL.Select
                 .All
                 .From('clientes')
                 .BeginWhereGroup
                   .Where('cidade', 'Sao Paulo')
                   .OrWhere('cidade', 'Rio de Janeiro')
                 .EndWhereGroup
                 .AndWhere('ativo', True)
                 .ToFormattedSQL;

  // Resultado esperado:
  // WHERE (cidade = :cidade OR cidade = :cidade1) AND ativo = :ativo
end;
```

## Exemplo 16: Grupo logico em HAVING (GRUPO 7)

```pascal
var
  QuerySQL: string;
begin
  SQL.UseNamedParams := True;
  SQL.StrictMode := True;

  QuerySQL := SQL.Select
                 .Fields(['categoria', 'SUM(valor) AS total', 'COUNT(*) AS qtd'])
                 .From('vendas')
                 .GroupBy('categoria')
                 .BeginHavingGroup
                   .Having('SUM(valor)', 1000, opGreaterOrEqual)
                   .AndHaving('COUNT(*)', 5, opGreaterOrEqual)
                 .EndHavingGroup
                 .OrHaving('MAX(valor)', 500, opGreaterOrEqual)
                 .ToFormattedSQL;
end;
```

## Exemplo completo: precedencia de AND/OR no WHERE 

Quando misturamos `AND` e `OR`, a precedencia SQL pode gerar resultado diferente do esperado.
Para evitar ambiguidades, use grupos explicitos com `BeginWhereGroup/EndWhereGroup`.

### Cenario 1: `(cidade AND idade AND idcidade) OR uf`

Objetivo:
- retornar registros que atendam todos os filtros principais
- ou que tenham `uf = 'SP'`

```pascal
var
  QuerySQL: string;
begin
  QuerySQL := SQL.Select
                 .All
                 .From('clientes')
                 .BeginWhereGroup
                   .Where('cidade', 'Sao Paulo')
                   .AndWhere('idade', 18, opGreaterOrEqual)
                   .AndWhere('idcidade', 1, opGreaterOrEqual)
                 .EndWhereGroup
                 .OrWhere('uf', 'SP')
                 .ToFormattedSQL;
end;
```

SQL esperado:

```sql
WHERE (cidade = 'Sao Paulo' AND idade >= 18 AND idcidade >= 1)
  OR uf = 'SP'
```

### Cenario 2: `cidade AND (idade OR uf)`

Objetivo:
- sempre exigir `cidade = 'Sao Paulo'`
- e aceitar (`idade >= 18` ou `uf = 'SP'`)

```pascal
var
  QuerySQL: string;
begin
  QuerySQL := SQL.Select
                 .All
                 .From('clientes')
                 .Where('cidade', 'Sao Paulo')
                 .AndBeginWhereGroup
                   .Where('idade', 18, opGreaterOrEqual)
                   .OrWhere('uf', 'SP')
                 .EndWhereGroup
                 .ToFormattedSQL;
end;
```

SQL esperado:

```sql
WHERE cidade = 'Sao Paulo'
  AND (idade >= 18 OR uf = 'SP')
```

Boas praticas:
- sempre use grupos quando houver mistura de `AND` e `OR`;
- evite depender apenas da precedencia padrao do SQL;
- prefira `ToFormattedSQL` para validar visualmente a expressao final.

## Exemplo 17: EXISTS/NOT EXISTS (GRUPO 8)

```pascal
var
  QuerySQL: string;
begin
  SQL.StrictMode := True;
  SQL.UseNamedParams := True;

  QuerySQL := SQL.Select
                 .Fields(['c.id', 'c.nome'])
                 .From('clientes c')
                 .WhereExists(
                   'SELECT 1 FROM pedidos p WHERE p.cliente_id = c.id AND p.status = ''ABERTO'''
                 )
                 .AndWhereNotExists(
                   'SELECT 1 FROM bloqueios b WHERE b.cliente_id = c.id'
                 )
                 .ToFormattedSQL;
end;
```

## Exemplo 18: EXISTS combinado com grupos logicos (GRUPO 8)

```pascal
var
  QuerySQL: string;
begin
  SQL.StrictMode := True;

  QuerySQL := SQL.Select
                 .All
                 .From('clientes c')
                 .BeginWhereGroup
                   .WhereExists('SELECT 1 FROM pedidos p WHERE p.cliente_id = c.id')
                   .OrWhereExists('SELECT 1 FROM orcamentos o WHERE o.cliente_id = c.id')
                 .EndWhereGroup
                 .AndWhere('c.ativo', True)
                 .ToSQL;
end;
```

## Exemplo 19: HAVING EXISTS/NOT EXISTS (GRUPO 9)

```pascal
var
  QuerySQL: string;
begin
  SQL.StrictMode := True;

  QuerySQL := SQL.Select
                 .Fields(['c.id', 'SUM(v.valor) AS total'])
                 .From('clientes c')
                 .Join('vendas v', 'v.cliente_id = c.id')
                 .GroupBy('c.id')
                 .Having('SUM(v.valor)', 1000, opGreaterOrEqual)
                 .AndHavingExists(
                   'SELECT 1 FROM metas m WHERE m.cliente_id = c.id AND m.ativa = 1'
                 )
                 .ToFormattedSQL;
end;
```

## Exemplo 20: HAVING EXISTS com grupos logicos (GRUPO 9)

```pascal
var
  QuerySQL: string;
begin
  SQL.StrictMode := True;

  QuerySQL := SQL.Select
                 .Fields(['categoria', 'SUM(valor) AS total'])
                 .From('vendas')
                 .GroupBy('categoria')
                 .BeginHavingGroup
                   .HavingExists('SELECT 1 FROM metas_categoria m WHERE m.categoria = vendas.categoria')
                   .OrHavingNotExists('SELECT 1 FROM bloqueios_categoria b WHERE b.categoria = vendas.categoria')
                 .EndHavingGroup
                 .AndHaving('SUM(valor)', 5000, opGreaterOrEqual)
                 .ToSQL;
end;
```

## Exemplo 21: UNION e UNION ALL com SQL literal (GRUPO 10)

```pascal
var
  QuerySQL: string;
begin
  SQL.StrictMode := False; // necessario para UNION com string literal

  QuerySQL := SQL.Select
                 .Fields(['id', 'nome'])
                 .From('clientes_ativos')
                 .Union('SELECT id, nome FROM clientes_potenciais')
                 .UnionAll('SELECT id, nome FROM clientes_importados')
                 .OrderByAsc('nome')
                 .ToFormattedSQL;
end;
```

## Exemplo 22: UNION com outro builder e parametros (GRUPO 10)

```pascal
var
  SQL1, SQL2: TSQLBuilder;
  QuerySQL: string;
  P: string;
begin
  SQL1 := TSQLBuilder.Create;
  SQL2 := TSQLBuilder.Create;
  try
    SQL1.SetDatabaseType(dbPostgreSQL);
    SQL2.SetDatabaseType(dbPostgreSQL);
    SQL1.UseNamedParams := True;
    SQL2.UseNamedParams := True;

    SQL1.Select
        .Fields(['id', 'nome'])
        .From('clientes')
        .Where('ativo', True);

    SQL2.Select
        .Fields(['id', 'nome'])
        .From('fornecedores')
        .Where('ativo', True);

    QuerySQL := SQL1
      .UnionAll(SQL2)
      .ToSQL;

    for P in SQL1.GetParameters do
      Memo1.Lines.Add(P + ' = ' + VarToStr(SQL1.GetParamValue(P)));
  finally
    SQL1.Free;
    SQL2.Free;
  end;
end;
```

## Exemplo 23: INTERSECT (GRUPO 11)

```pascal
var
  QuerySQL: string;
begin
  SQL.StrictMode := False; // necessario para operacao com SQL literal

  QuerySQL := SQL.Select
                 .Fields(['id', 'nome'])
                 .From('clientes_ativos')
                 .Intersect('SELECT id, nome FROM clientes_compras_recentes')
                 .ToFormattedSQL;
end;
```

## Exemplo 24: EXCEPT com outro builder (GRUPO 11)

```pascal
var
  SQLBase, SQLRemover: TSQLBuilder;
  QuerySQL: string;
begin
  SQLBase := TSQLBuilder.Create;
  SQLRemover := TSQLBuilder.Create;
  try
    SQLBase.SetDatabaseType(dbPostgreSQL);
    SQLRemover.SetDatabaseType(dbPostgreSQL);
    SQLBase.UseNamedParams := True;
    SQLRemover.UseNamedParams := True;

    SQLBase.Select
      .Fields(['id', 'nome'])
      .From('clientes')
      .Where('ativo', True);

    SQLRemover.Select
      .Fields(['id', 'nome'])
      .From('clientes_bloqueados')
      .Where('ativo', True);

    QuerySQL := SQLBase
      .&Except(SQLRemover)
      .ToSQL;
  finally
    SQLBase.Free;
    SQLRemover.Free;
  end;
end;
```

## Exemplo 25: WITH CTE (GRUPO 12)

```pascal
var
  QuerySQL: string;
begin
  SQL.StrictMode := False; // necessario para CTE por SQL literal

  QuerySQL := SQL.Select
    .WithCTE('clientes_ativos',
      'SELECT id, nome, cidade FROM clientes WHERE ativo = 1')
    .Fields(['id', 'nome', 'cidade'])
    .From('clientes_ativos')
    .Where('cidade', 'Sao Paulo')
    .ToFormattedSQL;
end;
```

## Exemplo 26: WITH CTE com outro builder e parametros (GRUPO 12)

```pascal
var
  CTEBuilder, MainBuilder: TSQLBuilder;
  QuerySQL: string;
begin
  CTEBuilder := TSQLBuilder.Create;
  MainBuilder := TSQLBuilder.Create;
  try
    CTEBuilder.SetDatabaseType(dbPostgreSQL);
    MainBuilder.SetDatabaseType(dbPostgreSQL);
    CTEBuilder.UseNamedParams := True;
    MainBuilder.UseNamedParams := True;

    CTEBuilder.Select
      .Fields(['cliente_id', 'SUM(valor) AS total'])
      .From('vendas')
      .GroupBy('cliente_id')
      .Having('SUM(valor)', 1000, opGreaterOrEqual);

    QuerySQL := MainBuilder.Select
      .WithCTE('vendas_agg', CTEBuilder)
      .Fields(['c.id', 'c.nome', 'v.total'])
      .From('clientes c')
      .Join('vendas_agg v', 'v.cliente_id = c.id')
      .ToSQL;
  finally
    CTEBuilder.Free;
    MainBuilder.Free;
  end;
end;
```

## Exemplo 27: WITH RECURSIVE (GRUPO 12)

```pascal
var
  QuerySQL: string;
begin
  SQL.StrictMode := False;

  QuerySQL := SQL.Select
    .WithRecursiveCTE('hierarquia',
      'SELECT id, pai_id, nome, 1 AS nivel FROM categorias WHERE pai_id IS NULL ' +
      'UNION ALL ' +
      'SELECT c.id, c.pai_id, c.nome, h.nivel + 1 ' +
      'FROM categorias c JOIN hierarquia h ON c.pai_id = h.id')
    .Fields(['id', 'pai_id', 'nome', 'nivel'])
    .From('hierarquia')
    .OrderByAsc('nivel')
    .ToSQL;
end;
```

## Boas praticas

- Sempre use `SQL.Clear` entre consultas diferentes na mesma instancia.
- Prefira passar operador separado do campo.
- Correto: `.Where('data_pedido', DataInicio, opGreaterOrEqual)`
- Evite: `.Where('data_pedido >=', DataInicio)`
- Use `ToFormattedSQL` para logs e depuracao.

## Observacoes

- O builder retorna SQL em string. Os parametros da ultima geracao saem em `ToSQLParams` (formato do `ISQLExecutor`) ou em `GetParameters`/`GetParamValue` para outras camadas (dbExpress, Zeos, UniDAC...).
- Datas e booleanos sao formatados conforme `TSQLDatabaseType`.
- Em `StrictMode`, metodos raw geram excecao para evitar SQL livre acidental.
- Com `UseNamedParams = True`, valores de `WHERE/HAVING/BETWEEN` sao emitidos como placeholders e expostos por `GetParameters`/`GetParamValue`.
- `Limit` exige valor > 0, `Offset` exige >= 0 e `Paginate` exige `Page >= 1` e `PageSize > 0`.
- `WhereIn` e `WhereNotIn` agora usam estrutura interna (sem `Raw`) e funcionam em `StrictMode`.
- Com `QuoteIdentifiers = True`, apenas identificadores simples (ex.: `campo`, `tabela.campo`) sao quoted automaticamente.
- Expressoes SQL avancadas (com espacos, funcoes, aliases, operadores) nao sao alteradas para evitar quebrar consultas customizadas.
- A partir do GRUPO 5, `Fields/Field` e aliases simples tambem passam por quoting quando `QuoteIdentifiers=True`.
- A partir do GRUPO 6, `HAVING` permite combinacoes com `AND/OR` sem precisar concatenar SQL manualmente.
- A partir do GRUPO 7, `Begin...Group/End...Group` permitem parenteses em `WHERE/HAVING` sem usar metodos raw.
- A partir do GRUPO 8, `WhereExists/WhereNotExists` e variantes `And/Or` evitam SQL raw manual para subconsultas comuns.
- A partir do GRUPO 9, o mesmo padrao `Exists/NotExists` tambem esta disponivel no `HAVING`.
- A partir do GRUPO 10, `Union/UnionAll` permitem compor consultas maiores sem sair da API fluente.
- A partir do GRUPO 11, `Intersect/Except` cobrem os operadores de conjunto mais usados em SQL relacional.
- A partir do GRUPO 12, `WithCTE/WithRecursiveCTE` permitem estruturar consultas complexas mantendo composicao fluente.
- Dica de uso: inicie com `Select` e depois aplique `WithCTE/WithRecursiveCTE` na mesma cadeia.
- Para `Insert` com chave auto-gerada: PostgreSQL usa `INSERT ... RETURNING <pk>`; SQL Server usa `INSERT ... OUTPUT INSERTED.<pk> INTO @fluent_ids` (funciona em tabelas com trigger); MySQL usa `LAST_INSERT_ID()` via executor. O valor gerado e atribuido a propriedade `[Key]` quando o banco devolve a chave.
- `TRepository<T>.QuoteIdentifiers` vem `True` por padrao (veja "Quoting no repositorio" para as regras de PostgreSQL/Firebird).
- Seguranca adicional: `WhereNotBetween` nao usa mais caminho raw interno (suporta parametros nomeados).
- Em `StrictMode`, `FromSQL` e `OrderByRaw` tambem sao bloqueados.
- Em `StrictMode`, `OrderBy('campo, outro DESC')` continua permitido para identificadores simples.

## Compatibilidade SQL por banco

As regras abaixo foram aplicadas para gerar SQL compativel com:
- `dbMySQL`
- `dbPostgreSQL`
- `dbFirebird`
- `dbSQLite`
- `dbMSSQL`

Regras de geracao:
- Parametros: `:nome` em todos os bancos (FireDAC, Zeos, UniDAC, dbExpress e ADO reconhecem `:`); use `ParamPrefix` para trocar o marcador.
- Identificadores (`QuoteIdentifiers = True`):
  - `dbMSSQL`: `[tabela].[coluna]`
  - `dbMySQL`: `` `tabela`.`coluna` ``
  - `dbPostgreSQL`, `dbFirebird`, `dbSQLite`: `"tabela"."coluna"`
  - apenas identificadores simples (incluindo `schema.tabela`) sao quoted; expressoes e aliases com espacos ficam intactos.
- Datas:
  - `dbMSSQL`: ISO basico `'yyyymmdd'` (sem hora) ou `'yyyy-mm-ddThh:nn:ss.zzz'` (com hora), independente de `SET DATEFORMAT`/`SET LANGUAGE`.
  - demais: `'yyyy-mm-dd'` e `'yyyy-mm-dd hh:nn:ss'`.
- Boolean:
  - `dbPostgreSQL`: `TRUE`/`FALSE`
  - `dbMySQL`, `dbFirebird`, `dbSQLite`, `dbMSSQL`: `1`/`0`
- Strings:
  - aspas simples duplicadas (`'O''Brien'`);
  - `dbMSSQL`: prefixo `N'...'` para preservar Unicode;
  - `dbMySQL`: `\` duplicado para nao quebrar literais.
- Numeros decimais: separador `.` (invariante de locale).
- Paginacao:
  - `dbMySQL` e `dbSQLite`: `LIMIT ... OFFSET ...` (`LIMIT 18446744073709551615` / `LIMIT -1` quando ha apenas offset);
  - `dbPostgreSQL`: `LIMIT ... OFFSET ...`;
  - `dbFirebird`: `ROWS ...` / `ROWS ... TO ...`;
  - `dbMSSQL`: `OFFSET ... ROWS FETCH NEXT ... ROWS ONLY`.
- No MSSQL, quando ha paginacao sem ordenacao explicita, o builder injeta `ORDER BY (SELECT NULL)`; em consultas com `UNION` usa `ORDER BY 1` (o SQL Server nao aceita `(SELECT NULL)` nesse caso).
- `FULL JOIN` nao existe no MySQL: o builder lanca excecao e sugere `LEFT/RIGHT JOIN` + `UNION`.
- `INTERSECT`/`EXCEPT` exigem MySQL 8.0.31+; CTE (`WITH`) exige MySQL 8.0+ e SQL Server 2005+.
- `LIKE` diferencia maiusculas/minusculas no PostgreSQL; no MySQL e no SQL Server depende da collation da coluna.
- CTE recursiva: `WITH RECURSIVE` nos bancos que suportam; no SQL Server apenas `WITH`.
- `ToSQLCount`: consultas com `DISTINCT`, `GROUP BY` ou operacoes de conjunto sao envolvidas em `SELECT COUNT(*) FROM (...) fluent_count`.

### Identidade (chave auto-gerada) no `TRepository<T>`

| Banco | Estrategia | Retorno de `Insert` |
|-------|------------|---------------------|
| SQL Server (`dbMSSQL`) | `SET NOCOUNT ON; DECLARE @fluent_ids TABLE(id <tipo>); INSERT ... OUTPUT INSERTED.<pk> INTO @fluent_ids ...; SELECT TOP 1 id FROM @fluent_ids` | `1` |
| PostgreSQL (`dbPostgreSQL`) | `INSERT ... RETURNING <pk>` | `1` |
| MySQL (`dbMySQL`) | `INSERT` + `SELECT LAST_INSERT_ID()` | linhas afetadas |
| SQLite / Firebird / outros | funcao do executor (`last_insert_rowid`/fallback) | linhas afetadas |

O valor gerado e atribuido automaticamente a propriedade `[Key]` quando o banco/executor devolve a chave.

No SQL Server, `OUTPUT INSERTED.x` sem `INTO` falha em tabelas com trigger (erro 334), e `SCOPE_IDENTITY()` executado em outro comando devolve `NULL`. Por isso o insert e enviado num unico batch com `OUTPUT ... INTO` uma variavel de tabela, o que tambem cobre chaves `UNIQUEIDENTIFIER` com `DEFAULT NEWID()`.

### Tipos suportados no `TRepository<T>`

Cada parametro e enviado com o `TFieldType` correspondente ao tipo da propriedade (campo `TSQLParam.DataType`), o que evita conversoes implicitas erradas e o erro do FireDAC "data type is unknown" em valores `NULL`.

| Propriedade Delphi | Parametro | MySQL | SQL Server | PostgreSQL |
|--------------------|-----------|-------|------------|------------|
| `Integer`, `SmallInt`, `Byte`... | `ftInteger` | int | int | integer |
| `Int64`, `Cardinal` | `ftLargeint` | bigint | bigint | bigint |
| `Boolean` | `ftBoolean` | tinyint(1) | bit | boolean |
| `Double`, `Single` | `ftFloat` | double | float | double precision |
| `Currency` | `ftBCD` | decimal | decimal | numeric |
| `TDateTime` / `TDate` / `TTime` | `ftDateTime` / `ftDate` / `ftTime` | datetime/date/time | datetime2/date/time | timestamp/date/time |
| `string` | `ftWideString` (`ftWideMemo` acima de 4000 caracteres) | varchar/text | nvarchar | varchar/text |
| `TGUID` | `ftWideString` sem chaves (CHAR(36)) | char(36) | uniqueidentifier (`ftGuid`) | uuid (`ftGuid`) |
| `TBytes` | `ftBlob` | blob | varbinary(max) | bytea |
| `Variant` | inferido (NULL vira `ftWideString`) | qualquer | qualquer | qualquer |

O tipo e decidido pelo tipo *declarado* da propriedade (nao por `TValue.IsType`, que aceita tipos conversiveis e confundiria `Double` com `TDateTime`).

### Usando UniDAC

O ORM nao depende do FireDAC: tudo passa pela interface `ISQLExecutor`. Com o UniDAC instalado, inclua `uFluentORM.Executor.UniDAC.pas` no projeto e o provider de cada banco usado:

```pascal
uses
  Uni, MySQLUniProvider, SQLServerUniProvider, PostgreSQLUniProvider, // providers usados
  uFluentORM.Executor, uFluentORM.Executor.UniDAC, uFluentORM.Repository;

var
  Exec: ISQLExecutor;
  Repo: TRepository<TClienteDTO>;
begin
  // Conexao propria (MySQL em modo Direct: nao precisa de libmysql.dll)
  Exec := TUniDACSQLExecutor.CreateConnected('MySQL', 'localhost', 3306,
    'fluentorm_demo', 'usuario', 'senha');

  // ...ou uma TUniConnection que ja existe no seu data module:
  // Exec := TUniDACSQLExecutor.Create(UniConnection1);

  Repo := TRepository<TClienteDTO>.Create(Exec);
  try
    Cliente := Repo.FindById(1);
    // Insert/Update/Delete/Count/FindAll e TSQLTransaction funcionam igual.
  finally
    Repo.Free;
  end;
end;
```

O dialeto e deduzido de `TUniConnection.ProviderName` (`MySQL`, `SQL Server`, `PostgreSQL`, `InterBase`, `SQLite`); use `TUniDACSQLExecutor.Create(Conn, dbMSSQL)` para informa-lo explicitamente. `OpenQuery`/`OpenDataSet` leem consultas do builder (`Exec.OpenQuery(Builder.ToSQL, Builder.ToSQLParams)`).

> Esta unit foi escrita sem o UniDAC instalado e ainda nao foi compilada. Ao instalar o UniDAC, compile um projeto que a use e valide principalmente o insert no SQL Server (batch com `DECLARE @fluent_ids`).

### Leitura de entidades

```pascal
Cliente := Repo.FindById(10);          // nil se nao existir; quem chama libera
Lista := Repo.FindAll('nome');         // TObjectList<T> dona dos objetos
Repo.LoadFromDataSet(Cliente, Query);  // preenche a partir da linha atual de um TDataSet
```

Requer um executor que implemente `ISQLQueryExecutor` (`TFireDACSQLExecutor` e `TADOSQLExecutor` ja implementam). A entidade e criada pelo construtor sem parametros do DTO, entao valores padrao definidos nele sao respeitados. Colunas `[ReadOnly]` sao lidas normalmente.

### Leitura com o SQL Builder

```pascal
SQLText := Builder.ToSQL;                                   // gera SQL e parametros
Q := Exec.OpenQuery(SQLText, Builder.ToSQLParams);          // TFireDACSQLExecutor; quem chama libera Q
Total := Exec.ExecuteScalar(Builder.ToSQLCount, Builder.ToSQLParams);
```

### Quoting no repositorio

`TRepository<T>.QuoteIdentifiers` vem `True` por padrao, para que nomes reservados (`user`, `order`...) funcionem. Regras:

- MySQL usa crase e SQL Server usa colchetes. Nesses bancos o quoting nao muda a forma como maiusculas/minusculas sao tratadas.
- PostgreSQL so recebe aspas quando o nome esta todo em minusculas. Um nome sem aspas e convertido para minusculas pelo banco, entao `[Table('Usuario')]` continua encontrando a tabela `usuario`, como antes.
- Firebird segue a mesma regra, mas com maiusculas.
- Se o atributo ja vier com aspas (`[Table('"MinhaTabela"')]`, `` [Column('`x`')] ``, `[Column('[x]')]`), o nome e mantido como esta.
- `Repo.QuoteIdentifiers := False` gera os nomes exatamente como escritos nos atributos.

## Testes automatizados

O projeto inclui testes de console que nao dependem de servidor:

- `Tests/FluentORM.Tests.dpr`: valida o SQL gerado para MSSQL, PostgreSQL e MySQL (quoting, parametros, literais, paginacao, `ToSQLCount`, `UNION`, CTE, restricoes) e, atraves de um executor fake, o CRUD do `TRepository<T>`: estrategia de chave gerada por banco, tipos dos parametros (`Double` nao vira data, `Currency` -> `ftBCD`, `TGUID`, `TBytes`, `Variant` nulo) e regras de quoting no PostgreSQL.
- `Tests/FluentORM.MSSQLSmoke.dpr`: gera `Tests/Generated/mssql_smoke.sql` a partir do proprio builder/repositorio, para validar a sintaxe no SQL Server (a tabela de teste tem trigger, para provar o insert com `OUTPUT ... INTO`).

Forma mais simples: rode `build.bat` na raiz (padrao Win64, ou `build.bat Win32`). Ele localiza o Delphi (13, 12 ou 11), compila testes, gerador e exemplos em `Build\<plataforma>`, executa os testes e grava tudo em `build.log`, terminando com `RESULTADO: OK` ou `RESULTADO: FALHOU`.

Compilacao manual dos testes (Win32):

```bat
set OUT=%TEMP%\fluentorm
mkdir %OUT%
dcc32 -B -Q -N0"%OUT%" -E"%OUT%" ^
  -U"C:\Program Files (x86)\Embarcadero\Studio\37.0\lib\Win32\release" ^
  -U"." Tests\FluentORM.Tests.dpr
"%OUT%\FluentORM.Tests.exe"
```

Saida esperada: `0 failures`.

Validacao opcional no SQL Server local:

```bat
Tests\FluentORM.MSSQLSmoke.exe Tests\Generated\mssql_smoke.sql
sqlcmd -S localhost -E -C -b -d tempdb -i Tests\Generated\mssql_smoke.sql
```

MySQL e PostgreSQL nao precisam de servidor para os testes: o texto SQL e a estrategia de identidade de cada dialeto sao verificados diretamente.


# ORM minimo (DTO + RTTI)

### 1. Defina seu DTO

```pascal
uses
  uFluentORM.Attributes;

type
  [Table('clientes')]
  TClienteDTO = class
  private
    FId: Integer;
    FNome: string;
    FAtivo: Boolean;
  public
    [Key(True)]
    [Column('id')]
    property Id: Integer read FId write FId;

    [Column('nome')]
    property Nome: string read FNome write FNome;

    [Column('ativo')]
    property Ativo: Boolean read FAtivo write FAtivo;
  end;
```

### 2. Escolha o executor

Para FireDAC use o pronto `TFireDACSQLExecutor` (veja os itens 4 e 5). Para outra camada de acesso, implemente `ISQLExecutor`;
implementar tambem `ISQLDialectInfo` (ou `ISQLDriverInfo`) informa o banco ao repositorio, e `ISQLIdentityExecutor` permite devolver a chave gerada no MySQL.
Use `TSQLParam.DataType` (quando diferente de `ftUnknown`) para tipar cada parametro.

```pascal
type
  TMeuExecutor = class(TInterfacedObject, ISQLExecutor)
  public
    function Execute(const ASQL: string; const AParams: TSQLParams): Integer;
    function ExecuteScalar(const ASQL: string; const AParams: TSQLParams): Variant;
  end;
```

### 3. Use `TRepository<T>`

```pascal
uses
  uFluentORM.Repository, uFluentORM.Executor;

var
  Repo: TRepository<TClienteDTO>;
  Cliente: TClienteDTO;
begin
  Repo := TRepository<TClienteDTO>.Create(TMeuExecutor.Create);
  Cliente := TClienteDTO.Create;
  try
    Cliente.Nome := 'Maria';
    Cliente.Ativo := True;
    Repo.Insert(Cliente);

    Cliente.Ativo := False;
    Repo.Update(Cliente);

    Repo.Delete(Cliente);
  finally
    Cliente.Free;
    Repo.Free;
  end;
end;
```

### 4. Transacao explicita (FireDAC)

`TFireDACSQLExecutor` implementa `ISQLTransactionalExecutor`, entao voce pode executar multiplas operacoes no mesmo commit/rollback:

Observacao de seguranca:
- quando o executor e criado via `CreateFromFactory` (pool), ele e dono da conexao;
- no `Destroy`, se houver transacao aberta, faz `Rollback` automatico, fecha a conexao e libera o objeto.

```pascal
uses
  System.Classes,
  uFluentORM.Executor,
  uFluentORM.Executor.FireDAC,
  uFluentORM.ConnectionPool.FireDAC;

procedure ExemploTransacao;
var
  Params: TStringList;
  PoolFactory: IFireDACConnectionFactory;
  PoolOptions: TFireDACPoolOptions;
  Exec: ISQLExecutor;
  Repo: TRepository<TUsuarioDTO>;
  U1, U2: TUsuarioDTO;
begin
  Params := TStringList.Create;
  try
    Params.Values['DriverID'] := 'MySQL';
    Params.Values['Server'] := 'localhost';
    Params.Values['Port'] := '3306';
    Params.Values['Database'] := 'chat_database';
    Params.Values['User_Name'] := 'root';
    Params.Values['Password'] := 'root';

    PoolOptions := TFireDACPoolOptions.Default;
    PoolFactory := TFireDACPooledConnectionFactory.Create(Params, PoolOptions);
    Exec := TFireDACSQLExecutor.CreateFromFactory(PoolFactory);
    Repo := TRepository<TUsuarioDTO>.Create(Exec);
    U1 := TUsuarioDTO.Create;
    U2 := TUsuarioDTO.Create;
    try
      TSQLTransaction.ExecuteInTransaction(Exec,
        procedure
        begin
          U1.Email := 'a@dominio.com';
          U1.Cpf := '11111111111';
          U1.Senha := 'hash_a';
          Repo.Insert(U1);

          U2.Email := 'b@dominio.com';
          U2.Cpf := '22222222222';
          U2.Senha := 'hash_b';
          Repo.Insert(U2);
        end
      );
    finally
      U1.Free;
      U2.Free;
      Repo.Free;
    end;
  finally
    Params.Free;
  end;
end;
```

### 5. Pool de conexoes (FireDAC)

Para uso concorrente, crie o executor via factory de pool:

```pascal
uses
  uFluentORM.Executor,
  uFluentORM.Executor.FireDAC,
  uFluentORM.ConnectionPool.FireDAC;

procedure ExemploPoolFireDAC;
var
  Params: TStringList;
  PoolFactory: IFireDACConnectionFactory;
  PoolOptions: TFireDACPoolOptions;
  Exec: ISQLExecutor;
  Repo: TRepository<TUsuarioDTO>;
begin
  Params := TStringList.Create;
  try
    Params.Values['DriverID'] := 'MySQL';
    Params.Values['Server'] := 'localhost';
    Params.Values['Port'] := '3306';
    Params.Values['Database'] := 'chat_database';
    Params.Values['User_Name'] := 'root';
    Params.Values['Password'] := 'admin';

    PoolOptions := TFireDACPoolOptions.Default;
    PoolOptions.MaximumItems := 100;

    PoolFactory := TFireDACPooledConnectionFactory.Create(Params, PoolOptions);
    Exec := TFireDACSQLExecutor.CreateFromFactory(PoolFactory);
    Repo := TRepository<TUsuarioDTO>.Create(Exec);
    try
      // use normalmente (Insert/Update/Delete/Count)
    finally
      Repo.Free;
    end;
  finally
    Params.Free;
  end;
end;
```

Detalhe importante:
- o FluentORM registra/reutiliza `ConnectionDef` no `FDManager` por configuracao;
- isso evita criar multiplos pools para os mesmos parametros;
- cada conexao e aberta por `ConnectionDefName`, seguindo o modelo recomendado do FireDAC.

## Gerador automatico de DTOs (MySQL, SQL Server e PostgreSQL)

Foi adicionado um projeto de ferramenta em:

- `Tools/FluentORM.DtoGenerator`

Esse gerador le as tabelas via `INFORMATION_SCHEMA` e cria DTOs no formato do FluentORM (`[Table]`, `[Column]`, `[Key]`).

- MySQL: ADO (driver ODBC do MySQL)
- SQL Server: ADO (OLE DB)
- PostgreSQL: ADO (driver ODBC psqlODBC)
- Regras automaticas:
- `tinyint(1)` (MySQL) vira `Boolean`
- `timestamp`/`rowversion` (SQL Server) vira `TBytes` com `[ReadOnly]`
- `uuid`/`uniqueidentifier` vira `TGuid`; `bytea`/`blob`/`varbinary` vira `TBytes`; `date` vira `TDate`
- chave `identity`/`auto_increment`/`serial` recebe `[Key(True)]`
- por padrao (`nullable_mode=native`), campos nullable escalares mantem o tipo nativo
- opcionalmente, `nullable_mode=variant` transforma nullable escalar em `Variant`
- campos de auditoria (`data_criacao`, `data_atualizacao`, `created_at`, `updated_at`) recebem `[ReadOnly]`

Exemplos:

```bash
FluentORM.DtoGenerator.exe --db=mysql --server=localhost --port=3306 --database=chat_database --user=root --password=admin --ado_provider_mysql=MSDASQL --mysql_odbc_driver="MySQL ODBC 8.0 Unicode Driver" --table=usuario --output=.\GeneratedDTOs
```

```bash
FluentORM.DtoGenerator.exe --db=sqlserver --server=localhost --port=1433 --database=MinhaBase --schema=dbo --user=sa --password=senha --ado_provider=SQLOLEDB --output=.\GeneratedDTOs
```

```bash
FluentORM.DtoGenerator.exe --db=postgres --server=localhost --port=5432 --database=MinhaBase --schema=public --user=postgres --password=senha --pg_odbc_driver="PostgreSQL Unicode(x64)" --output=.\GeneratedDTOs
```

Detalhes completos em:

- `Tools/FluentORM.DtoGenerator/README.md`

## Exemplos (`Samples/`)

| Exemplo | Tipo | O que mostra |
|---------|------|--------------|
| `Samples/Sample01.dpr` | VCL | Builder (varios dialetos) e `TRepository<T>` com MySQL, transacao e pool. |
| `Samples/Sample02/` | VCL | Carrega a tabela `usuario` em grid a partir do SQL do builder (MySQL, SQL Server ou PostgreSQL). Scripts: `script-MySQL.sql`, `script-MSSQL.sql`, `script-PostgreSQL.sql`. |
| `Samples/Sample04_MySQL_VCL/` | VCL | Cadastro de clientes completo em MySQL: cria banco/tabela, lista com filtro e paginacao (builder + `ToSQLCount`), `FindById`/`Insert`/`Update`/`DeleteById`, geracao de dados em transacao e log de todo SQL executado. |
| `Samples/Sample03_MultiBanco/` | Console | O mesmo codigo em MySQL, PostgreSQL (FireDAC) e SQL Server (ADO): CRUD em transacao, rollback automatico, mapeamento de tipos (`Int64`, `TGUID`, `Currency`, `Double`, `TDate`, `TBytes`, `Variant`), builder com paginacao e `ToSQLCount` lido com `OpenQuery`. Scripts em `scripts/` (o do SQL Server cria trigger). |

```bat
Sample03.exe --db=mysql    --server=localhost --database=fluentorm_demo --user=root     --password=admin
Sample03.exe --db=mssql    --server=localhost --database=fluentorm_demo --user=sa       --password=senha
Sample03.exe --db=postgres --server=localhost --database=fluentorm_demo --user=postgres --password=admin
```

Veja `Samples/Sample03_MultiBanco/README.md` para as opcoes.
