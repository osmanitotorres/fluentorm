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

unit uFluentORM.Executor.UniDAC;

{ Executor para Devart UniDAC (Universal Data Access Components).

  Requisitos:
  - UniDAC instalado (units Uni, DBAccess, MemDS, UniProvider);
  - o provider de cada banco usado declarado no projeto, por exemplo:
      uses MySQLUniProvider, SQLServerUniProvider, PostgreSQLUniProvider;
    (sem o provider, o UniDAC gera "Provider is not defined").

  O dialeto do FluentORM e deduzido de TUniConnection.ProviderName
  ('MySQL', 'SQL Server', 'PostgreSQL', 'InterBase', 'SQLite'...) ou pode ser
  informado no construtor.

  Observacao: esta unit NAO faz parte do build.bat porque depende do UniDAC. }

interface

uses
  System.SysUtils,
  System.Variants,
  Data.DB,
  DBAccess,
  Uni,
  uFluentORM.Types,
  uFluentORM.Executor;

type
  TUniDACSQLExecutor = class(TInterfacedObject, ISQLExecutor, ISQLDriverInfo,
    ISQLDialectInfo, ISQLTransactionalExecutor, ISQLIdentityExecutor, ISQLQueryExecutor)
  private
    FConnection: TUniConnection;
    FOwnsConnection: Boolean;
    FDatabaseType: TSQLDatabaseType;
    FDialectForced: Boolean;
    class function NormalizeParamName(const AName: string): string; static;
    procedure PrepareQuery(AQuery: TUniQuery; const ASQL: string; const AParams: TSQLParams);
  public
    /// <summary>
    /// Usa uma conexao existente (nao assume a posse). O dialeto vem do
    /// ProviderName da conexao.
    /// </summary>
    constructor Create(AConnection: TUniConnection); overload;
    /// <summary> Usa uma conexao existente informando o dialeto explicitamente. </summary>
    constructor Create(AConnection: TUniConnection; ADatabaseType: TSQLDatabaseType); overload;
    /// <summary>
    /// Cria e abre uma conexao propria.
    /// AProviderName: 'MySQL', 'SQL Server', 'PostgreSQL', 'InterBase', 'SQLite'...
    /// Para MySQL liga o modo Direct (dispensa a libmysql.dll).
    /// APort = 0 usa a porta padrao do provider.
    /// </summary>
    constructor CreateConnected(const AProviderName, AServer: string; APort: Integer;
      const ADatabase, AUser, APassword: string);
    destructor Destroy; override;

    function Execute(const ASQL: string; const AParams: TSQLParams): Integer;
    function ExecuteScalar(const ASQL: string; const AParams: TSQLParams): Variant;
    /// <summary> Abre um SELECT; quem chama libera o dataset. </summary>
    function OpenQuery(const ASQL: string; const AParams: TSQLParams): TUniQuery;
    function OpenDataSet(const ASQL: string; const AParams: TSQLParams): TDataSet;
    function GetDriverID: string;
    function GetDatabaseType: TSQLDatabaseType;
    function GetLastInsertedId: Variant;
    procedure BeginTransaction;
    procedure Commit;
    procedure Rollback;
    function InTransaction: Boolean;
    property Connection: TUniConnection read FConnection;
  end;

implementation

{ TUniDACSQLExecutor }

constructor TUniDACSQLExecutor.Create(AConnection: TUniConnection);
begin
  inherited Create;
  if AConnection = nil then
    raise Exception.Create('TUniConnection cannot be nil.');
  FConnection := AConnection;
  FOwnsConnection := False;
  FDialectForced := False;
end;

constructor TUniDACSQLExecutor.Create(AConnection: TUniConnection;
  ADatabaseType: TSQLDatabaseType);
begin
  Create(AConnection);
  FDatabaseType := ADatabaseType;
  FDialectForced := True;
end;

constructor TUniDACSQLExecutor.CreateConnected(const AProviderName, AServer: string;
  APort: Integer; const ADatabase, AUser, APassword: string);
begin
  inherited Create;
  FDialectForced := False;
  FConnection := TUniConnection.Create(nil);
  FOwnsConnection := True;
  try
    FConnection.LoginPrompt := False;
    FConnection.ProviderName := AProviderName;
    FConnection.Server := AServer;
    if APort > 0 then
      FConnection.Port := APort;
    FConnection.Database := ADatabase;
    FConnection.Username := AUser;
    FConnection.Password := APassword;

    if SameText(AProviderName, 'MySQL') then
    begin
      // Protocolo nativo do UniDAC: nao precisa da libmysql.dll.
      FConnection.SpecificOptions.Values['MySQL.Direct'] := 'True';
      FConnection.SpecificOptions.Values['MySQL.UseUnicode'] := 'True';
    end
    else if SameText(AProviderName, 'PostgreSQL') then
      FConnection.SpecificOptions.Values['PostgreSQL.UseUnicode'] := 'True';

    FConnection.Connected := True;
  except
    FreeAndNil(FConnection);
    raise;
  end;
