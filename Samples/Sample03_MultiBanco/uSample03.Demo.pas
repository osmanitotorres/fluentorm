unit uSample03.Demo;

interface

procedure RunDemo;

implementation

uses
  System.SysUtils,
  System.StrUtils,
  System.Classes,
  System.Variants,
  System.DateUtils,
  Data.DB,
  FireDAC.Comp.Client,
  uFluentORM.Types,
  uFluentORM,
  uFluentORM.Executor,
  uFluentORM.Executor.FireDAC,
  uFluentORM.Executor.ADO,
  uFluentORM.ConnectionPool.FireDAC,
  uFluentORM.Repository,
  uSample03.Entities;

type
  // Abre um SELECT no executor em uso (FireDAC ou ADO); quem chama libera.
  TOpenQueryFunc = reference to function(const ASQL: string;
    const AParams: TSQLParams): TDataSet;

  TDemoOptions = record
    DbName: string;
    DriverID: string;
    Server: string;
    Port: string;
    Database: string;
    User: string;
    Password: string;
    KeepRows: Boolean;
  end;

function ArgValue(const AName, ADefault: string): string;
var
  I: Integer;
  S, Prefix: string;
begin
  Result := ADefault;
  Prefix := '--' + AName + '=';
  for I := 1 to ParamCount do
  begin
    S := ParamStr(I);
    if StartsText(Prefix, S) then
      Exit(Copy(S, Length(Prefix) + 1, MaxInt));
  end;
end;

function HasArg(const AName: string): Boolean;
var
  I: Integer;
begin
  Result := False;
  for I := 1 to ParamCount do
    if SameText(ParamStr(I), '--' + AName) then
      Exit(True);
end;

function LoadOptions: TDemoOptions;
begin
  Result.DbName := LowerCase(ArgValue('db', 'mysql'));
  if Result.DbName = 'mysql' then
  begin
    Result.DriverID := 'MySQL';
    Result.Port := ArgValue('port', '3306');
    Result.User := ArgValue('user', 'root');
  end
  else if (Result.DbName = 'mssql') or (Result.DbName = 'sqlserver') then
  begin
    Result.DriverID := 'MSSQL';
    Result.Port := ArgValue('port', '1433');
    Result.User := ArgValue('user', 'sa');
  end
  else if (Result.DbName = 'postgres') or (Result.DbName = 'postgresql') or
          (Result.DbName = 'pg') then
  begin
    Result.DriverID := 'PG';
    Result.Port := ArgValue('port', '5432');
    Result.User := ArgValue('user', 'postgres');
  end
  else
    raise Exception.Create('--db invalido. Use mysql, mssql ou postgres.');

  Result.Server := ArgValue('server', 'localhost');
  Result.Database := ArgValue('database', 'fluentorm_demo');
  Result.Password := ArgValue('password', '');
  Result.KeepRows := HasArg('keep');
end;

// MySQL / PostgreSQL: FireDAC com pool de conexoes.
function CreateFireDACExecutor(const AOpt: TDemoOptions): TFireDACSQLExecutor;
var
  Params: TStringList;
  PoolOptions: TFireDACPoolOptions;
  Factory: IFireDACConnectionFactory;
begin
  Params := TStringList.Create;
  try
    Params.Values['DriverID'] := AOpt.DriverID;
    Params.Values['Database'] := AOpt.Database;
    Params.Values['User_Name'] := AOpt.User;
    Params.Values['Password'] := AOpt.Password;

    Params.Values['Server'] := AOpt.Server;
    Params.Values['Port'] := AOpt.Port;

    if AOpt.DriverID = 'MySQL' then
      Params.Values['CharacterSet'] := 'utf8mb4';

    PoolOptions := TFireDACPoolOptions.Default;
    Factory := TFireDACPooledConnectionFactory.Create(Params, PoolOptions);
    Result := TFireDACSQLExecutor.CreateFromFactory(Factory);
  finally
    Params.Free;
  end;
end;

