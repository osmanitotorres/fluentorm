unit uGenerator.Main;

interface

procedure RunGenerator;

implementation

uses
  System.SysUtils,
  System.Classes,
  System.IOUtils,
  System.Generics.Collections,
  Data.DB,
  Data.Win.ADODB,
  Winapi.ActiveX;

type
  TDbKind = (dbMySQL, dbSQLServer);
  TNullableMode = (nmNative, nmVariant);

  TColumnMeta = record
    ColumnName: string;
    DataType: string;
    ColumnType: string;
    IsPrimaryKey: Boolean;
    IsIdentity: Boolean;
    IsNullable: Boolean;
  end;

  TGeneratorOptions = record
    DbKind: TDbKind;
    Server: string;
    Port: Integer;
    Database: string;
    UserName: string;
    Password: string;
    SchemaName: string;
    TableName: string; // optional, empty => all tables
    OutputDir: string;
    ADOProvider: string; // SQL Server
    ADOProviderMySQL: string; // MySQL
    MySQLODBCDriver: string;
    ConnectionString: string; // optional override
    NullableMode: TNullableMode;
  end;

function BoolToLiteral(const AValue: Boolean): string;
begin
  if AValue then
    Result := 'True'
  else
    Result := 'False';
end;

function ParseArgs: TGeneratorOptions;
var
  I: Integer;
  Arg, Key, Value: string;
  P: Integer;
begin
  Result.DbKind := dbMySQL;
  Result.Port := 0;
  Result.Server := 'localhost';
  Result.SchemaName := '';
  Result.TableName := '';
  Result.OutputDir := TPath.Combine(GetCurrentDir, 'GeneratedDTOs');
  Result.ADOProvider := 'SQLOLEDB';
  Result.ADOProviderMySQL := 'MSDASQL';
  Result.MySQLODBCDriver := 'MySQL ODBC 9.6 Unicode Driver';
  Result.ConnectionString := '';
  Result.NullableMode := nmNative;

  for I := 1 to ParamCount do
  begin
    Arg := ParamStr(I);
    if Copy(Arg, 1, 2) <> '--' then
      Continue;

    P := Pos('=', Arg);
    if P <= 3 then
      Continue;

    Key := LowerCase(Trim(Copy(Arg, 3, P - 3)));
    Value := Trim(Copy(Arg, P + 1, MaxInt));

    if Key = 'db' then
    begin
      if SameText(Value, 'mysql') then
        Result.DbKind := dbMySQL
      else if SameText(Value, 'sqlserver') or SameText(Value, 'mssql') then
        Result.DbKind := dbSQLServer
      else
        raise Exception.Create('Invalid --db. Use mysql or sqlserver.');
    end
    else if Key = 'server' then
      Result.Server := Value
    else if Key = 'port' then
      Result.Port := StrToIntDef(Value, 0)
    else if Key = 'database' then
      Result.Database := Value
    else if Key = 'user' then
      Result.UserName := Value
    else if Key = 'password' then
      Result.Password := Value
    else if Key = 'schema' then
      Result.SchemaName := Value
    else if Key = 'table' then
      Result.TableName := Value
    else if Key = 'output' then
      Result.OutputDir := Value
    else if Key = 'ado_provider' then
      Result.ADOProvider := Value
    else if Key = 'ado_provider_mysql' then
      Result.ADOProviderMySQL := Value
    else if Key = 'mysql_odbc_driver' then
      Result.MySQLODBCDriver := Value
    else if Key = 'connstr' then
      Result.ConnectionString := Value
    else if Key = 'nullable_mode' then
    begin
      if SameText(Value, 'native') then
        Result.NullableMode := nmNative
      else if SameText(Value, 'variant') then
        Result.NullableMode := nmVariant
      else
        raise Exception.Create('Invalid --nullable_mode. Use native or variant.');
    end;
  end;

  if Result.Database = '' then
    raise Exception.Create('Missing --database.');
  if Result.UserName = '' then
    raise Exception.Create('Missing --user.');

  if Result.DbKind = dbMySQL then
  begin
    if Result.Port = 0 then
      Result.Port := 3306;
    if Result.SchemaName = '' then
      Result.SchemaName := Result.Database;
  end
  else
  begin
    if Result.Port = 0 then
      Result.Port := 1433;
    if Result.SchemaName = '' then
      Result.SchemaName := 'dbo';
  end;
end;

