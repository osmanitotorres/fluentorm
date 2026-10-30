{******************************************************************************}
{                                                                              }
{  FluentORM                                                                   }
{  --------------------------------------------------------------------------  }
{  Minimalist and high-performance Micro ORM for Delphi                        }
{                                                                              }
{  Author: Osmanito Torres                                                     }
{                                                                              }
{  Description:                                                                }
{    FluentORM is a lightweight and efficient micro-ORM designed to provide    }
{    type-safe CRUD operations, SQL generation, and metadata-based mapping     }
{    for Delphi applications. It emphasizes simplicity, performance, and       }
{    explicit behavior over hidden abstractions.                               }
{                                                                              }
{    The framework includes:                                                   }
{      - Fluent SQL Builder                                                    }
{      - Generic Repository pattern                                            }
{      - Metadata caching via RTTI                                             }
{      - Transaction support                                                   }
{      - Multi-database dialect handling                                       }
{                                                                              }
{  Disclaimer:                                                                 }
{    This software is provided "as is", without warranty of any kind,          }
{    express or implied, including but not limited to the warranties of        }
{    merchantability, fitness for a particular purpose and noninfringement.    }
{                                                                              }
{    The author assumes no responsibility or liability for any damages         }
{    arising from the use of this component in any environment, including      }
{    production systems. Use at your own risk.                                 }
{                                                                              }
{  Notes:                                                                      }
{    This component was designed with a minimalist philosophy and does not     }
{    aim to replicate the complexity of full-scale ORM frameworks.             }
{                                                                              }
{******************************************************************************}

unit uFluentORM.Executor.FireDAC;

interface

uses
  System.SysUtils,
  System.StrUtils,
  System.Variants,
  Data.DB,
  FireDAC.Stan.Param,
  FireDAC.Comp.Client,
  uFluentORM.Types,
  uFluentORM.Executor;

type
  IFireDACConnectionFactory = interface
    ['{EA786B5F-BF87-470E-BD14-903F71F3CD1C}']
    function CreateConnection: TFDConnection;
  end;

  TFireDACSQLExecutor = class(TInterfacedObject, ISQLExecutor, ISQLDriverInfo, ISQLDialectInfo,
    ISQLTransactionalExecutor, ISQLIdentityExecutor, ISQLQueryExecutor)
  private
    FConnection: TFDConnection;
    FOwnsConnection: Boolean;
    class function NormalizeParamName(const AName: string): string; static;
    function ExecuteScalarNoParams(const ASQL: string): Variant;
    procedure BindParams(AQuery: TFDQuery; const AParams: TSQLParams);
  public
    // Normaliza o DriverID do FireDAC (inclusive drivers customizados, ex.:
    // 'MySQL8', 'MSSQL2019', 'PG_Prod') para: MYSQL, MSSQL, PG, SQLITE, FB...
    class function NormalizeDriverID(const ADriverID: string): string; static;
  public
    constructor Create(AConnection: TFDConnection);
    constructor CreateFromFactory(const AConnectionFactory: IFireDACConnectionFactory);
    destructor Destroy; override;
    function Execute(const ASQL: string; const AParams: TSQLParams): Integer;
    function ExecuteScalar(const ASQL: string; const AParams: TSQLParams): Variant;
    function GetDriverID: string;
    function GetDatabaseType: TSQLDatabaseType;
    /// <summary>
    /// Opens a SELECT and returns the dataset (the caller owns and frees it).
    /// Typical use with the builder:
    ///   SQLText := Builder.ToSQL;
    ///   Q := Exec.OpenQuery(SQLText, Builder.ToSQLParams);
    /// </summary>
    function OpenQuery(const ASQL: string; const AParams: TSQLParams): TFDQuery;
    function OpenDataSet(const ASQL: string; const AParams: TSQLParams): TDataSet;
    property Connection: TFDConnection read FConnection;
    function GetLastInsertedId: Variant;
    procedure BeginTransaction;
    procedure Commit;
    procedure Rollback;
    function InTransaction: Boolean;
  end;