// SQL Server: ADO (OLE DB). O driver FireDAC.Phys.MSSQL so existe nas edicoes
// Enterprise/Architect do Delphi; com ele, basta usar CreateFireDACExecutor
// com DriverID=MSSQL e Server=host,porta.
function CreateADOExecutor(const AOpt: TDemoOptions): TADOSQLExecutor;
begin
  Result := TADOSQLExecutor.CreateFromConnectionString(
    TADOSQLExecutor.MSSQLConnectionString(
      AOpt.Server + ',' + AOpt.Port, AOpt.Database, AOpt.User, AOpt.Password,
      ArgValue('provider', 'MSOLEDBSQL'),
      SameText(ArgValue('encrypt', 'No'), 'Yes')),
    dbMSSQL);
end;

procedure Title(const AText: string);
begin
  Writeln;
  Writeln('=== ', AText, ' ', StringOfChar('=', 60 - Length(AText)));
end;

{ 1. CRUD de usuario dentro de uma transacao }
procedure DemoUsuario(const AExec: ISQLExecutor; AKeepRows: Boolean);
var
  Repo: TRepository<TUsuarioDTO>;
  U: TUsuarioDTO;
begin
  Title('Usuario: Insert/Update em transacao');
  Repo := TRepository<TUsuarioDTO>.Create(AExec);
  U := TUsuarioDTO.Create;
  try
    TSQLTransaction.ExecuteInTransaction(AExec,
      procedure
      begin
        U.Email := 'maria@exemplo.com';
        U.Cpf := '123.456.789-00';
        U.Nickname := 'maria';
        U.Bloqueado := False;
        U.Senha := 'hash-da-senha';
        Repo.Insert(U);
        Writeln('Inserido usuario id = ', U.Id);

        U.Nickname := 'maria.souza';
        Writeln('Update -> linhas afetadas: ', Repo.Update(U));
      end);

    Writeln('Total de usuarios: ', Repo.Count);

    if not AKeepRows then
      Writeln('Delete -> linhas afetadas: ', Repo.Delete(U));
  finally
    U.Free;
    Repo.Free;
  end;
end;

{ 2. Rollback automatico quando o bloco gera excecao }
procedure DemoRollback(const AExec: ISQLExecutor);
var
  Repo: TRepository<TUsuarioDTO>;
  U: TUsuarioDTO;
  Antes, Depois: Int64;
begin
  Title('Rollback automatico');
  Repo := TRepository<TUsuarioDTO>.Create(AExec);
  U := TUsuarioDTO.Create;
  try
    Antes := Repo.Count;
    try
      TSQLTransaction.ExecuteInTransaction(AExec,
        procedure
        begin
          U.Email := 'rollback@exemplo.com';
          Repo.Insert(U);
          raise Exception.Create('falha simulada depois do INSERT');
        end);
    except
      on E: Exception do
        Writeln('Excecao capturada: ', E.Message);
    end;
    Depois := Repo.Count;
    Writeln(Format('Registros antes: %d / depois: %d (INSERT desfeito)', [Antes, Depois]));
  finally
    U.Free;
    Repo.Free;
  end;
end;

{ 3. Tipos: Int64, TGUID, Currency, Double, TDate, TBytes, Variant nulo }
procedure DemoProduto(const AExec: ISQLExecutor; AKeepRows: Boolean);
var
  Repo: TRepository<TProdutoDTO>;
  P: TProdutoDTO;
  G: TGUID;
begin
  Title('Produto: mapeamento de tipos');
  Repo := TRepository<TProdutoDTO>.Create(AExec);
  P := TProdutoDTO.Create;
  try
    CreateGUID(G);
    P.Codigo := G;                       // uuid / uniqueidentifier / char(36)
    P.Nome := 'Cafe especial 500g';
    P.Preco := 49.90;                    // Currency -> numeric
    P.Peso := 0.5;                       // Double   -> float
    P.Validade := IncMonth(Date, 12);    // TDate    -> date
    P.Foto := TBytes.Create($89, $50, $4E, $47); // TBytes -> blob/varbinary/bytea
    P.Observacao := Null;                // Variant nulo -> NULL

    Repo.Insert(P);
    Writeln('Inserido produto id = ', P.Id, '  codigo = ', GUIDToString(P.Codigo));

    P.Preco := 44.90;
    P.Observacao := 'Promocao';
    Writeln('Update -> linhas afetadas: ', Repo.Update(P));

    if not AKeepRows then
      Writeln('Delete -> linhas afetadas: ', Repo.Delete(P));
  finally
    P.Free;
    Repo.Free;
  end;