procedure PrintUsage;
begin
  Writeln('FluentORM DTO Generator');
  Writeln('Usage:');
  Writeln('  --db=mysql|sqlserver --server=localhost --port=3306 --database=chat_database');
  Writeln('  --user=root --password=root --schema=dbo --table=usuario --output=.\DTOs');
  Writeln('  --ado_provider=SQLOLEDB');
  Writeln('  --ado_provider_mysql=MSDASQL --mysql_odbc_driver="MySQL ODBC 9.6 Unicode Driver"');
  Writeln('  --connstr="Provider=...;Data Source=...;..."');
  Writeln('  --nullable_mode=native|variant');
  Writeln('Notes:');
  Writeln('  - --table optional. If omitted, generates all tables in schema.');
  Writeln('  - MySQL default schema is database name.');
  Writeln('  - SQL Server default schema is dbo (connection via ADO).');
  Writeln('  - --connstr overrides provider/server/port/database/user/password.');
  Writeln('  - default nullable mode is native.');
end;

function ToPascalIdentifier(const AValue: string): string;
var
  I: Integer;
  S: string;
  MakeUpper: Boolean;
  C: Char;
begin
  S := AValue;
  Result := '';
  MakeUpper := True;
  for I := 1 to Length(S) do
  begin
    C := S[I];
    if (C = '_') or (C = ' ') or (C = '-') then
    begin
      MakeUpper := True;
      Continue;
    end;
    if MakeUpper then
      Result := Result + UpCase(C)
    else
      Result := Result + C;
    MakeUpper := False;
  end;

  if Result = '' then
    Result := 'Field';
  if not (Result[1] in ['A'..'Z', 'a'..'z', '_']) then
    Result := '_' + Result;
end;

function ToPrivateFieldName(const AColumnName: string): string;
begin
  Result := 'F' + ToPascalIdentifier(AColumnName);
end;

function ToPropertyName(const AColumnName: string): string;
begin
  Result := ToPascalIdentifier(AColumnName);
end;

function IsValueType(const ADelphiType: string): Boolean;
begin
  Result :=
    SameText(ADelphiType, 'SmallInt') or
    SameText(ADelphiType, 'Integer') or
    SameText(ADelphiType, 'Int64') or
    SameText(ADelphiType, 'Boolean') or
    SameText(ADelphiType, 'TGuid') or
    SameText(ADelphiType, 'Currency') or
    SameText(ADelphiType, 'Double') or
    SameText(ADelphiType, 'TDateTime') or
    SameText(ADelphiType, 'TTime');
end;

function IsAutoReadOnlyColumn(const AColumnName: string): Boolean;
begin
  Result :=
    SameText(AColumnName, 'data_criacao') or
    SameText(AColumnName, 'data_atualizacao') or
    SameText(AColumnName, 'created_at') or
    SameText(AColumnName, 'updated_at');
end;

function MapDbTypeToDelphi(const ADbType, AColumnType: string; ADbKind: TDbKind): string;
var
  T: string;
  CT: string;
begin
  T := LowerCase(Trim(ADbType));
  CT := LowerCase(Trim(AColumnType));

  if (ADbKind = dbMySQL) and (T = 'tinyint') and (Pos('(1)', CT) > 0) then
    Exit('Boolean');

  if (T = 'tinyint') or (T = 'smallint') then
    Exit('SmallInt');
  if (T = 'int') or (T = 'integer') then
    Exit('Integer');
  if (T = 'bigint') then
    Exit('Int64');
  if (T = 'bit') or (T = 'boolean') or (T = 'bool') then
    Exit('Boolean');
  if (T = 'guid') or (T = 'uniqueidentifier') then
    Exit('TGuid');
  if (T = 'blob') or (T = 'binary') or (T = 'varbinary') or (T = 'image') or
     (T = 'longblob') or (T = 'mediumblob') then
    Exit('TBytes');
  if (T = 'decimal') or (T = 'numeric') or (T = 'money') or (T = 'smallmoney') then
    Exit('Currency');
  if (T = 'float') or (T = 'real') or (T = 'double') or (T = 'double precision') then
    Exit('Double');
  if (T = 'date') or (T = 'datetime') or (T = 'datetime2') or (T = 'smalldatetime') or
     (T = 'timestamp') then
    Exit('TDateTime');
  if (T = 'time') then
    Exit('TTime');
  if (T = 'char') or (T = 'nchar') or (T = 'varchar') or (T = 'nvarchar') or
     (T = 'text') or (T = 'ntext') or (T = 'longtext') or (T = 'mediumtext') then
    Exit('string');

  Result := 'string';
end;