implementation

constructor TFireDACSQLExecutor.Create(AConnection: TFDConnection);
begin
  inherited Create;
  if AConnection = nil then
    raise Exception.Create('TFDConnection cannot be nil.');
  FConnection := AConnection;
  FOwnsConnection := False;
end;

constructor TFireDACSQLExecutor.CreateFromFactory(
  const AConnectionFactory: IFireDACConnectionFactory);
begin
  inherited Create;
  if not Assigned(AConnectionFactory) then
    raise Exception.Create('IFireDACConnectionFactory cannot be nil.');
  FConnection := AConnectionFactory.CreateConnection;
  if FConnection = nil then
    raise Exception.Create('Connection factory returned nil.');
  FOwnsConnection := True;
end;

destructor TFireDACSQLExecutor.Destroy;
begin
  if FOwnsConnection and Assigned(FConnection) then
  begin
    try
      if FConnection.InTransaction then
        FConnection.Rollback;
    except
      // Destructor must not raise exceptions.
    end;

    try
      if FConnection.Connected then
        FConnection.Connected := False;
    except
      // Destructor must not raise exceptions.
    end;

    FConnection.Free;
    FConnection := nil;
  end;
  inherited;
end;

class function TFireDACSQLExecutor.NormalizeParamName(const AName: string): string;
begin
  Result := AName;
  if Result = '' then
    Exit;
  if (Result[1] = ':') or (Result[1] = '@') then
    Delete(Result, 1, 1);
end;

function NormalizeGuidText(const AValue: string): string;
begin
  Result := Trim(AValue);
  if (Result <> '') and (Result[1] <> '{') then
    Result := '{' + Result + '}';
end;

procedure TFireDACSQLExecutor.BindParams(AQuery: TFDQuery; const AParams: TSQLParams);
var
  I: Integer;
  P: TFDParam;
begin
  for I := 0 to High(AParams) do
  begin
    P := AQuery.ParamByName(NormalizeParamName(AParams[I].Name));
    if AParams[I].DataType <> ftUnknown then
      P.DataType := AParams[I].DataType
    else if VarIsNull(AParams[I].Value) or VarIsEmpty(AParams[I].Value) then
      // NULL sem tipo gera "[FireDAC] Param data type is unknown".
      P.DataType := ftWideString;
    if VarIsNull(AParams[I].Value) or VarIsEmpty(AParams[I].Value) then
      P.Clear
    else if (P.DataType = ftGuid) and VarIsStr(AParams[I].Value) then
      P.AsGUID := StringToGUID(NormalizeGuidText(VarToStr(AParams[I].Value)))
    else
      P.Value := AParams[I].Value;
  end;
end;

function TFireDACSQLExecutor.Execute(const ASQL: string; const AParams: TSQLParams): Integer;
var
  Q: TFDQuery;
begin
  Q := TFDQuery.Create(nil);
  try
    Q.Connection := FConnection;
    Q.SQL.Text := ASQL;
    BindParams(Q, AParams);
    Q.ExecSQL;
    Result := Q.RowsAffected;
  finally
    Q.Free;
  end;
end;

function TFireDACSQLExecutor.ExecuteScalar(const ASQL: string;
  const AParams: TSQLParams): Variant;
var
  Q: TFDQuery;
begin
  Q := TFDQuery.Create(nil);
  try
    Q.Connection := FConnection;
    Q.SQL.Text := ASQL;
    BindParams(Q, AParams);
    Q.Open;
    if not Q.Eof then
      Result := Q.Fields[0].Value
    else
      Result := Null;
  finally
    Q.Free;
  end;
end;

function TFireDACSQLExecutor.OpenQuery(const ASQL: string;
  const AParams: TSQLParams): TFDQuery;
