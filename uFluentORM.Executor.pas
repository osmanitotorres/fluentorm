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
  uFluentORM.Types;

type
  ISQLExecutor = interface
    ['{07B5F295-E165-466E-BB35-0F08E08AA93A}']
    function Execute(const ASQL: string; const AParams: TSQLParams): Integer;
    function ExecuteScalar(const ASQL: string; const AParams: TSQLParams): Variant;
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

  TSQLTransaction = class
  public
    class function HasTransactionSupport(const AExecutor: ISQLExecutor): Boolean; static;
    class procedure ExecuteInTransaction(const AExecutor: ISQLExecutor; const AProc: TProc); static;
  end;

function SQLParam(const AName: string; const AValue: Variant): TSQLParam;

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
end;

end.
