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

unit uFluentORM.Executor;

interface

uses
  System.SysUtils,
  System.Variants,
  Data.DB,
  uFluentORM.Types;

type
  ISQLExecutor = interface
    ['{07B5F295-E165-466E-BB35-0F08E08AA93A}']
    function Execute(const ASQL: string; const AParams: TSQLParams): Integer;
    function ExecuteScalar(const ASQL: string; const AParams: TSQLParams): Variant;
  end;

  ISQLDriverInfo = interface(ISQLExecutor)
    ['{8B9700E9-0D93-4E32-92F8-BA13E4CF3D3E}']
    function GetDriverID: string;
  end;

  ISQLTransactionalExecutor = interface(ISQLExecutor)
    ['{FBAA3D34-F2FA-4787-B122-B177E0DE37A8}']
    procedure BeginTransaction;
    procedure Commit;
    procedure Rollback;
    function InTransaction: Boolean;
  end;

  ISQLIdentityExecutor = interface(ISQLExecutor)
    ['{759E08F9-97C3-49A3-8A02-64EB3C44679F}']
    function GetLastInsertedId: Variant;
  end;

  /// <summary>
  /// Optional capability: opens a SELECT and returns the dataset (the caller
  /// owns and frees it). Required by TRepository<T>.FindById/FindAll.
  /// </summary>
  ISQLQueryExecutor = interface(ISQLExecutor)
    ['{3E7C1F52-8B44-4D7A-A6B1-2F0D9C5E7A13}']
    function OpenDataSet(const ASQL: string; const AParams: TSQLParams): TDataSet;
  end;

  /// <summary>
  /// Optional capability: informs the SQL dialect of the connection so the
  /// repository can quote identifiers and choose the identity retrieval
  /// strategy (RETURNING / OUTPUT INSERTED / LAST_INSERT_ID) correctly.
  /// Executors that do not implement it fall back to ISQLDriverInfo.
  /// </summary>
  ISQLDialectInfo = interface
    ['{C2A5E0A1-4D0E-4A3B-9D5E-6F1B7C8D9E20}']
    function GetDatabaseType: TSQLDatabaseType;
  end;

  TSQLTransaction = class
  public
    class function HasTransactionSupport(const AExecutor: ISQLExecutor): Boolean; static;
    class procedure ExecuteInTransaction(const AExecutor: ISQLExecutor; const AProc: TProc); static;
  end;

function SQLParam(const AName: string; const AValue: Variant): TSQLParam; overload;
function SQLParam(const AName: string; const AValue: Variant;
  ADataType: TFieldType): TSQLParam; overload;

implementation

class function TSQLTransaction.HasTransactionSupport(const AExecutor: ISQLExecutor): Boolean;
var
  Tx: ISQLTransactionalExecutor;
begin
  Result := Assigned(AExecutor) and Supports(AExecutor, ISQLTransactionalExecutor, Tx);
end;

class procedure TSQLTransaction.ExecuteInTransaction(const AExecutor: ISQLExecutor;
  const AProc: TProc);
var
  Tx: ISQLTransactionalExecutor;
  StartedHere: Boolean;
begin
  if not Assigned(AExecutor) then
    raise Exception.Create('AExecutor cannot be nil.');
  if not Assigned(AProc) then
    raise Exception.Create('AProc cannot be nil.');

  if not Supports(AExecutor, ISQLTransactionalExecutor, Tx) then
  begin
    AProc();
    Exit;
  end;

  StartedHere := not Tx.InTransaction;
  if StartedHere then
    Tx.BeginTransaction;

  try
    AProc();
    if StartedHere then
      Tx.Commit;
  except
    if StartedHere and Tx.InTransaction then
      Tx.Rollback;
    raise;
  end;
end;

function SQLParam(const AName: string; const AValue: Variant): TSQLParam;
begin
  Result.Name := AName;
  Result.Value := AValue;
  Result.DataType := ftUnknown;
end;

function SQLParam(const AName: string; const AValue: Variant;
  ADataType: TFieldType): TSQLParam;
begin
  Result.Name := AName;
  Result.Value := AValue;
  Result.DataType := ADataType;
end;

end.
