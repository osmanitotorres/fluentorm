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

unit uFluentORM.Executor.ADO;

{ Executor ADO (dbGo). Util principalmente para SQL Server em edicoes do Delphi
  que nao trazem o driver FireDAC MSSQL (FireDAC.Phys.MSSQL e exclusivo das
  edicoes Enterprise/Architect). Tambem funciona com MySQL/PostgreSQL via ODBC
  (Provider=MSDASQL), informando o dialeto no construtor.

  Aplicacoes console precisam chamar CoInitialize(nil) antes de usar ADO
  (aplicacoes VCL ja fazem isso em Application.Initialize). }

interface

uses
  System.SysUtils,
  System.StrUtils,
  System.Variants,
  Data.DB,
  Data.Win.ADODB,
  uFluentORM.Types,
  uFluentORM.Executor;

type
  TADOSQLExecutor = class(TInterfacedObject, ISQLExecutor, ISQLDialectInfo,
    ISQLTransactionalExecutor, ISQLIdentityExecutor, ISQLQueryExecutor)
  private
    FConnection: TADOConnection;
    FOwnsConnection: Boolean;
    FDatabaseType: TSQLDatabaseType;
    class function NormalizeParamName(const AName: string): string; static;
    procedure PrepareQuery(AQuery: TADOQuery; const ASQL: string; const AParams: TSQLParams);
  public
    /// <summary> Usa uma conexao existente (nao assume a posse). </summary>
    constructor Create(AConnection: TADOConnection;
      ADatabaseType: TSQLDatabaseType = dbMSSQL);
    /// <summary> Cria e abre uma conexao propria a partir da connection string. </summary>
    constructor CreateFromConnectionString(const AConnectionString: string;
      ADatabaseType: TSQLDatabaseType = dbMSSQL);
    destructor Destroy; override;

    /// <summary>
    /// Monta uma connection string OLE DB para SQL Server.
    /// AProvider: 'MSOLEDBSQL' (recomendado, suporta datetime2/date/time),
    /// 'MSOLEDBSQL19' ou 'SQLOLEDB' (legado, ja vem no Windows).
    /// AUser vazio = autenticacao do Windows.
    /// </summary>
    class function MSSQLConnectionString(const AServer, ADatabase, AUser,
      APassword: string; const AProvider: string = 'MSOLEDBSQL';
      AEncrypt: Boolean = False): string; static;

    function Execute(const ASQL: string; const AParams: TSQLParams): Integer;
    function ExecuteScalar(const ASQL: string; const AParams: TSQLParams): Variant;
    /// <summary> Abre um SELECT; quem chama libera o dataset. </summary>
    function OpenQuery(const ASQL: string; const AParams: TSQLParams): TADOQuery;
    function OpenDataSet(const ASQL: string; const AParams: TSQLParams): TDataSet;
    function GetDatabaseType: TSQLDatabaseType;
    function GetLastInsertedId: Variant;
    procedure BeginTransaction;
    procedure Commit;
    procedure Rollback;
    function InTransaction: Boolean;
    property Connection: TADOConnection read FConnection;
  end;

implementation

{ TADOSQLExecutor }

constructor TADOSQLExecutor.Create(AConnection: TADOConnection;
  ADatabaseType: TSQLDatabaseType);
begin
  inherited Create;
  if AConnection = nil then
    raise Exception.Create('TADOConnection cannot be nil.');
  FConnection := AConnection;
  FOwnsConnection := False;
  FDatabaseType := ADatabaseType;
end;

constructor TADOSQLExecutor.CreateFromConnectionString(
  const AConnectionString: string; ADatabaseType: TSQLDatabaseType);
begin
  inherited Create;
  FDatabaseType := ADatabaseType;
  FConnection := TADOConnection.Create(nil);
  FOwnsConnection := True;
  FConnection.LoginPrompt := False;
  FConnection.ConnectionString := AConnectionString;
  FConnection.Connected := True;
end;

destructor TADOSQLExecutor.Destroy;
begin
  if FOwnsConnection and Assigned(FConnection) then
  begin
    try
      if FConnection.InTransaction then
        FConnection.RollbackTrans;
    except
      // Destructor must not raise exceptions.
    end;
    try
      FConnection.Connected := False;
    except
      // Destructor must not raise exceptions.
    end;
    FConnection.Free;
    FConnection := nil;
  end;
  inherited;
end;

