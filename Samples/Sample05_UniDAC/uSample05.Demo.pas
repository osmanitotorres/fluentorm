unit uSample05.Demo;

{ Passo a passo do uso do FluentORM com UniDAC. Cada procedure e um passo:

  1. CreateExecutor     - duas formas de obter o ISQLExecutor UniDAC
  2. DemoRepository     - CRUD com TRepository<T> dentro de transacao
  3. DemoTipos          - Int64, TGUID, Currency, Double, TDate, TBytes, Variant
  4. DemoLeitura        - FindById e FindAll
  5. DemoBuilder        - TSQLBuilder + OpenQuery (TUniQuery) + ToSQLCount

  Nada aqui e especifico de um banco: trocar MySQL por SQL Server ou
  PostgreSQL e so trocar o ProviderName da conexao. }

interface

procedure RunDemo;

implementation

uses
  System.SysUtils,
  System.StrUtils,
  System.Variants,
  System.Generics.Collections,
  Data.DB,
  Uni,
  uFluentORM.Types,
  uFluentORM,
  uFluentORM.Executor,
  uFluentORM.Executor.UniDAC,
  uFluentORM.Repository,
  uSample03.Entities;

type
  TDemoOptions = record
    ProviderName: string; // 'MySQL', 'SQL Server', 'PostgreSQL'
    Server: string;
    Port: Integer;
    Database: string;
    User: string;
    Password: string;
    UseComponent: Boolean;
    KeepRows: Boolean;
  end;

function ArgValue(const AName, ADefault: string): string;
var
  I: Integer;
  Prefix: string;
begin
  Result := ADefault;
  Prefix := '--' + AName + '=';
  for I := 1 to ParamCount do
    if StartsText(Prefix, ParamStr(I)) then
      Exit(Copy(ParamStr(I), Length(Prefix) + 1, MaxInt));
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
var
  Db: string;
begin
  Db := LowerCase(ArgValue('db', 'mysql'));
  if Db = 'mysql' then
  begin
    Result.ProviderName := 'MySQL';
    Result.Port := StrToIntDef(ArgValue('port', '3306'), 3306);
    Result.User := ArgValue('user', 'root');
  end
  else if (Db = 'mssql') or (Db = 'sqlserver') then
  begin
    Result.ProviderName := 'SQL Server';
    Result.Port := StrToIntDef(ArgValue('port', '1433'), 1433);
    Result.User := ArgValue('user', 'sa');
  end
  else if (Db = 'postgres') or (Db = 'postgresql') or (Db = 'pg') then
  begin
    Result.ProviderName := 'PostgreSQL';
    Result.Port := StrToIntDef(ArgValue('port', '5432'), 5432);
    Result.User := ArgValue('user', 'postgres');
  end
  else
    raise Exception.Create('--db invalido. Use mysql, mssql ou postgres.');

  Result.Server := ArgValue('server', 'localhost');
  Result.Database := ArgValue('database', 'fluentorm_demo');
  Result.Password := ArgValue('password', '');
  Result.UseComponent := SameText(ArgValue('mode', 'executor'), 'component');
  Result.KeepRows := HasArg('keep');
end;

procedure Title(const AText: string);
begin
  Writeln;
  Writeln('=== ', AText, ' ', StringOfChar('=', 60 - Length(AText)));
end;

{ ---------------------------------------------------------------------------
  Passo 1 - obter o executor
  --------------------------------------------------------------------------- }

// Forma A: o executor cria e e dono da conexao (mais simples).
// Para MySQL ele liga o modo Direct do UniDAC: nao precisa de libmysql.dll.
function CreateOwnedExecutor(const AOpt: TDemoOptions): TUniDACSQLExecutor;
var
  Server: string;
  Port: Integer;
begin
  Server := AOpt.Server;
  Port := AOpt.Port;
  if AOpt.ProviderName = 'SQL Server' then
  begin
    // SQL Server: a porta vai junto do servidor (host,porta).
    Server := Server + ',' + IntToStr(Port);
    Port := 0;
  end;
  Result := TUniDACSQLExecutor.CreateConnected(AOpt.ProviderName, Server, Port,
    AOpt.Database, AOpt.User, AOpt.Password);
