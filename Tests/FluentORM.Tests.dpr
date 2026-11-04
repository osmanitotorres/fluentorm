program FluentORM.Tests;

{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  System.Variants,
  Data.DB,
  uFluentORM.Types,
  uFluentORM.Attributes,
  uFluentORM.Executor,
  uFluentORM,
  uFluentORM.Repository;

type
  [Table('usuario')]
  TUsuario = class
  private
    FId: Integer;
    FNome: string;
    FEmail: string;
    FAtivo: Boolean;
    FCriadoEm: TDateTime;
  public
    [Key(True)]
    [Column('id')]
    property Id: Integer read FId write FId;

    [Column('nome')]
    property Nome: string read FNome write FNome;

    [Column('email')]
    property Email: string read FEmail write FEmail;

    [Column('ativo')]
    property Ativo: Boolean read FAtivo write FAtivo;

    [Column('criado_em')]
    property CriadoEm: TDateTime read FCriadoEm write FCriadoEm;
  end;

  [Table('guid_tbl')]
  TGuidEntity = class
  private
    FId: TGUID;
    FNome: string;
  public
    [Key(True)]
    [Column('id')]
    property Id: TGUID read FId write FId;

    [Column('nome')]
    property Nome: string read FNome write FNome;
  end;

  [Table('produto')]
  TProduto = class
  private
    FId: Int64;
    FPreco: Double;
    FCusto: Currency;
    FValidade: TDate;
    FFoto: TBytes;
    FCodigo: TGUID;
    FObs: Variant;
  public
    [Key(True)]
    [Column('id')]
    property Id: Int64 read FId write FId;
    [Column('preco')]
    property Preco: Double read FPreco write FPreco;
    [Column('custo')]
    property Custo: Currency read FCusto write FCusto;
    [Column('validade')]
    property Validade: TDate read FValidade write FValidade;
    [Column('foto')]
    property Foto: TBytes read FFoto write FFoto;
    [Column('codigo')]
    property Codigo: TGUID read FCodigo write FCodigo;
    [Column('obs')]
    property Obs: Variant read FObs write FObs;
  end;

  [Table('pessoa')]
  TPessoaNullable = class
  private
    FId: Integer;
    FNascimento: Variant;
    FPontos: Variant;
  public
    [Key(True)]
    [Column('id')]
    property Id: Integer read FId write FId;
    [Column('nascimento', ftDate)]
    property Nascimento: Variant read FNascimento write FNascimento;
    [Column('pontos')]
    property Pontos: Variant read FPontos write FPontos;
  end;

  [Table('Cliente')]
  TClienteMixedCase = class
  private
    FId: Integer;
    FNome: string;
  public
    [Key(True)]
    [Column('Id')]
    property Id: Integer read FId write FId;
    [Column('nome')]
    property Nome: string read FNome write FNome;
  end;

  /// <summary>
  /// Records the SQL/params received by the repository and returns canned
  /// values, so the generated CRUD statements can be asserted without a DB.
  /// </summary>
  TFakeExecutor = class(TInterfacedObject, ISQLExecutor, ISQLDialectInfo, ISQLIdentityExecutor)
  private
    FDatabaseType: TSQLDatabaseType;
    FLastSQL: string;
    FLastParams: TSQLParams;
    FScalarResult: Variant;
    FIdentityResult: Variant;
    FExecuteResult: Integer;
  public
    constructor Create(ADatabaseType: TSQLDatabaseType);
    function Execute(const ASQL: string; const AParams: TSQLParams): Integer;
    function ExecuteScalar(const ASQL: string; const AParams: TSQLParams): Variant;
    function GetDatabaseType: TSQLDatabaseType;
    function GetLastInsertedId: Variant;

    property LastSQL: string read FLastSQL;
    property LastParams: TSQLParams read FLastParams;
    property ScalarResult: Variant read FScalarResult write FScalarResult;
    property IdentityResult: Variant read FIdentityResult write FIdentityResult;
    property ExecuteResult: Integer read FExecuteResult write FExecuteResult;
  end;

var
  Checks: Integer = 0;
  Failures: Integer = 0;

procedure CheckTrue(ACondition: Boolean; const AName: string);
begin
  Inc(Checks);
  if not ACondition then
  begin
    Inc(Failures);
    Writeln('FAIL: ', AName);
  end;
end;

procedure CheckEqualsStr(const AExpected, AActual, AName: string);
begin
  Inc(Checks);
  if not SameStr(AExpected, AActual) then
  begin
    Inc(Failures);
    Writeln('FAIL: ', AName);
    Writeln('  expected: ', AExpected);
    Writeln('  actual  : ', AActual);
  end;
end;

procedure CheckContains(const ANeedle, AHaystack, AName: string);
begin
  Inc(Checks);
  if Pos(ANeedle, AHaystack) = 0 then
  begin
    Inc(Failures);
    Writeln('FAIL: ', AName);
    Writeln('  expected to find: ', ANeedle);
    Writeln('  in: ', AHaystack);
  end;
end;

procedure CheckNotContains(const ANeedle, AHaystack, AName: string);
begin
  Inc(Checks);
  if Pos(ANeedle, AHaystack) > 0 then
  begin
    Inc(Failures);
    Writeln('FAIL: ', AName);
    Writeln('  expected NOT to find: ', ANeedle);
    Writeln('  in: ', AHaystack);
  end;
end;

function ParamValue(const AParams: TSQLParams; const AName: string): Variant;
var
  I: Integer;
begin
  Result := Null;
  for I := Low(AParams) to High(AParams) do
    if SameText(AParams[I].Name, AName) then
      Exit(AParams[I].Value);
end;

function ParamType(const AParams: TSQLParams; const AName: string): TFieldType;
var
  I: Integer;
begin
  Result := ftUnknown;
  for I := Low(AParams) to High(AParams) do
    if SameText(AParams[I].Name, AName) then
      Exit(AParams[I].DataType);
end;

function NormalizeSQL(const ASQL: string): string;
begin
  Result := StringReplace(Trim(ASQL), #13#10, ' ', [rfReplaceAll]);
  Result := StringReplace(Result, #10, ' ', [rfReplaceAll]);
  Result := StringReplace(Result, #9, ' ', [rfReplaceAll]);
  while Pos('  ', Result) > 0 do
    Result := StringReplace(Result, '  ', ' ', [rfReplaceAll]);
end;

{ TFakeExecutor }

constructor TFakeExecutor.Create(ADatabaseType: TSQLDatabaseType);
begin
  inherited Create;
  FDatabaseType := ADatabaseType;
  FScalarResult := Null;
  FIdentityResult := Null;
  FExecuteResult := 1;
end;

function TFakeExecutor.Execute(const ASQL: string; const AParams: TSQLParams): Integer;
begin
  FLastSQL := ASQL;
  FLastParams := AParams;
  Result := FExecuteResult;
end;

function TFakeExecutor.ExecuteScalar(const ASQL: string; const AParams: TSQLParams): Variant;
begin
  FLastSQL := ASQL;
  FLastParams := AParams;
  Result := FScalarResult;
end;

function TFakeExecutor.GetDatabaseType: TSQLDatabaseType;
begin
  Result := FDatabaseType;
end;

function TFakeExecutor.GetLastInsertedId: Variant;
begin
  Result := FIdentityResult;
end;

{ --------------------------------------------------------------------------
  Builder: identifiers, parameters, literals
  -------------------------------------------------------------------------- }

procedure TestIdentifierQuoting;
var
  SQL, S: TSQLBuilder;
begin
  SQL := TSQLBuilder.Create;
  try
    SQL.SetDatabaseType(dbMSSQL);
    SQL.QuoteIdentifiers := True;
    S := SQL.Select.Fields(['id', 'nome']).From('usuario');
    CheckEqualsStr('SELECT [id], [nome] FROM [usuario];', S.ToSQL,
      'MSSQL quotes identifiers with brackets');

    SQL.Clear;
    SQL.SetDatabaseType(dbMySQL);
    SQL.QuoteIdentifiers := True;
    S := SQL.Select.Fields(['id']).From('usuario');
    CheckEqualsStr('SELECT `id` FROM `usuario`;', S.ToSQL,
      'MySQL quotes identifiers with backticks');

    SQL.Clear;
    SQL.SetDatabaseType(dbPostgreSQL);
    SQL.QuoteIdentifiers := True;
    S := SQL.Select.Fields(['id']).From('usuario');
    CheckEqualsStr('SELECT "id" FROM "usuario";', S.ToSQL,
      'PostgreSQL quotes identifiers with double quotes');

    SQL.Clear;
    SQL.SetDatabaseType(dbMSSQL);
    SQL.QuoteIdentifiers := True;
    S := SQL.Select.All.From('dbo.usuario');
    CheckContains('FROM [dbo].[usuario]', S.ToSQL, 'MSSQL quotes dotted identifiers');

    SQL.Clear;
    SQL.SetDatabaseType(dbPostgreSQL);
    SQL.QuoteIdentifiers := True;
    S := SQL.Select.All.From('usuario u');
    CheckContains('FROM usuario u', S.ToSQL, 'table aliases are left untouched');

    SQL.Clear;
    SQL.SetDatabaseType(dbPostgreSQL);
    SQL.QuoteIdentifiers := False;
    S := SQL.Select.Fields(['id']).From('usuario');
    CheckEqualsStr('SELECT id FROM usuario;', S.ToSQL,
      'QuoteIdentifiers=False keeps legacy identifiers');
  finally
    SQL.Free;
  end;
end;

procedure TestParameterPrefixAndValues;
var
  SQL: TSQLBuilder;
  S: string;
  Params: TArray<string>;
begin
  SQL := TSQLBuilder.Create;
  try
    SQL.SetDatabaseType(dbMSSQL);
    S := SQL.Select.All.From('usuario').Where('nome', 'O''Brien').ToSQL;
    CheckContains('WHERE nome = :nome', S, 'MSSQL uses ":" parameter markers');
    Params := SQL.GetParameters;
    CheckEqualsStr('nome', string.Join(',', Params), 'parameter name is derived from field');
    CheckEqualsStr('O''Brien', VarToStr(SQL.GetParamValue('nome')), 'parameter keeps original value');

    SQL.Clear;
    SQL.SetDatabaseType(dbPostgreSQL);
    SQL.ParamPrefix := '@';
    S := SQL.Select.All.From('usuario').Where('nome', 'x').ToSQL;
    CheckContains('WHERE nome = @nome', S, 'ParamPrefix override is honoured');

    SQL.Clear;
    SQL.SetDatabaseType(dbMySQL);
    SQL.UseNamedParams := False;
    S := SQL.Select.All.From('usuario').Where('nome', 'O''Brien').ToSQL;
    CheckContains('WHERE nome = ''O''''Brien''', S, 'single quotes are escaped');

    SQL.Clear;
    SQL.SetDatabaseType(dbMySQL);
    SQL.UseNamedParams := False;
    S := SQL.Select.All.From('usuario').Where('caminho', 'C:\temp\').ToSQL;
    CheckContains('C:\\temp\\', S, 'MySQL backslashes are escaped in literals');
  finally
    SQL.Free;
  end;
end;

procedure TestLiterals;
var
  SQL: TSQLBuilder;
  S: string;
begin
  SQL := TSQLBuilder.Create;
  try
    SQL.SetDatabaseType(dbMSSQL);
    SQL.UseNamedParams := False;
    S := SQL.Select.All.From('usuario').Where('ativo', True).ToSQL;
    CheckContains('WHERE ativo = 1', S, 'MSSQL boolean literal is 1');

    SQL.Clear;
    SQL.SetDatabaseType(dbPostgreSQL);
    SQL.UseNamedParams := False;
    S := SQL.Select.All.From('usuario').Where('ativo', True).ToSQL;
    CheckContains('WHERE ativo = TRUE', S, 'PostgreSQL boolean literal is TRUE');

    SQL.Clear;
    SQL.SetDatabaseType(dbMSSQL);
    SQL.UseNamedParams := False;
    S := SQL.Select.All.From('usuario')
      .Where('criado_em', EncodeDate(2024, 1, 15), opGreaterOrEqual).ToSQL;
    CheckContains('criado_em >= ''20240115''', S, 'MSSQL date literal is ISO basic');

    SQL.Clear;
    SQL.SetDatabaseType(dbPostgreSQL);
    SQL.UseNamedParams := False;
    S := SQL.Select.All.From('usuario')
      .Where('criado_em', EncodeDate(2024, 1, 15), opGreaterOrEqual).ToSQL;
    CheckContains('criado_em >= ''2024-01-15''', S, 'PostgreSQL date literal is ISO extended');

    SQL.Clear;
    SQL.SetDatabaseType(dbPostgreSQL);
    SQL.UseNamedParams := False;
    S := SQL.Select.All.From('usuario').Where('valor', 1234.5).ToSQL;
    CheckContains('valor = 1234.5', S, 'decimal separator is invariant');
  finally
    SQL.Free;
  end;
end;

{ --------------------------------------------------------------------------
  Builder: pagination
  -------------------------------------------------------------------------- }

procedure TestPagination;
var
  SQL: TSQLBuilder;
  S: string;
begin
  SQL := TSQLBuilder.Create;
  try
    SQL.SetDatabaseType(dbMSSQL);
    SQL.QuoteIdentifiers := True;
    S := SQL.Select.All.From('usuario').OrderByAsc('nome').Paginate(2, 10).ToSQL;
    CheckContains('ORDER BY [nome] ASC OFFSET 10 ROWS FETCH NEXT 10 ROWS ONLY', S,
      'MSSQL pagination uses OFFSET/FETCH');

    SQL.Clear;
    SQL.SetDatabaseType(dbMSSQL);
    S := SQL.Select.All.From('usuario').Limit(5).ToSQL;
    CheckContains('ORDER BY (SELECT NULL) OFFSET 0 ROWS FETCH NEXT 5 ROWS ONLY', S,
      'MSSQL injects ORDER BY when paginating without ORDER BY');

    SQL.Clear;
    SQL.SetDatabaseType(dbPostgreSQL);
    S := SQL.Select.All.From('usuario').Limit(10).Offset(20).ToSQL;
    CheckContains('LIMIT 10 OFFSET 20', S, 'PostgreSQL pagination');

    SQL.Clear;
    SQL.SetDatabaseType(dbMySQL);
    S := SQL.Select.All.From('usuario').Limit(10).Offset(20).ToSQL;
    CheckContains('LIMIT 10 OFFSET 20', S, 'MySQL pagination');

    SQL.Clear;
    SQL.SetDatabaseType(dbMySQL);
    S := SQL.Select.All.From('usuario').Offset(20).ToSQL;
    CheckContains('LIMIT 18446744073709551615 OFFSET 20', S,
      'MySQL accepts OFFSET through LIMIT max value');

    SQL.Clear;
    SQL.SetDatabaseType(dbSQLite);
    S := SQL.Select.All.From('usuario').Offset(5).ToSQL;
    CheckContains('LIMIT -1 OFFSET 5', S, 'SQLite accepts OFFSET through LIMIT -1');

    SQL.Clear;
    SQL.SetDatabaseType(dbFirebird);
    S := SQL.Select.All.From('usuario').Paginate(2, 10).ToSQL;
    CheckContains('ROWS 11 TO 20', S, 'Firebird pagination uses ROWS');

    SQL.Clear;
    SQL.SetDatabaseType(dbPostgreSQL);
    S := SQL.Select.All.From('usuario').Paginate(3, 15).ToSQL;
    CheckContains('LIMIT 15 OFFSET 30', S, 'Paginate computes LIMIT/OFFSET');
  finally
    SQL.Free;
  end;
end;

{ --------------------------------------------------------------------------
  Builder: aggregates, unions, CTEs
  -------------------------------------------------------------------------- }

procedure TestCountGeneration;
var
  SQL, Union1, Union2: TSQLBuilder;
  S: string;
begin
  SQL := TSQLBuilder.Create;
  try
    SQL.SetDatabaseType(dbMSSQL);
    S := SQL.Select.Fields(['id', 'nome']).From('usuario').Where('ativo', True).ToSQLCount;
    CheckContains('SELECT COUNT(*) AS Total FROM usuario WHERE ativo = :ativo', S,
      'simple count discards the select list');

    SQL.Clear;
    SQL.SetDatabaseType(dbPostgreSQL);
    S := SQL.SelectDistinct.Fields(['cidade']).From('usuario').ToSQLCount;
    CheckContains('SELECT COUNT(*) AS Total FROM (SELECT DISTINCT cidade FROM usuario) fluent_count',
      S, 'distinct count is wrapped in a derived table');

    SQL.Clear;
    SQL.SetDatabaseType(dbMSSQL);
    S := SQL.Select.Fields(['cidade', 'COUNT(*)']).From('usuario')
      .GroupBy('cidade').ToSQLCount;
    CheckContains('SELECT COUNT(*) AS Total FROM (SELECT 1 AS fluent_row FROM usuario GROUP BY cidade) fluent_count',
      S, 'grouped count is wrapped in a derived table');

    SQL.Clear;
    SQL.SetDatabaseType(dbMySQL);
    S := SQL.Select.Fields(['cidade', 'COUNT(*) AS total']).From('usuario')
      .GroupBy('cidade').Having('COUNT(*)', 2, opGreater).ToSQLCount;
    CheckContains('SELECT COUNT(*) AS Total FROM (SELECT cidade, COUNT(*) AS total FROM usuario GROUP BY cidade HAVING COUNT(*) > :COUNT',
      S, 'MySQL grouped+having count keeps the select list');
  finally
    SQL.Free;
  end;

  Union1 := TSQLBuilder.Create;
  Union2 := TSQLBuilder.Create;
  try
    Union1.SetDatabaseType(dbPostgreSQL);
    Union2.SetDatabaseType(dbPostgreSQL);
    Union1.Select.Fields(['id', 'nome']).From('ativos').Where('tipo', 1);
    Union2.Select.Fields(['id', 'nome']).From('inativos').Where('tipo', 2);
    Union1.Union(Union2);
    S := Union1.ToSQL;
    CheckContains('(SELECT id, nome FROM ativos WHERE tipo = :tipo) UNION (SELECT id, nome FROM inativos WHERE tipo = :tipo_u0_1)',
      S, 'UNION merges and renames parameters from the second builder');
    CheckTrue(Length(Union1.GetParameters) = 2, 'UNION exposes both parameters');
    CheckEqualsStr('2', VarToStr(Union1.GetParamValue('tipo_u0_1')), 'UNION param value is copied');

    Union1.Clear;
    Union1.SetDatabaseType(dbMSSQL);
    Union1.Select.Fields(['id']).From('a');
    Union2.SetDatabaseType(dbMSSQL);
    Union2.Clear;
    Union2.Select.Fields(['id']).From('b');
    Union1.Union(Union2).Limit(5);
    S := Union1.ToSQL;
    CheckContains('ORDER BY 1 OFFSET 0 ROWS FETCH NEXT 5 ROWS ONLY', S,
      'MSSQL union pagination uses ORDER BY 1');
  finally
    Union1.Free;
    Union2.Free;
  end;

  SQL := TSQLBuilder.Create;
  try
    SQL.StrictMode := False;
    SQL.SetDatabaseType(dbMSSQL);
    S := SQL.Select.All.From('arvore')
      .WithRecursiveCTE('arvore', 'SELECT 1 AS id')
      .ToSQL;
    CheckContains('WITH arvore AS (SELECT 1 AS id)', S, 'recursive CTE on MSSQL omits RECURSIVE');

    SQL.Clear;
    SQL.StrictMode := False;
    SQL.SetDatabaseType(dbPostgreSQL);
    S := SQL.Select.All.From('arvore')
      .WithRecursiveCTE('arvore', 'SELECT 1 AS id')
      .ToSQL;
    CheckContains('WITH RECURSIVE arvore AS (SELECT 1 AS id)', S,
      'recursive CTE on PostgreSQL includes RECURSIVE');
  finally
    SQL.Free;
  end;
end;

procedure TestDialectRestrictions;
var
  SQL: TSQLBuilder;
  Raised: Boolean;
begin
  SQL := TSQLBuilder.Create;
  try
    SQL.SetDatabaseType(dbMySQL);
    Raised := False;
    try
      SQL.Select.All.From('a').FullJoin('b', 'b.id = a.id').ToSQL;
    except
      on E: Exception do
        Raised := E.Message.Contains('FULL JOIN');
    end;
    CheckTrue(Raised, 'MySQL FULL JOIN raises a clear error');
  finally
    SQL.Free;
  end;
end;

{ --------------------------------------------------------------------------
  Repository
  -------------------------------------------------------------------------- }

procedure TestRepositoryMSSQL;
var
  Fake: TFakeExecutor;
  FakeIntf: ISQLExecutor;
  Repo: TRepository<TUsuario>;
  U: TUsuario;
begin
  Fake := TFakeExecutor.Create(dbMSSQL);
  FakeIntf := Fake;
  Fake.ScalarResult := 42;
  U := TUsuario.Create;
  Repo := TRepository<TUsuario>.Create(FakeIntf);
  try
    U.Nome := 'Ana';
    U.Email := 'ana@example.com';
    U.Ativo := True;
    U.CriadoEm := EncodeDate(2024, 5, 1);

    CheckTrue(Repo.Insert(U) = 1, 'MSSQL insert returns 1');
    CheckContains('INSERT INTO [usuario]', Fake.LastSQL, 'MSSQL insert quotes the table');
    CheckContains('OUTPUT INSERTED.[id] INTO @fluent_ids VALUES', Fake.LastSQL,
      'MSSQL insert uses OUTPUT ... INTO (works with triggers)');
    CheckContains('DECLARE @fluent_ids TABLE (id INT)', Fake.LastSQL,
      'MSSQL insert declares the key table with the key SQL type');
    CheckContains('SELECT TOP 1 id FROM @fluent_ids', Fake.LastSQL,
      'MSSQL insert returns the generated key');
    CheckTrue(ParamType(Fake.LastParams, 'p_ativo') = ftBoolean, 'Boolean param is typed');
    CheckTrue(ParamType(Fake.LastParams, 'p_criado_em') = ftDateTime, 'TDateTime param is typed');
    CheckTrue(ParamType(Fake.LastParams, 'p_nome') = ftWideString, 'string param is typed');
    CheckNotContains('RETURNING', Fake.LastSQL, 'MSSQL insert has no RETURNING');
    CheckTrue(U.Id = 42, 'MSSQL identity is assigned to the entity');
    CheckTrue(ParamValue(Fake.LastParams, 'p_nome') = 'Ana', 'insert binds p_nome');
    CheckTrue(ParamValue(Fake.LastParams, 'p_email') = 'ana@example.com', 'insert binds p_email');

    U.Id := 42;
    U.Nome := 'Ana Maria';
    Fake.ExecuteResult := 1;
    CheckTrue(Repo.Update(U) = 1, 'MSSQL update returns affected rows');
    CheckContains('UPDATE [usuario] SET', Fake.LastSQL, 'MSSQL update quotes the table');
    CheckContains('WHERE [id] = :k_id', Fake.LastSQL, 'MSSQL update filters by quoted key');
    CheckTrue(ParamValue(Fake.LastParams, 'k_id') = 42, 'update binds the key');

    CheckTrue(Repo.DeleteById(42) = 1, 'MSSQL delete returns affected rows');
    CheckEqualsStr('DELETE FROM [usuario] WHERE [id] = :k_id', Trim(Fake.LastSQL),
      'MSSQL delete SQL');

    Fake.ScalarResult := 7;
    CheckTrue(Repo.Count = 7, 'MSSQL count reads the scalar');
    CheckContains('SELECT COUNT(*) AS Total FROM [usuario]', Fake.LastSQL, 'MSSQL count SQL');
  finally
    Repo.Free;
    U.Free;
    FakeIntf := nil;
  end;
end;

procedure TestRepositoryPostgreSQL;
var
  Fake: TFakeExecutor;
  FakeIntf: ISQLExecutor;
  Repo: TRepository<TUsuario>;
  U: TUsuario;
begin
  Fake := TFakeExecutor.Create(dbPostgreSQL);
  FakeIntf := Fake;
  Fake.ScalarResult := 77;
  U := TUsuario.Create;
  Repo := TRepository<TUsuario>.Create(FakeIntf);
  try
    U.Nome := 'Bia';
    CheckTrue(Repo.Insert(U) = 1, 'PostgreSQL insert returns 1');
    CheckContains('INSERT INTO "usuario"', Fake.LastSQL, 'PostgreSQL insert quotes the table');
    CheckContains('RETURNING "id"', Fake.LastSQL, 'PostgreSQL insert uses RETURNING');
    CheckNotContains('OUTPUT', Fake.LastSQL, 'PostgreSQL insert has no OUTPUT');
    CheckTrue(U.Id = 77, 'PostgreSQL identity is assigned to the entity');
  finally
    Repo.Free;
    U.Free;
    FakeIntf := nil;
  end;
end;

procedure TestRepositoryMySQL;
var
  Fake: TFakeExecutor;
  FakeIntf: ISQLExecutor;
  Repo: TRepository<TUsuario>;
  U: TUsuario;
begin
  Fake := TFakeExecutor.Create(dbMySQL);
  FakeIntf := Fake;
  Fake.IdentityResult := 55;
  U := TUsuario.Create;
  Repo := TRepository<TUsuario>.Create(FakeIntf);
  try
    U.Nome := 'Caio';
    CheckTrue(Repo.Insert(U) = 1, 'MySQL insert returns affected rows');
    CheckContains('INSERT INTO `usuario`', Fake.LastSQL, 'MySQL insert quotes the table');
    CheckNotContains('OUTPUT', Fake.LastSQL, 'MySQL insert has no OUTPUT');
    CheckNotContains('RETURNING', Fake.LastSQL, 'MySQL insert has no RETURNING');
    CheckTrue(U.Id = 55, 'MySQL identity comes from LAST_INSERT_ID');
  finally
    Repo.Free;
    U.Free;
    FakeIntf := nil;
  end;
end;

procedure TestRepositoryGuidKey;
var
  Fake: TFakeExecutor;
  FakeIntf: ISQLExecutor;
  Repo: TRepository<TGuidEntity>;
  E: TGuidEntity;
  Expected, Actual: TGUID;
begin
  Expected := StringToGUID('{6F9619FF-8B86-D011-B42D-00C04FC964FF}');
  Fake := TFakeExecutor.Create(dbMSSQL);
  FakeIntf := Fake;
  Fake.ScalarResult := GUIDToString(Expected);
  E := TGuidEntity.Create;
  Repo := TRepository<TGuidEntity>.Create(FakeIntf);
  try
    E.Nome := 'Guid row';
    CheckTrue(Repo.Insert(E) = 1, 'GUID key insert returns 1');
    CheckContains('OUTPUT INSERTED.[id] INTO @fluent_ids', Fake.LastSQL, 'GUID entity insert uses OUTPUT INTO');
    CheckContains('TABLE (id UNIQUEIDENTIFIER)', Fake.LastSQL, 'GUID key table uses UNIQUEIDENTIFIER');
    Actual := E.Id;
    CheckTrue(IsEqualGUID(Actual, Expected), 'GUID key is assigned to the entity');
  finally
    Repo.Free;
    E.Free;
    FakeIntf := nil;
  end;
end;

procedure TestRepositoryQuoteToggle;
var
  Fake: TFakeExecutor;
  FakeIntf: ISQLExecutor;
  Repo: TRepository<TUsuario>;
  U: TUsuario;
begin
  Fake := TFakeExecutor.Create(dbMSSQL);
  FakeIntf := Fake;
  Fake.ScalarResult := 1;
  U := TUsuario.Create;
  Repo := TRepository<TUsuario>.Create(FakeIntf);
  try
    Repo.QuoteIdentifiers := False;
    U.Nome := 'Legacy';
    Repo.Insert(U);
    CheckContains('INSERT INTO usuario', Fake.LastSQL, 'legacy mode does not quote the table');
    CheckContains('(nome,', Fake.LastSQL, 'legacy mode does not quote columns');
  finally
    Repo.Free;
    U.Free;
    FakeIntf := nil;
  end;
end;

procedure TestRepositoryValueTypes;
var
  Fake: TFakeExecutor;
  FakeIntf: ISQLExecutor;
  Repo: TRepository<TProduto>;
  P: TProduto;
  V: Variant;
begin
  Fake := TFakeExecutor.Create(dbPostgreSQL);
  FakeIntf := Fake;
  Fake.ScalarResult := Int64(9000000000);
  P := TProduto.Create;
  Repo := TRepository<TProduto>.Create(FakeIntf);
  try
    P.Preco := 12.5;
    P.Custo := 7.25;
    P.Validade := EncodeDate(2025, 12, 31);
    P.Foto := TBytes.Create(1, 2, 3);
    P.Codigo := StringToGUID('{6F9619FF-8B86-D011-B42D-00C04FC964FF}');
    P.Obs := Null;
    Repo.Insert(P);

    V := ParamValue(Fake.LastParams, 'p_preco');
    CheckTrue(VarType(V) = varDouble, 'Double property is NOT sent as a date');
    CheckTrue(ParamType(Fake.LastParams, 'p_preco') = ftFloat, 'Double param is ftFloat');
    CheckTrue(ParamType(Fake.LastParams, 'p_custo') = ftBCD, 'Currency param is ftBCD (numeric)');
    CheckTrue(VarType(ParamValue(Fake.LastParams, 'p_validade')) = varDate, 'TDate property is a date');
    CheckTrue(ParamType(Fake.LastParams, 'p_validade') = ftDate, 'TDate param is ftDate');
    CheckTrue(ParamType(Fake.LastParams, 'p_foto') = ftBlob, 'TBytes param is ftBlob');
    V := ParamValue(Fake.LastParams, 'p_foto');
    CheckTrue(VarIsArray(V) and (VarArrayHighBound(V, 1) = 2), 'TBytes is sent as byte array');
    CheckTrue(ParamType(Fake.LastParams, 'p_codigo') = ftGuid, 'TGUID param is ftGuid on PostgreSQL');
    CheckTrue(VarIsNull(ParamValue(Fake.LastParams, 'p_obs')), 'Null Variant is sent as NULL');
    CheckTrue(P.Id = 9000000000, 'Int64 key is assigned');
  finally
    Repo.Free;
    P.Free;
    FakeIntf := nil;
  end;

  Fake := TFakeExecutor.Create(dbMySQL);
  FakeIntf := Fake;
  Fake.IdentityResult := 1;
  P := TProduto.Create;
  Repo := TRepository<TProduto>.Create(FakeIntf);
  try
    P.Codigo := StringToGUID('{6F9619FF-8B86-D011-B42D-00C04FC964FF}');
    Repo.Insert(P);
    CheckEqualsStr('6F9619FF-8B86-D011-B42D-00C04FC964FF',
      VarToStr(ParamValue(Fake.LastParams, 'p_codigo')), 'MySQL GUID is CHAR(36) without braces');
    CheckTrue(ParamType(Fake.LastParams, 'p_codigo') = ftWideString, 'MySQL GUID param is a string');
  finally
    Repo.Free;
    P.Free;
    FakeIntf := nil;
  end;
end;

procedure TestColumnDataTypeHint;
var
  Fake: TFakeExecutor;
  FakeIntf: ISQLExecutor;
  Repo: TRepository<TPessoaNullable>;
  P: TPessoaNullable;
begin
  Fake := TFakeExecutor.Create(dbPostgreSQL);
  FakeIntf := Fake;
  Fake.ScalarResult := 1;
  P := TPessoaNullable.Create;
  Repo := TRepository<TPessoaNullable>.Create(FakeIntf);
  try
    P.Nascimento := Null;
    P.Pontos := Null;
    Repo.Insert(P);
    CheckTrue(ParamType(Fake.LastParams, 'p_nascimento') = ftDate,
      '[Column(name, ftDate)] types a NULL Variant parameter');
    CheckTrue(VarIsNull(ParamValue(Fake.LastParams, 'p_nascimento')),
      'typed Variant parameter keeps NULL');
    CheckTrue(ParamType(Fake.LastParams, 'p_pontos') = ftUnknown,
      'Variant without hint stays ftUnknown');
  finally
    Repo.Free;
    P.Free;
    FakeIntf := nil;
  end;
end;

procedure TestRepositoryPostgreSQLCaseFolding;
var
  Fake: TFakeExecutor;
  FakeIntf: ISQLExecutor;
  Repo: TRepository<TClienteMixedCase>;
  C: TClienteMixedCase;
begin
  Fake := TFakeExecutor.Create(dbPostgreSQL);
  FakeIntf := Fake;
  Fake.ScalarResult := 1;
  C := TClienteMixedCase.Create;
  Repo := TRepository<TClienteMixedCase>.Create(FakeIntf);
  try
    C.Nome := 'x';
    Repo.Insert(C);
    CheckContains('INSERT INTO Cliente ("nome")', Fake.LastSQL,
      'PostgreSQL keeps mixed-case names unquoted (folded to lowercase)');
    CheckContains('RETURNING Id', Fake.LastSQL, 'PostgreSQL RETURNING follows the same rule');
  finally
    Repo.Free;
    C.Free;
    FakeIntf := nil;
  end;
end;

begin
  Writeln('FluentORM test suite');
  Writeln('--------------------');

  TestIdentifierQuoting;
  TestParameterPrefixAndValues;
  TestLiterals;
  TestPagination;
  TestCountGeneration;
  TestDialectRestrictions;
  TestRepositoryMSSQL;
  TestRepositoryPostgreSQL;
  TestRepositoryMySQL;
  TestRepositoryGuidKey;
  TestRepositoryQuoteToggle;
  TestRepositoryValueTypes;
  TestRepositoryPostgreSQLCaseFolding;
  TestColumnDataTypeHint;

  Writeln('--------------------');
  Writeln(Format('%d checks, %d failures', [Checks, Failures]));
  if Failures > 0 then
    ExitCode := 1;
end.