function CreateMySQLADOConnectionString(const Opt: TGeneratorOptions): string;
begin
  if Opt.ConnectionString <> '' then
    Exit(Opt.ConnectionString);

  if SameText(Opt.ADOProviderMySQL, 'MSDASQL') then
  begin
    Result :=
      'Provider=MSDASQL;' +
      'Extended Properties="Driver={' + Opt.MySQLODBCDriver + '};' +
      'Server=' + Opt.Server + ';' +
      'Port=' + Opt.Port.ToString + ';' +
      'Database=' + Opt.Database + ';' +
      'User=' + Opt.UserName + ';' +
      'Password=' + Opt.Password + ';Option=3;"';
  end
  else
  begin
    Result :=
      'Provider=' + Opt.ADOProviderMySQL + ';' +
      'Data Source=' + Opt.Server + ';' +
      'Initial Catalog=' + Opt.Database + ';' +
      'User ID=' + Opt.UserName + ';' +
      'Password=' + Opt.Password + ';' +
      'Persist Security Info=False;';
  end;
end;

function CreateSQLServerADOConnectionString(const Opt: TGeneratorOptions): string;
begin
  if Opt.ConnectionString <> '' then
    Exit(Opt.ConnectionString);

  Result :=
    'Provider=' + Opt.ADOProvider + ';' +
    'Data Source=' + Opt.Server + ',' + Opt.Port.ToString + ';' +
    'Initial Catalog=' + Opt.Database + ';' +
    'User ID=' + Opt.UserName + ';' +
    'Password=' + Opt.Password + ';' +
    'Persist Security Info=False;';
end;

function LoadTablesMySQL(AConn: TADOConnection; const Opt: TGeneratorOptions): TArray<string>;
var
  Q: TADOQuery;
  L: TList<string>;
begin
  L := TList<string>.Create;
  Q := TADOQuery.Create(nil);
  try
    Q.Connection := AConn;
    Q.SQL.Text :=
      'SELECT TABLE_NAME ' +
      'FROM INFORMATION_SCHEMA.TABLES ' +
      'WHERE TABLE_SCHEMA = ' + QuotedStr(Opt.SchemaName) + ' AND TABLE_TYPE = ''BASE TABLE'' ' +
      'ORDER BY TABLE_NAME';
    Q.Open;
    while not Q.Eof do
    begin
      if (Opt.TableName = '') or SameText(Opt.TableName, Q.FieldByName('TABLE_NAME').AsString) then
        L.Add(Q.FieldByName('TABLE_NAME').AsString);
      Q.Next;
    end;
    Result := L.ToArray;
  finally
    Q.Free;
    L.Free;
  end;
end;

function LoadColumnsMySQL(AConn: TADOConnection; const Opt: TGeneratorOptions;
  const ATableName: string): TArray<TColumnMeta>;
var
  Q: TADOQuery;
  L: TList<TColumnMeta>;
  C: TColumnMeta;
begin
  L := TList<TColumnMeta>.Create;
  Q := TADOQuery.Create(nil);
  try
    Q.Connection := AConn;
    Q.SQL.Text :=
      'SELECT COLUMN_NAME, DATA_TYPE, COLUMN_TYPE, COLUMN_KEY, EXTRA, IS_NULLABLE ' +
      'FROM INFORMATION_SCHEMA.COLUMNS ' +
      'WHERE TABLE_SCHEMA = ' + QuotedStr(Opt.SchemaName) +
      '  AND TABLE_NAME = ' + QuotedStr(ATableName) + ' ' +
      'ORDER BY ORDINAL_POSITION';
    Q.Open;
    while not Q.Eof do
    begin
      C.ColumnName := Q.FieldByName('COLUMN_NAME').AsString;
      C.DataType := Q.FieldByName('DATA_TYPE').AsString;
      C.ColumnType := Q.FieldByName('COLUMN_TYPE').AsString;
      C.IsPrimaryKey := SameText(Q.FieldByName('COLUMN_KEY').AsString, 'PRI');
      C.IsIdentity := Pos('auto_increment', LowerCase(Q.FieldByName('EXTRA').AsString)) > 0;
      C.IsNullable := SameText(Q.FieldByName('IS_NULLABLE').AsString, 'YES');
      L.Add(C);
      Q.Next;
    end;

    Result := L.ToArray;
  finally
    Q.Free;
    L.Free;
  end;
end;

function LoadTablesSQLServer(AConn: TADOConnection; const Opt: TGeneratorOptions): TArray<string>;
var
  Q: TADOQuery;
  L: TList<string>;