end;

// Forma B: a aplicacao ja tem uma TUniConnection (num DataModule, por exemplo).
// O executor apenas a usa: quem cria a conexao e quem a libera.
function CreateComponentConnection(const AOpt: TDemoOptions): TUniConnection;
begin
  Result := TUniConnection.Create(nil);
  try
    Result.LoginPrompt := False;
    Result.ProviderName := AOpt.ProviderName;
    Result.Database := AOpt.Database;
    Result.Username := AOpt.User;
    Result.Password := AOpt.Password;
    if AOpt.ProviderName = 'SQL Server' then
      Result.Server := AOpt.Server + ',' + IntToStr(AOpt.Port)
    else
    begin
      Result.Server := AOpt.Server;
      Result.Port := AOpt.Port;
    end;
    if AOpt.ProviderName = 'MySQL' then
      Result.SpecificOptions.Values['MySQL.Direct'] := 'True';
    Result.Connected := True;
  except
    Result.Free;
    raise;
  end;
end;

{ ---------------------------------------------------------------------------
  Passo 2 - CRUD com TRepository<T> em transacao
  --------------------------------------------------------------------------- }

procedure DemoRepository(const AExec: ISQLExecutor; AKeepRows: Boolean);
var
  Repo: TRepository<TUsuarioDTO>;
  U: TUsuarioDTO;