class function TADOSQLExecutor.MSSQLConnectionString(const AServer, ADatabase,
  AUser, APassword: string; const AProvider: string; AEncrypt: Boolean): string;
begin
  Result := 'Provider=' + AProvider + ';Data Source=' + AServer +
    ';Initial Catalog=' + ADatabase + ';';
  if Trim(AUser) = '' then
    Result := Result + 'Integrated Security=SSPI;'
  else
    Result := Result + 'User ID=' + AUser + ';Password=' + APassword + ';';
  Result := Result + 'Persist Security Info=False;';

  if StartsText('MSOLEDBSQL', AProvider) then
  begin
    // MSOLEDBSQL 19 criptografa por padrao; sem certificado valido a conexao
    // local falha. "DataTypeCompatibility=0" mantem date/time/datetime2 nativos.
    if AEncrypt then
      Result := Result + 'Use Encryption for Data=Mandatory;'
    else
      Result := Result + 'Use Encryption for Data=Optional;';
    Result := Result + 'Trust Server Certificate=True;';
  end;
end;

class function TADOSQLExecutor.NormalizeParamName(const AName: string): string;
begin
  Result := AName;
  if (Result <> '') and ((Result[1] = ':') or (Result[1] = '@')) then
    Delete(Result, 1, 1);
end;

procedure TADOSQLExecutor.PrepareQuery(AQuery: TADOQuery; const ASQL: string;
  const AParams: TSQLParams);
var
  I: Integer;
  P: TParameter;
  V: Variant;
  S: string;
begin
  AQuery.Connection := FConnection;
  AQuery.ParamCheck := True;
  AQuery.SQL.Text := ASQL;
  for I := 0 to High(AParams) do
  begin
    P := AQuery.Parameters.ParamByName(NormalizeParamName(AParams[I].Name));
    V := AParams[I].Value;
    if VarIsEmpty(V) then
      V := Null;

    if AParams[I].DataType <> ftUnknown then
      P.DataType := AParams[I].DataType
    else if VarIsNull(V) then
      P.DataType := ftWideString;

    // ADO exige Size para tipos de tamanho variavel.
    if VarIsNull(V) then
    begin
      if P.Size <= 0 then
        P.Size := 1;
    end
    else if VarIsArray(V) then
      P.Size := VarArrayHighBound(V, 1) - VarArrayLowBound(V, 1) + 1
    else if VarIsStr(V) then
    begin
      S := VarToStr(V);
      if Length(S) > 0 then
        P.Size := Length(S)
      else
        P.Size := 1;
    end;

    P.Value := V;
  end;
end;

function TADOSQLExecutor.Execute(const ASQL: string; const AParams: TSQLParams): Integer;
var
  Q: TADOQuery;
begin
  Q := TADOQuery.Create(nil);
  try
    PrepareQuery(Q, ASQL, AParams);
    Result := Q.ExecSQL;
  finally
    Q.Free;
  end;
end;

function TADOSQLExecutor.ExecuteScalar(const ASQL: string;
  const AParams: TSQLParams): Variant;
var
  Q: TADOQuery;
begin
  Q := TADOQuery.Create(nil);
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

function TADOSQLExecutor.OpenQuery(const ASQL: string;
  const AParams: TSQLParams): TADOQuery;
begin
  Result := TADOQuery.Create(nil);
  try
    PrepareQuery(Result, ASQL, AParams);
    Result.Open;
  except
    Result.Free;
    raise;
  end;
end;

function TADOSQLExecutor.OpenDataSet(const ASQL: string;
  const AParams: TSQLParams): TDataSet;
begin
  Result := OpenQuery(ASQL, AParams);
end;

function TADOSQLExecutor.GetDatabaseType: TSQLDatabaseType;
begin
  Result := FDatabaseType;
end;

function TADOSQLExecutor.GetLastInsertedId: Variant;
begin
  case FDatabaseType of
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

procedure TADOSQLExecutor.BeginTransaction;
begin
  if not FConnection.InTransaction then
    FConnection.BeginTrans;
end;

procedure TADOSQLExecutor.Commit;
begin
  if FConnection.InTransaction then
    FConnection.CommitTrans;
end;

procedure TADOSQLExecutor.Rollback;
begin
  if FConnection.InTransaction then
    FConnection.RollbackTrans;
end;

function TADOSQLExecutor.InTransaction: Boolean;
begin
  Result := FConnection.InTransaction;
end;

end.