begin
  L := TList<string>.Create;
  Q := TADOQuery.Create(nil);
  try
    Q.Connection := AConn;
    Q.SQL.Text :=
      'SELECT TABLE_NAME ' +
      'FROM INFORMATION_SCHEMA.TABLES ' +
      'WHERE TABLE_SCHEMA = ' + QuotedStr(Opt.SchemaName) + ' AND TABLE_TYPE = ''BASE TABLE'' ' +
      'ORDER BY TABLE_NAME';
    Q.Open;
    while not Q.Eof do
    begin
      if (Opt.TableName = '') or SameText(Opt.TableName, Q.FieldByName('TABLE_NAME').AsString) then
        L.Add(Q.FieldByName('TABLE_NAME').AsString);
      Q.Next;
    end;
    Result := L.ToArray;
  finally
    Q.Free;
    L.Free;
  end;
end;

function LoadColumnsSQLServer(AConn: TADOConnection; const Opt: TGeneratorOptions;
  const ATableName: string): TArray<TColumnMeta>;
var
  Q: TADOQuery;
  L: TList<TColumnMeta>;
  C: TColumnMeta;
begin
  L := TList<TColumnMeta>.Create;
  Q := TADOQuery.Create(nil);
  try
    Q.Connection := AConn;
    Q.SQL.Text :=
      'SELECT c.COLUMN_NAME, c.DATA_TYPE, c.IS_NULLABLE, ' +
      '       CASE WHEN pk.COLUMN_NAME IS NOT NULL THEN 1 ELSE 0 END AS IS_PK, ' +
      '       COLUMNPROPERTY(OBJECT_ID(c.TABLE_SCHEMA + ''.'' + c.TABLE_NAME), c.COLUMN_NAME, ''IsIdentity'') AS IS_IDENTITY ' +
      'FROM INFORMATION_SCHEMA.COLUMNS c ' +
      'LEFT JOIN ( ' +
      '  SELECT ku.TABLE_SCHEMA, ku.TABLE_NAME, ku.COLUMN_NAME ' +
      '  FROM INFORMATION_SCHEMA.TABLE_CONSTRAINTS tc ' +
      '  JOIN INFORMATION_SCHEMA.KEY_COLUMN_USAGE ku ' +
      '    ON ku.CONSTRAINT_NAME = tc.CONSTRAINT_NAME ' +
      '   AND ku.TABLE_SCHEMA = tc.TABLE_SCHEMA ' +
      '   AND ku.TABLE_NAME = tc.TABLE_NAME ' +
      '  WHERE tc.CONSTRAINT_TYPE = ''PRIMARY KEY'' ' +
      ') pk ON pk.TABLE_SCHEMA = c.TABLE_SCHEMA AND pk.TABLE_NAME = c.TABLE_NAME AND pk.COLUMN_NAME = c.COLUMN_NAME ' +
      'WHERE c.TABLE_SCHEMA = ' + QuotedStr(Opt.SchemaName) +
      '  AND c.TABLE_NAME = ' + QuotedStr(ATableName) + ' ' +
      'ORDER BY c.ORDINAL_POSITION';
    Q.Open;
    while not Q.Eof do
    begin
      C.ColumnName := Q.FieldByName('COLUMN_NAME').AsString;
      C.DataType := Q.FieldByName('DATA_TYPE').AsString;
      C.ColumnType := C.DataType;
      C.IsPrimaryKey := Q.FieldByName('IS_PK').AsInteger = 1;
      C.IsIdentity := Q.FieldByName('IS_IDENTITY').AsInteger = 1;
      C.IsNullable := SameText(Q.FieldByName('IS_NULLABLE').AsString, 'YES');
      L.Add(C);
      Q.Next;
    end;

    Result := L.ToArray;
  finally
    Q.Free;
    L.Free;
  end;
end;

function BuildDtoUnitText(const ATableName: string; const AColumns: TArray<TColumnMeta>;
  ADbKind: TDbKind; ANullableMode: TNullableMode): string;
var
  SL: TStringList;
  ClassName: string;
  UnitName: string;
  I: Integer;
  C: TColumnMeta;
  PropName: string;
  FieldName: string;
  DelphiType: string;
  IsReadOnly: Boolean;