begin
  Title('2. TRepository<T>: Insert/Update/Delete em transacao');
  Repo := TRepository<TUsuarioDTO>.Create(AExec);
  U := TUsuarioDTO.Create;
  try
    Writeln('Dialeto detectado pelo repositorio: ',
      IfThen(Repo.DatabaseType = dbMySQL, 'MySQL',
      IfThen(Repo.DatabaseType = dbMSSQL, 'SQL Server',
      IfThen(Repo.DatabaseType = dbPostgreSQL, 'PostgreSQL', 'outro'))));

    // TUniConnection.StartTransaction/Commit/Rollback por baixo dos panos.
    TSQLTransaction.ExecuteInTransaction(AExec,
      procedure
      begin
        U.Email := 'unidac@exemplo.com';
        U.Cpf := '111.222.333-44';
        U.Nickname := 'unidac';
        U.Senha := 'hash';
        Repo.Insert(U);                      // id gerado volta para U.Id
        Writeln('Inserido usuario id = ', U.Id);

        U.Nickname := 'unidac.alterado';
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

{ ---------------------------------------------------------------------------
  Passo 3 - tipos de propriedade
  --------------------------------------------------------------------------- }

procedure DemoTipos(const AExec: ISQLExecutor; AKeepRows: Boolean);
var
  Repo: TRepository<TProdutoDTO>;
  P, Lido: TProdutoDTO;
  G: TGUID;
begin
  Title('3. Tipos: Int64, TGUID, Currency, Double, TDate, TBytes, Variant');
  Repo := TRepository<TProdutoDTO>.Create(AExec);
  P := TProdutoDTO.Create;
  try
    CreateGUID(G);
    P.Codigo := G;
    P.Nome := 'Produto via UniDAC';
    P.Preco := 19.90;
    P.Peso := 1.25;
    P.Validade := Date + 180;
    P.Foto := TBytes.Create(1, 2, 3, 4);
    P.Observacao := Null;
    Repo.Insert(P);
    Writeln('Inserido produto id = ', P.Id);

    // Passo 4 (leitura) aplicado ao mesmo registro.
    Lido := Repo.FindById(P.Id);
    try
      if Lido = nil then
        Writeln('FindById nao encontrou o produto!')
      else
        Writeln(Format('FindById: %s | preco %s | %d bytes de foto | codigo %s',
          [Lido.Nome, CurrToStr(Lido.Preco), Length(Lido.Foto),
           GUIDToString(Lido.Codigo)]));
    finally
      Lido.Free;
    end;

    if not AKeepRows then
      Repo.Delete(P);
  finally
    P.Free;
    Repo.Free;
  end;
end;

{ ---------------------------------------------------------------------------
  Passo 4 - FindAll
  --------------------------------------------------------------------------- }

procedure DemoLeitura(const AExec: ISQLExecutor);
var
  Repo: TRepository<TUsuarioDTO>;
  Lista: TObjectList<TUsuarioDTO>;
  U: TUsuarioDTO;
begin
  Title('4. FindAll (lista de entidades)');
  Repo := TRepository<TUsuarioDTO>.Create(AExec);
  try
    Lista := Repo.FindAll('id');   // ORDER BY id; a lista e dona dos objetos
    try
      for U in Lista do
        Writeln(Format('  #%d  %s', [U.Id, U.Email]));
      Writeln(Lista.Count, ' usuario(s).');
    finally
      Lista.Free;
    end;
  finally
    Repo.Free;
  end;
end;

{ ---------------------------------------------------------------------------
  Passo 5 - SQL Builder lido com TUniQuery
  --------------------------------------------------------------------------- }

procedure DemoBuilder(AExec: TUniDACSQLExecutor);
var
  SQL: TSQLBuilder;
  SQLText: string;
  Q: TUniQuery;
begin
  Title('5. TSQLBuilder + OpenQuery (TUniQuery)');
  SQL := TSQLBuilder.Create;
  try
    SQL.SetDatabaseType(AExec.GetDatabaseType);  // mesmo dialeto da conexao
    SQL.QuoteIdentifiers := True;
    SQL.Select
       .Fields(['id', 'email', 'nickname'])
       .From('usuario')
       .WhereLike('email', '@')
       .OrderByDesc('id')
       .Paginate(1, 5);

    Writeln(SQL.ToFormattedSQL);

    SQLText := SQL.ToSQL;                        // gera SQL + parametros
    Q := AExec.OpenQuery(SQLText, SQL.ToSQLParams);
    try
      while not Q.Eof do
      begin
        Writeln(Format('  #%-6s %s', [Q.FieldByName('id').AsString,
          Q.FieldByName('email').AsString]));
        Q.Next;
      end;
    finally
      Q.Free;
    end;

    SQLText := SQL.ToSQLCount;
    Writeln('Total: ', VarToStr(AExec.ExecuteScalar(SQLText, SQL.ToSQLParams)));
  finally
    SQL.Free;
  end;
end;

procedure RunDemo;
var
  Opt: TDemoOptions;
  Conn: TUniConnection;
  ExecObj: TUniDACSQLExecutor;
  Exec: ISQLExecutor;
begin
  if ParamCount = 0 then
  begin
    Writeln('Uso: Sample05 --db=mysql|mssql|postgres --server=localhost --database=fluentorm_demo');
    Writeln('              --user=USUARIO --password=SENHA [--port=N] [--mode=component] [--keep] [--pause]');
    Exit;
  end;

  Opt := LoadOptions;
  Conn := nil;
  try
    Title('1. Executor UniDAC');
    if Opt.UseComponent then
    begin
      Conn := CreateComponentConnection(Opt);
      ExecObj := TUniDACSQLExecutor.Create(Conn);   // nao libera a Conn
      Writeln('Modo: TUniConnection da aplicacao');
    end
    else
    begin
      ExecObj := CreateOwnedExecutor(Opt);           // dono da conexao
      Writeln('Modo: conexao criada pelo executor');
    end;
    Exec := ExecObj; // a interface controla o tempo de vida do executor
    Writeln('Provider: ', ExecObj.GetDriverID, '  Servidor: ', Opt.Server, ' / ', Opt.Database);

    DemoRepository(Exec, Opt.KeepRows);
    DemoTipos(Exec, Opt.KeepRows);
    DemoLeitura(Exec);
    DemoBuilder(ExecObj);

    Writeln;
    Writeln('Concluido.');
    Exec := nil; // libera o executor antes da conexao da aplicacao
  finally
    Conn.Free;
  end;
end;

end.