begin
  Result := TFDQuery.Create(nil);
  try
    Result.Connection := FConnection;
    Result.SQL.Text := ASQL;
    BindParams(Result, AParams);
    Result.Open;
  except
    Result.Free;
    raise;
  end;
end;

function TFireDACSQLExecutor.OpenDataSet(const ASQL: string;
  const AParams: TSQLParams): TDataSet;
begin
  Result := OpenQuery(ASQL, AParams);
end;

function TFireDACSQLExecutor.ExecuteScalarNoParams(const ASQL: string): Variant;
begin
  Result := ExecuteScalar(ASQL, []);
end;

function TFireDACSQLExecutor.GetLastInsertedId: Variant;
begin
  case GetDatabaseType of
    dbMySQL:
      Result := ExecuteScalarNoParams('SELECT LAST_INSERT_ID()');
    dbPostgreSQL:
      Result := ExecuteScalarNoParams('SELECT LASTVAL()');
    // SCOPE_IDENTITY() executed in another command/batch returns NULL on SQL
    // Server (each query runs in its own scope). @@IDENTITY is session scoped.
    // TRepository uses "INSERT ... OUTPUT INSERTED.<pk>" for SQL Server and
    // does not depend on this method there.
    dbMSSQL:
      Result := ExecuteScalarNoParams('SELECT CAST(@@IDENTITY AS BIGINT)');
    dbSQLite:
      Result := ExecuteScalarNoParams('SELECT last_insert_rowid()');
  else
    // Firebird/Oracle/generic ODBC do not have a portable session function.
    // (The repository currently uses RETURNING only for PostgreSQL; Firebird
    // callers that need the key should implement ISQLIdentityExecutor.)
    Result := Null;
  end;
end;

function TFireDACSQLExecutor.GetDatabaseType: TSQLDatabaseType;
begin
  Result := TSQLDialect.FromDriverID(GetDriverID);
end;

class function TFireDACSQLExecutor.NormalizeDriverID(const ADriverID: string): string;
begin
  Result := UpperCase(Trim(ADriverID));
  if StartsText('MYSQL', Result) or StartsText('MARIA', Result) then
    Result := 'MYSQL'
  else if StartsText('MSSQL', Result) or StartsText('SQLSERVER', Result) then
    Result := 'MSSQL'
  else if StartsText('PG', Result) or StartsText('POSTGRE', Result) then
    Result := 'PG'
  else if StartsText('SQLITE', Result) then
    Result := 'SQLITE'
  else if StartsText('FB', Result) or StartsText('FIREBIRD', Result) then
    Result := 'FB';
end;

function TFireDACSQLExecutor.GetDriverID: string;
var
  Raw: string;
begin
  // Params.Values['DriverID'] fica vazio quando a conexao usa
  // ConnectionDefName (caso do pool). DriverName resolve pelo ConnectionDef.
  Raw := '';
  try
    Raw := FConnection.DriverName;
  except
    Raw := '';
  end;
  if Trim(Raw) = '' then
    Raw := FConnection.Params.Values['DriverID'];
  if (Trim(Raw) = '') and (FConnection.ConnectionDefName <> '') then
    Raw := FDManager.ConnectionDefs.ConnectionDefByName(
      FConnection.ConnectionDefName).Params.Values['DriverID'];
  Result := NormalizeDriverID(Raw);
end;

procedure TFireDACSQLExecutor.BeginTransaction;
begin
  if not FConnection.InTransaction then
    FConnection.StartTransaction;
end;

procedure TFireDACSQLExecutor.Commit;
begin
  if FConnection.InTransaction then
    FConnection.Commit;
end;

procedure TFireDACSQLExecutor.Rollback;
begin
  if FConnection.InTransaction then
    FConnection.Rollback;
end;

function TFireDACSQLExecutor.InTransaction: Boolean;
begin
  Result := FConnection.InTransaction;
end;

end.
