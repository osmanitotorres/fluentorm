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

unit uFluentORM.Repository;

interface

uses
  System.SysUtils,
  System.Rtti,
  System.Variants,
  uFluentORM.Types,
  uFluentORM.Executor,
  uFluentORM.Metadata;

type
  TRepository<T: class> = class
  private
    FExecutor: ISQLExecutor;
    FMeta: TOrmEntityMeta;
    class function IsSimpleIdentifier(const AValue: string): Boolean; static;
    class function QuoteIdentifierForDriver(const AIdentifier, ADriverID: string): string; static;
    class function IsInvalidKeyValue(const AValue: Variant): Boolean; static;
    class function ValueToVariant(const AValue: TValue): Variant; static;
    function GetEntityValue(AEntity: T; const APropMeta: TOrmPropertyMeta): Variant;
    procedure SetEntityValue(AEntity: T; const APropMeta: TOrmPropertyMeta;
      const AValue: Variant);
    function BuildInsertSQL(AEntity: T; out AParams: TSQLParams;
      const AReturningColumn: string = ''; AUseDefaultValues: Boolean = False): string;
    function BuildUpdateSQL(AEntity: T; out AParams: TSQLParams): string;
    function BuildDeleteSQL(const AId: Variant; out AParams: TSQLParams): string;
  public
    constructor Create(const AExecutor: ISQLExecutor);

    function Insert(AEntity: T): Integer;
    function Update(AEntity: T): Integer;
    function Delete(AEntity: T): Integer;
    function DeleteById(const AId: Variant): Integer;
    function Count: Int64;
  end;

implementation

{ TRepository<T> }

class function TRepository<T>.IsSimpleIdentifier(const AValue: string): Boolean;
var
  I: Integer;
  C: Char;
begin
  Result := Trim(AValue) <> '';
  if not Result then
    Exit;

  C := AValue[1];
  if not ((C in ['A'..'Z']) or (C in ['a'..'z']) or (C = '_')) then
    Exit(False);

  for I := 2 to Length(AValue) do
  begin
    C := AValue[I];
    if not ((C in ['A'..'Z']) or (C in ['a'..'z']) or (C in ['0'..'9']) or (C = '_')) then
      Exit(False);
  end;

  Result := True;
end;

class function TRepository<T>.QuoteIdentifierForDriver(const AIdentifier,
  ADriverID: string): string;
begin
  if (UpperCase(Trim(ADriverID)) = 'PG') and IsSimpleIdentifier(Trim(AIdentifier)) then
    Result := '"' + Trim(AIdentifier) + '"'
  else
    Result := Trim(AIdentifier);
end;

class function TRepository<T>.IsInvalidKeyValue(const AValue: Variant): Boolean;
begin
  if VarIsNull(AValue) or VarIsEmpty(AValue) then
    Exit(True);

  if VarIsStr(AValue) then
    Exit(Trim(VarToStr(AValue)) = '');

  Result := False;
end;

class function TRepository<T>.ValueToVariant(const AValue: TValue): Variant;
begin
  if AValue.IsEmpty then
    Exit(Null);

  if AValue.IsType<string> then
    Exit(AValue.AsString);

  if AValue.IsType<Integer> then
    Exit(AValue.AsInteger);

  if AValue.IsType<Int64> then
    Exit(AValue.AsInt64);

  if AValue.IsType<Double> then
    Exit(AValue.AsExtended);

  if AValue.IsType<Boolean> then
    Exit(AValue.AsBoolean);

  if AValue.IsType<TDateTime> then
    Exit(AValue.AsType<TDateTime>);

  Result := AValue.ToString;
end;

constructor TRepository<T>.Create(const AExecutor: ISQLExecutor);
var
  Ctx: TRttiContext;
  RType: TRttiType;
  InstType: TRttiInstanceType;
begin
  inherited Create;
  if AExecutor = nil then
    raise Exception.Create('ISQLExecutor is required.');

  FExecutor := AExecutor;
  Ctx := TRttiContext.Create;
  RType := Ctx.GetType(TypeInfo(T));
  if (RType = nil) or not (RType is TRttiInstanceType) then
    raise Exception.Create('TRepository<T> requires T to be a class type.');
  InstType := TRttiInstanceType(RType);
  FMeta := TOrmMetadataCache.GetEntityMeta(InstType.MetaclassType);
end;

function TRepository<T>.GetEntityValue(AEntity: T;
  const APropMeta: TOrmPropertyMeta): Variant;
var
  RttiValue: TValue;
begin
  RttiValue := APropMeta.PropertyInfo.GetValue(TObject(AEntity));
  Result := ValueToVariant(RttiValue);
end;

procedure TRepository<T>.SetEntityValue(AEntity: T;
  const APropMeta: TOrmPropertyMeta; const AValue: Variant);