end;

destructor TUniDACSQLExecutor.Destroy;
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
      FConnection.Connected := False;
    except
      // Destructor must not raise exceptions.
    end;
    FreeAndNil(FConnection);
  end;
  inherited;
end;

class function TUniDACSQLExecutor.NormalizeParamName(const AName: string): string;
begin
  Result := AName;
  if (Result <> '') and ((Result[1] = ':') or (Result[1] = '@')) then
    Delete(Result, 1, 1);
end;

procedure TUniDACSQLExecutor.PrepareQuery(AQuery: TUniQuery; const ASQL: string;
  const AParams: TSQLParams);
var
  I: Integer;
  P: TDAParam;
  V: Variant;
begin
  AQuery.Connection := FConnection;
  AQuery.ParamCheck := True;
  AQuery.SQL.Text := ASQL;
  for I := 0 to High(AParams) do
  begin
    P := AQuery.ParamByName(NormalizeParamName(AParams[I].Name));
    V := AParams[I].Value;
    if VarIsEmpty(V) then
      V := Null;

    if AParams[I].DataType <> ftUnknown then
      P.DataType := AParams[I].DataType
    else if VarIsNull(V) then
      // NULL sem tipo: evita "Unknown data type" no prepare.
      P.DataType := ftWideString;

    if VarIsNull(V) then
      P.Clear
    else
      P.Value := V;
  end;
end;

function TUniDACSQLExecutor.Execute(const ASQL: string; const AParams: TSQLParams): Integer;
var
  Q: TUniQuery;
begin
  Q := TUniQuery.Create(nil);
  try
    PrepareQuery(Q, ASQL, AParams);
    Q.Execute;
    Result := Q.RowsAffected;
  finally
    Q.Free;
  end;
end;

function TUniDACSQLExecutor.ExecuteScalar(const ASQL: string;
  const AParams: TSQLParams): Variant;
var
  Q: TUniQuery;
begin
  Q := TUniQuery.Create(nil);
  try
    PrepareQuery(Q, ASQL, AParams);
    Q.Open;
    if (Q.FieldCount > 0) and not Q.Eof then
      Result := Q.Fields[0].Value
    else
      Result := Null;
  finally
    Q.Free;
  end;
end;

function TUniDACSQLExecutor.OpenQuery(const ASQL: string;
  const AParams: TSQLParams): TUniQuery;
begin
  Result := TUniQuery.Create(nil);
  try
    PrepareQuery(Result, ASQL, AParams);
    Result.Open;
  except
    Result.Free;
    raise;
  end;
end;

function TUniDACSQLExecutor.OpenDataSet(const ASQL: string;
  const AParams: TSQLParams): TDataSet;
begin
  Result := OpenQuery(ASQL, AParams);
end;

function TUniDACSQLExecutor.GetDriverID: string;
begin
  Result := FConnection.ProviderName;
end;

function TUniDACSQLExecutor.GetDatabaseType: TSQLDatabaseType;
begin
  if FDialectForced then
    Result := FDatabaseType
  else
    // 'MySQL' -> dbMySQL, 'SQL Server' -> dbMSSQL, 'PostgreSQL' -> dbPostgreSQL,
    // 'InterBase' -> dbFirebird, 'SQLite' -> dbSQLite; demais -> dbGeneric.
    Result := TSQLDialect.FromDriverID(FConnection.ProviderName);
end;

function TUniDACSQLExecutor.GetLastInsertedId: Variant;
begin
  case GetDatabaseType of
    dbMySQL:
      Result := ExecuteScalar('SELECT LAST_INSERT_ID()', []);
    dbPostgreSQL:
      Result := ExecuteScalar('SELECT LASTVAL()', []);
    dbMSSQL:
      // O TRepository nao depende disto no SQL Server (usa OUTPUT ... INTO).
      Result := ExecuteScalar('SELECT CAST(@@IDENTITY AS BIGINT)', []);
    dbSQLite:
      Result := ExecuteScalar('SELECT last_insert_rowid()', []);
  else
    Result := Null;
  end;
end;

procedure TUniDACSQLExecutor.BeginTransaction;
begin
  if not FConnection.InTransaction then
    FConnection.StartTransaction;
end;

procedure TUniDACSQLExecutor.Commit;
begin
  if FConnection.InTransaction then
    FConnection.Commit;
end;

procedure TUniDACSQLExecutor.Rollback;
begin
  if FConnection.InTransaction then
    FConnection.Rollback;
end;

function TUniDACSQLExecutor.InTransaction: Boolean;
begin
  Result := FConnection.InTransaction;
end;

end.