begin
  ClassName := 'T' + ToPascalIdentifier(ATableName) + 'DTO';
  UnitName := 'uDTO_' + ToPascalIdentifier(ATableName);

  SL := TStringList.Create;
  try
    SL.Add('// ------------------------------------------------------------------');
    SL.Add('// Classe gerada automaticamente pelo FluentORM DTO Generator');
    SL.Add('// Data: ' + FormatDateTime('dd/mm/yyyy', Date));
    SL.Add('// Ajuste manualmente conforme necessario.');
    SL.Add('// ------------------------------------------------------------------');
    SL.Add('');
    SL.Add('unit ' + UnitName + ';');
    SL.Add('');
    SL.Add('interface');
    SL.Add('');
    SL.Add('uses');
    SL.Add('  uFluentORM.Attributes;');
    SL.Add('');
    SL.Add('type');
    SL.Add('  [Table(''' + ATableName + ''')]');
    SL.Add('  ' + ClassName + ' = class');
    SL.Add('  private');
    for I := 0 to High(AColumns) do
    begin
      C := AColumns[I];
      FieldName := ToPrivateFieldName(C.ColumnName);
      DelphiType := MapDbTypeToDelphi(C.DataType, C.ColumnType, ADbKind);
      if (ANullableMode = nmVariant) and C.IsNullable and IsValueType(DelphiType) then
        DelphiType := 'Variant';
      SL.Add('    ' + FieldName + ': ' + DelphiType + ';');
    end;
    SL.Add('  public');
    for I := 0 to High(AColumns) do
    begin
      C := AColumns[I];
      PropName := ToPropertyName(C.ColumnName);
      FieldName := ToPrivateFieldName(C.ColumnName);
      DelphiType := MapDbTypeToDelphi(C.DataType, C.ColumnType, ADbKind);
      if (ANullableMode = nmVariant) and C.IsNullable and IsValueType(DelphiType) then
        DelphiType := 'Variant';
      IsReadOnly := IsAutoReadOnlyColumn(C.ColumnName);
      if C.IsPrimaryKey then
        SL.Add('    [Key(' + BoolToLiteral(C.IsIdentity) + ')]');
      if IsReadOnly then
        SL.Add('    [ReadOnly]');
      SL.Add('    [Column(''' + C.ColumnName + ''')]');
      SL.Add('    property ' + PropName + ': ' + DelphiType + ' read ' + FieldName + ' write ' + FieldName + ';');
      SL.Add('');
    end;
    SL.Add('  end;');
    SL.Add('');
    SL.Add('implementation');
    SL.Add('');
    SL.Add('end.');
    Result := SL.Text;
  finally
    SL.Free;
  end;
end;

procedure GenerateDtoUnits(const Opt: TGeneratorOptions);
var
  ADOConn: TADOConnection;
  Tables: TArray<string>;
  TableName: string;
  Cols: TArray<TColumnMeta>;
  UnitText: string;
  FileName: string;
begin
  if not TDirectory.Exists(Opt.OutputDir) then
    TDirectory.CreateDirectory(Opt.OutputDir);

  ADOConn := TADOConnection.Create(nil);
  try
    ADOConn.LoginPrompt := False;
    if Opt.DbKind = dbMySQL then
      ADOConn.ConnectionString := CreateMySQLADOConnectionString(Opt)
    else
      ADOConn.ConnectionString := CreateSQLServerADOConnectionString(Opt);
    ADOConn.Connected := True;

    if Opt.DbKind = dbMySQL then
      Tables := LoadTablesMySQL(ADOConn, Opt)
    else
      Tables := LoadTablesSQLServer(ADOConn, Opt);

    if Length(Tables) = 0 then
      raise Exception.Create('No tables found with provided schema/table filters.');

    for TableName in Tables do
    begin
      if Opt.DbKind = dbMySQL then
        Cols := LoadColumnsMySQL(ADOConn, Opt, TableName)
      else
        Cols := LoadColumnsSQLServer(ADOConn, Opt, TableName);

      UnitText := BuildDtoUnitText(TableName, Cols, Opt.DbKind, Opt.NullableMode);
      FileName := TPath.Combine(Opt.OutputDir, 'uDTO_' + ToPascalIdentifier(TableName) + '.pas');
      TFile.WriteAllText(FileName, UnitText, TEncoding.UTF8);
      Writeln('Generated: ' + FileName);
    end;
  finally
    ADOConn.Free;
  end;
end;

procedure RunGenerator;
var
  Opt: TGeneratorOptions;
  HR: HRESULT;
  COMInitialized: Boolean;
begin
  if ParamCount = 0 then
  begin
    PrintUsage;
    Exit;
  end;

  HR := CoInitialize(nil);
  COMInitialized := HR >= 0;
  try
    Opt := ParseArgs;
    GenerateDtoUnits(Opt);
    Writeln('Done.');
  finally
    if COMInitialized then
      CoUninitialize;
  end;
end;

end.