end;

{ 4. SQL Builder + leitura com OpenQuery }
procedure DemoBuilder(const AExec: ISQLExecutor; ADatabaseType: TSQLDatabaseType;
  const AOpenQuery: TOpenQueryFunc);
var
  SQL: TSQLBuilder;
  SQLText: string;
  Q: TDataSet;
  Total: Variant;
begin
  Title('SQL Builder: filtro, paginacao e contagem');
  SQL := TSQLBuilder.Create;
  try
    SQL.SetDatabaseType(ADatabaseType);
    SQL.QuoteIdentifiers := True;

    SQL.Select
       .Fields(['id', 'email', 'nickname', 'bloqueado'])
       .From('usuario')
       .WhereLike('email', '@')
       .AndWhere('bloqueado', False)
       .OrderByDesc('id')
       .Paginate(1, 5);

    Writeln(SQL.ToFormattedSQL);
    Writeln;

    // ToSQL gera o texto e os parametros; ToSQLParams devolve os parametros
    // da ultima geracao no formato do executor.
    SQLText := SQL.ToSQL;
    Q := AOpenQuery(SQLText, SQL.ToSQLParams);
    try
      while not Q.Eof do
      begin
        Writeln(Format('  #%-6s %-30s %s',
          [Q.FieldByName('id').AsString,
           Q.FieldByName('email').AsString,
           Q.FieldByName('nickname').AsString]));
        Q.Next;
      end;
    finally
      Q.Free;
    end;

    SQLText := SQL.ToSQLCount;
    Total := AExec.ExecuteScalar(SQLText, SQL.ToSQLParams);
    Writeln('Total (ToSQLCount): ', VarToStr(Total));
  finally
    SQL.Free;
  end;
end;

procedure RunDemo;
var
  Opt: TDemoOptions;
  FDExec: TFireDACSQLExecutor;
  ADOExec: TADOSQLExecutor;
  Exec: ISQLExecutor;
  DatabaseType: TSQLDatabaseType;
  OpenQuery: TOpenQueryFunc;
begin
  if HasArg('help') or (ParamCount = 0) then
  begin
    Writeln('Uso: Sample03 --db=mysql|mssql|postgres --server=localhost --database=fluentorm_demo');
    Writeln('              --user=USUARIO --password=SENHA [--port=N] [--keep] [--pause]');
    if ParamCount = 0 then
      Exit;
  end;

  Opt := LoadOptions;
  Writeln('FluentORM Sample03');

  // A interface (Exec) controla o tempo de vida do executor.
  if Opt.DriverID = 'MSSQL' then
  begin
    ADOExec := CreateADOExecutor(Opt);
    Exec := ADOExec;
    DatabaseType := ADOExec.GetDatabaseType;
    OpenQuery :=
      function(const ASQL: string; const AParams: TSQLParams): TDataSet
      begin
        Result := ADOExec.OpenQuery(ASQL, AParams);
      end;
    Writeln('Acesso         : ADO (', ArgValue('provider', 'MSOLEDBSQL'), ')');
  end
  else
  begin
    FDExec := CreateFireDACExecutor(Opt);
    Exec := FDExec;
    DatabaseType := FDExec.GetDatabaseType;
    OpenQuery :=
      function(const ASQL: string; const AParams: TSQLParams): TDataSet
      begin
        Result := FDExec.OpenQuery(ASQL, AParams);
      end;
    Writeln('Acesso         : FireDAC (', FDExec.GetDriverID, ')');
  end;

  Writeln('Servidor       : ', Opt.Server, ':', Opt.Port, ' / ', Opt.Database);

  DemoUsuario(Exec, Opt.KeepRows);
  DemoRollback(Exec);
  DemoProduto(Exec, Opt.KeepRows);
  DemoBuilder(Exec, DatabaseType, OpenQuery);

  Writeln;
  Writeln('Concluido.');
end;

end.