var
  Kind: TTypeKind;
begin
  if not APropMeta.PropertyInfo.IsWritable then
    Exit;

  Kind := APropMeta.PropertyInfo.PropertyType.TypeKind;
  case Kind of
    tkInteger:
      APropMeta.PropertyInfo.SetValue(TObject(AEntity), TValue.From<Integer>(VarAsType(AValue, varInteger)));
    tkInt64:
      APropMeta.PropertyInfo.SetValue(TObject(AEntity), TValue.From<Int64>(VarAsType(AValue, varInt64)));
    tkFloat:
      begin
        if SameText(APropMeta.PropertyInfo.PropertyType.Name, 'TDateTime') then
          APropMeta.PropertyInfo.SetValue(TObject(AEntity), TValue.From<TDateTime>(VarToDateTime(AValue)))
        else
          APropMeta.PropertyInfo.SetValue(TObject(AEntity), TValue.From<Double>(AValue));
      end;
    tkUString, tkString, tkLString, tkWString:
      APropMeta.PropertyInfo.SetValue(TObject(AEntity), TValue.From<string>(VarToStr(AValue)));
    tkEnumeration:
      begin
        if APropMeta.PropertyInfo.PropertyType.Name = 'Boolean' then
          APropMeta.PropertyInfo.SetValue(TObject(AEntity), TValue.From<Boolean>(AValue));
      end;
  else
    APropMeta.PropertyInfo.SetValue(TObject(AEntity), TValue.FromVariant(AValue));
  end;
end;

function TRepository<T>.BuildInsertSQL(AEntity: T; out AParams: TSQLParams;
  const AReturningColumn: string; AUseDefaultValues: Boolean): string;
var
  P: TOrmPropertyMeta;
  Fields: string;
  Values: string;
  ParamList: TArray<TSQLParam>;
  ParamName: string;
begin
  Fields := '';
  Values := '';
  SetLength(ParamList, 0);

  for P in FMeta.Properties do
  begin
    if P.IsReadOnly then
      Continue;
    if P.IsKey and P.IsAutoGenerated then
      Continue;

    if Fields <> '' then
    begin
      Fields := Fields + ', ';
      Values := Values + ', ';
    end;

    Fields := Fields + P.ColumnName;
    ParamName := 'p_' + P.ColumnName;
    Values := Values + ':' + ParamName;

    SetLength(ParamList, Length(ParamList) + 1);
    ParamList[High(ParamList)] := SQLParam(ParamName, GetEntityValue(AEntity, P));
  end;

  AParams := ParamList;
  if (Fields = '') and AUseDefaultValues then
    Result := Format('INSERT INTO %s DEFAULT VALUES', [FMeta.TableName])
  else
    Result := Format('INSERT INTO %s (%s) VALUES (%s)', [FMeta.TableName, Fields, Values]);
  if Trim(AReturningColumn) <> '' then
    Result := Result + ' RETURNING ' + AReturningColumn;
end;

function TRepository<T>.BuildUpdateSQL(AEntity: T; out AParams: TSQLParams): string;
var
  P: TOrmPropertyMeta;
  SetClause: string;
  ParamList: TArray<TSQLParam>;
  ParamName: string;
  KeyMeta: TOrmPropertyMeta;
  KeyValue: Variant;
begin
  if not FMeta.HasKey then
    raise Exception.CreateFmt('Entity %s has no key. Cannot update.', [FMeta.EntityClass.ClassName]);

  KeyMeta := FMeta.KeyProperty;
  KeyValue := GetEntityValue(AEntity, KeyMeta);
  if IsInvalidKeyValue(KeyValue) then
    raise Exception.CreateFmt('Entity %s has null/empty key. Cannot update.',
      [FMeta.EntityClass.ClassName]);

  SetClause := '';
  SetLength(ParamList, 0);

  for P in FMeta.Properties do
  begin
    if P.IsKey or P.IsReadOnly then
      Continue;

    if SetClause <> '' then
      SetClause := SetClause + ', ';

    ParamName := 'p_' + P.ColumnName;
    SetClause := SetClause + P.ColumnName + ' = :' + ParamName;

    SetLength(ParamList, Length(ParamList) + 1);
    ParamList[High(ParamList)] := SQLParam(ParamName, GetEntityValue(AEntity, P));
  end;

  if SetClause = '' then
    raise Exception.CreateFmt('Entity %s has no writable non-key fields to update.',
      [FMeta.EntityClass.ClassName]);

  ParamName := 'k_' + KeyMeta.ColumnName;
  SetLength(ParamList, Length(ParamList) + 1);
  ParamList[High(ParamList)] := SQLParam(ParamName, KeyValue);

  AParams := ParamList;
  Result := Format('UPDATE %s SET %s WHERE %s = :%s',
    [FMeta.TableName, SetClause, KeyMeta.ColumnName, ParamName]);
