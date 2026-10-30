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

unit uFluentORM.ConnectionPool.FireDAC;

interface

uses
  System.SysUtils,
  System.Classes,
  System.Generics.Collections,
  FireDAC.Comp.Client,
  uFluentORM.Executor.FireDAC;

type
  TFireDACPoolOptions = record
    Pooled: Boolean;
    MaximumItems: Integer;
    ExpireTimeout: Integer;
    CleanupTimeout: Integer;
    class function Default: TFireDACPoolOptions; static;
  end;

  TFireDACPooledConnectionFactory = class(TInterfacedObject, IFireDACConnectionFactory)
  private
    FParams: TStringList;
    FConnectionDefName: string;
    class var FLock: TObject;
    class var FRegistry: TDictionary<string, string>;
    class var FCreatedDefs: TStringList;
    class var FDefCounter: Integer;
    class constructor CreateClass;
    class destructor DestroyClass;
    class function BuildRegistryKey(const ABaseParams: TStrings;
      const APoolOptions: TFireDACPoolOptions): string; static;
    class function EnsureSharedConnectionDef(const ABaseParams: TStrings;
      const APoolOptions: TFireDACPoolOptions): string; static;
  public
    constructor Create(const ABaseParams: TStrings;
      const APoolOptions: TFireDACPoolOptions);
    destructor Destroy; override;
    function CreateConnection: TFDConnection;
  end;

implementation

{ TFireDACPoolOptions }

class function TFireDACPoolOptions.Default: TFireDACPoolOptions;
begin
  Result.Pooled := True;
  Result.MaximumItems := 50;
  Result.ExpireTimeout := 90000;
  Result.CleanupTimeout := 30000;
end;

{ TFireDACPooledConnectionFactory }

class constructor TFireDACPooledConnectionFactory.CreateClass;
begin
  FLock := TObject.Create;
  FRegistry := TDictionary<string, string>.Create;
  FCreatedDefs := TStringList.Create;
  FCreatedDefs.CaseSensitive := False;
  FDefCounter := 0;
end;

class destructor TFireDACPooledConnectionFactory.DestroyClass;
var
  I: Integer;
begin
  // Remove the connection definitions created by this factory. Without this
  // FDManager keeps them registered (and the pool alive) until the process ends.
  TMonitor.Enter(FLock);
  try
    if Assigned(FCreatedDefs) then
    begin
      for I := 0 to FCreatedDefs.Count - 1 do
        try
          FDManager.DeleteConnectionDef(FCreatedDefs[I]);
        except
          // Finalization must not raise.
        end;
      FCreatedDefs.Free;
      FCreatedDefs := nil;
    end;
    FRegistry.Free;
    FRegistry := nil;
  finally
    TMonitor.Exit(FLock);
  end;
  FLock.Free;
  FLock := nil;
end;

class function TFireDACPooledConnectionFactory.BuildRegistryKey(
  const ABaseParams: TStrings; const APoolOptions: TFireDACPoolOptions): string;
var
  L: TStringList;
  I: Integer;
begin
  L := TStringList.Create;
  try
    L.Assign(ABaseParams);
    L.CaseSensitive := False;
    L.Sorted := True;
    L.Duplicates := dupIgnore;

    Result := '';
    for I := 0 to L.Count - 1 do
      Result := Result + LowerCase(L.Names[I]) + '=' + L.ValueFromIndex[I] + ';';

    Result := Result +
      'pooled=' + BoolToStr(APoolOptions.Pooled, True) + ';' +
      'max=' + IntToStr(APoolOptions.MaximumItems) + ';' +
      'exp=' + IntToStr(APoolOptions.ExpireTimeout) + ';' +
      'cleanup=' + IntToStr(APoolOptions.CleanupTimeout) + ';';
  finally
    L.Free;
  end;
end;

class function TFireDACPooledConnectionFactory.EnsureSharedConnectionDef(
  const ABaseParams: TStrings; const APoolOptions: TFireDACPoolOptions): string;
var
  Key: string;
  DefParams: TStringList;
  DriverID: string;
begin
  Key := BuildRegistryKey(ABaseParams, APoolOptions);

  TMonitor.Enter(FLock);
  try
    if FRegistry.TryGetValue(Key, Result) then
      Exit;

    DefParams := TStringList.Create;
    try
      DefParams.Assign(ABaseParams);
      DefParams.Values['Pooled'] := BoolToStr(APoolOptions.Pooled, True);
      if APoolOptions.MaximumItems > 0 then
        DefParams.Values['POOL_MaximumItems'] := IntToStr(APoolOptions.MaximumItems);
      if APoolOptions.ExpireTimeout > 0 then
        DefParams.Values['POOL_ExpireTimeout'] := IntToStr(APoolOptions.ExpireTimeout);
      if APoolOptions.CleanupTimeout > 0 then
        DefParams.Values['POOL_CleanupTimeout'] := IntToStr(APoolOptions.CleanupTimeout);

      DriverID := Trim(DefParams.Values['DriverID']);
      if DriverID = '' then
        raise Exception.Create('DriverID is required in connection params for pooled factory.');

      if not FDManager.Active then
        FDManager.Active := True;

      Inc(FDefCounter);
      Result := 'FluentORMPoolDef_' + IntToStr(FDefCounter);
      FDManager.AddConnectionDef(Result, DriverID, DefParams);
      FCreatedDefs.Add(Result);
      FRegistry.Add(Key, Result);
    finally
      DefParams.Free;
    end;
  finally
    TMonitor.Exit(FLock);
  end;
end;

constructor TFireDACPooledConnectionFactory.Create(const ABaseParams: TStrings;
  const APoolOptions: TFireDACPoolOptions);
begin
  inherited Create;
  if not Assigned(ABaseParams) then
    raise Exception.Create('ABaseParams cannot be nil.');

  FParams := TStringList.Create;
  FParams.Assign(ABaseParams);
  FConnectionDefName := EnsureSharedConnectionDef(FParams, APoolOptions);
end;

destructor TFireDACPooledConnectionFactory.Destroy;
begin
  FParams.Free;
  inherited;
end;

function TFireDACPooledConnectionFactory.CreateConnection: TFDConnection;
begin
  Result := TFDConnection.Create(nil);
  try
    Result.LoginPrompt := False;
    Result.ConnectionDefName := FConnectionDefName;
    Result.Connected := True;
  except
    Result.Free;
    raise;
  end;
end;

end.
