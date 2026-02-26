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
  System.Variants,
  FireDAC.Comp.Client,
  uFluentORM.Types,
  uFluentORM.Executor;

type
  IFireDACConnectionFactory = interface
    ['{EA786B5F-BF87-470E-BD14-903F71F3CD1C}']
    function CreateConnection: TFDConnection;
  end;

  TFireDACSQLExecutor = class(TInterfacedObject, ISQLExecutor, ISQLDriverInfo, ISQLTransactionalExecutor, ISQLIdentityExecutor)
  private
    FConnection: TFDConnection;
    FOwnsConnection: Boolean;
    class function NormalizeParamName(const AName: string): string; static;
    function ExecuteScalarNoParams(const ASQL: string): Variant;
  public
    constructor Create(AConnection: TFDConnection);
    constructor CreateFromFactory(const AConnectionFactory: IFireDACConnectionFactory);
    destructor Destroy; override;
    function Execute(const ASQL: string; const AParams: TSQLParams): Integer;
    function ExecuteScalar(const ASQL: string; const AParams: TSQLParams): Variant;
    function GetDriverID: string;
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

function TFireDACSQLExecutor.Execute(const ASQL: string; const AParams: TSQLParams): Integer;
var
  Q: TFDQuery;
  I: Integer;
begin
  Q := TFDQuery.Create(nil);
  try
    Q.Connection := FConnection;
    Q.SQL.Text := ASQL;
    for I := 0 to High(AParams) do
      Q.ParamByName(NormalizeParamName(AParams[I].Name)).Value := AParams[I].Value;
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
  I: Integer;
begin
  Q := TFDQuery.Create(nil);
  try
    Q.Connection := FConnection;
    Q.SQL.Text := ASQL;
    for I := 0 to High(AParams) do
      Q.ParamByName(NormalizeParamName(AParams[I].Name)).Value := AParams[I].Value;
    Q.Open;
    if not Q.Eof then
      Result := Q.Fields[0].Value
    else
      Result := Null;
  finally
    Q.Free;
  end;
end;

function TFireDACSQLExecutor.ExecuteScalarNoParams(const ASQL: string): Variant;
begin
  Result := ExecuteScalar(ASQL, []);
end;

function TFireDACSQLExecutor.GetLastInsertedId: Variant;
var
  DriverID: string;
begin
  DriverID := GetDriverID;

  if DriverID = 'MYSQL' then
    Exit(ExecuteScalarNoParams('SELECT LAST_INSERT_ID()'));

  if (DriverID = 'MSSQL') or (DriverID = 'ODBC') then
    Exit(ExecuteScalarNoParams('SELECT SCOPE_IDENTITY()'));

  if DriverID = 'PG' then
    Exit(ExecuteScalarNoParams('SELECT LASTVAL()'));

  if DriverID = 'SQLITE' then
    Exit(ExecuteScalarNoParams('SELECT last_insert_rowid()'));

  Exit(ExecuteScalarNoParams('SELECT @@IDENTITY'));
end;

function TFireDACSQLExecutor.GetDriverID: string;
begin
  Result := UpperCase(Trim(FConnection.Params.Values['DriverID']));
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