end;

function TRepository<T>.BuildDeleteSQL(const AId: Variant;
  out AParams: TSQLParams): string;
var
  KeyMeta: TOrmPropertyMeta;
begin
  if not FMeta.HasKey then
    raise Exception.CreateFmt('Entity %s has no key. Cannot delete.',
      [FMeta.EntityClass.ClassName]);
  if IsInvalidKeyValue(AId) then
    raise Exception.CreateFmt('Entity %s received null/empty key for delete.',
      [FMeta.EntityClass.ClassName]);

  KeyMeta := FMeta.KeyProperty;
  SetLength(AParams, 1);
  AParams[0] := SQLParam('k_' + KeyMeta.ColumnName, AId);
  Result := Format('DELETE FROM %s WHERE %s = :%s',
    [FMeta.TableName, KeyMeta.ColumnName, AParams[0].Name]);
end;

function TRepository<T>.Insert(AEntity: T): Integer;
var
  SQL: string;
  Params: TSQLParams;
  KeyMeta: TOrmPropertyMeta;
  NewId: Variant;
  IdentityExec: ISQLIdentityExecutor;
  DriverInfo: ISQLDriverInfo;
  DriverID: string;
  UseDefaultValues: Boolean;
  ReturningColumn: string;
begin
  if AEntity = nil then
    raise Exception.CreateFmt('Entity %s instance is nil. Cannot insert.',
      [FMeta.EntityClass.ClassName]);

  DriverID := '';
  if Supports(FExecutor, ISQLDriverInfo, DriverInfo) then
    DriverID := UpperCase(Trim(DriverInfo.GetDriverID));
  UseDefaultValues := (DriverID = 'PG') or (DriverID = 'MSSQL') or (DriverID = 'SQLITE') or (DriverID = 'FB');

  if FMeta.HasKey and FMeta.KeyProperty.IsAutoGenerated then
  begin
    KeyMeta := FMeta.KeyProperty;
    if DriverID = 'PG' then
    begin
      ReturningColumn := QuoteIdentifierForDriver(KeyMeta.ColumnName, DriverID);
      SQL := BuildInsertSQL(AEntity, Params, ReturningColumn, UseDefaultValues);
      NewId := FExecutor.ExecuteScalar(SQL, Params);
      if not VarIsNull(NewId) then
        SetEntityValue(AEntity, KeyMeta, NewId);
      Result := Ord(not VarIsNull(NewId));
      Exit;
    end;
  end;

  SQL := BuildInsertSQL(AEntity, Params, '', UseDefaultValues);
  Result := FExecutor.Execute(SQL, Params);

  if FMeta.HasKey then
  begin
    KeyMeta := FMeta.KeyProperty;
    if KeyMeta.IsAutoGenerated and Supports(FExecutor, ISQLIdentityExecutor, IdentityExec) then
    begin
      NewId := IdentityExec.GetLastInsertedId;
      if not VarIsNull(NewId) then
        SetEntityValue(AEntity, KeyMeta, NewId);
    end;
  end;
end;


function TRepository<T>.Update(AEntity: T): Integer;
var
  SQL: string;
  Params: TSQLParams;
begin
  if AEntity = nil then
    raise Exception.CreateFmt('Entity %s instance is nil. Cannot update.',
      [FMeta.EntityClass.ClassName]);

  SQL := BuildUpdateSQL(AEntity, Params);
  Result := FExecutor.Execute(SQL, Params);
end;


function TRepository<T>.Delete(AEntity: T): Integer;
var
  KeyMeta: TOrmPropertyMeta;
begin
  if AEntity = nil then
    raise Exception.CreateFmt('Entity %s instance is nil. Cannot delete.',
      [FMeta.EntityClass.ClassName]);

  if not FMeta.HasKey then
    raise Exception.CreateFmt('Entity %s has no key. Cannot delete.',
      [FMeta.EntityClass.ClassName]);
  KeyMeta := FMeta.KeyProperty;
  Result := DeleteById(GetEntityValue(AEntity, KeyMeta));
end;

function TRepository<T>.DeleteById(const AId: Variant): Integer;
var
  SQL: string;
  Params: TSQLParams;
begin
  if IsInvalidKeyValue(AId) then
    raise Exception.CreateFmt('Entity %s received null/empty key for delete.',
      [FMeta.EntityClass.ClassName]);

  SQL := BuildDeleteSQL(AId, Params);
  Result := FExecutor.Execute(SQL, Params);
end;

function TRepository<T>.Count: Int64;
var
  V: Variant;
begin
  V := FExecutor.ExecuteScalar('SELECT COUNT(*) FROM ' + FMeta.TableName, []);
  if VarIsNull(V) then
    Exit(0);
  Result := V;
end;

end.
