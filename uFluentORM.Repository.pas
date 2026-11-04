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
  System.Classes,
  System.Rtti,
  System.TypInfo,
  System.Variants,
  System.Generics.Collections,
  Data.DB,
  uFluentORM.Types,
  uFluentORM.Executor,
  uFluentORM.Metadata;

type
  TRepository<T: class> = class
  private const
    // Table variable used to capture generated keys on SQL Server.
    // "OUTPUT INSERTED.x" without INTO fails on tables with triggers (error 334);
    // "OUTPUT ... INTO @table" is allowed.
    MSSQL_ID_TABLE = '@fluent_ids';
    // nvarchar(n) parameters above 4000 chars must be sent as NVARCHAR(MAX).
    MAX_WIDE_STRING_PARAM = 4000;
  private
    FExecutor: ISQLExecutor;
    FMeta: TOrmEntityMeta;
    FDatabaseType: TSQLDatabaseType;
    FQuoteIdentifiers: Boolean;
    class function IsInvalidKeyValue(const AValue: Variant): Boolean; static;
    class function SafeParamName(const AName: string): string; static;
    class function IsDateTimeType(ATypeInfo: PTypeInfo): Boolean; static;
    class function IsBooleanType(ATypeInfo: PTypeInfo): Boolean; static;
    function FieldTypeFor(AType: TRttiType): TFieldType;
    function ValueToVariant(const AValue: TValue; AType: TRttiType): Variant;
    function NormalizeKeyValue(const AValue: Variant): Variant;
    function MSSQLKeyTypeName: string;
    function QuoteIdentifier(const AIdentifier: string): string;
    function TableNameSQL: string;
    function GetEntityValue(AEntity: T; const APropMeta: TOrmPropertyMeta): Variant;
    function MakeParam(const AName: string; AEntity: T;
      const APropMeta: TOrmPropertyMeta): TSQLParam;
    function MakeKeyParam(const AName: string; const AValue: Variant): TSQLParam;
    procedure SetEntityValue(AEntity: T; const APropMeta: TOrmPropertyMeta;
      const AValue: Variant);
    function BuildInsertSQL(AEntity: T; out AParams: TSQLParams;
      const AReturningColumn: string = ''; const AOutputColumn: string = '';
      AUseDefaultValues: Boolean = False): string;
    function BuildUpdateSQL(AEntity: T; out AParams: TSQLParams): string;
    function BuildDeleteSQL(const AId: Variant; out AParams: TSQLParams): string;
    function BuildSelectSQL: string;
    function QueryExecutor: ISQLQueryExecutor;
    function CreateEntity: T;
    class function UnquotedName(const AName: string): string; static;
  public
    constructor Create(const AExecutor: ISQLExecutor);

    function Insert(AEntity: T): Integer;
    function Update(AEntity: T): Integer;
    function Delete(AEntity: T): Integer;
    function DeleteById(const AId: Variant): Integer;
    function Count: Int64;

    /// <summary>
    /// Le a entidade pela chave. Retorna nil se nao existir; quem chama libera.
    /// Requer um executor com ISQLQueryExecutor (FireDAC/ADO ja implementam).
    /// </summary>
    function FindById(const AId: Variant): T;
    /// <summary>
    /// Le todas as linhas da tabela (lista dona dos objetos).
    /// AOrderBy: nome de coluna opcional (ex.: 'nome').
    /// </summary>
    function FindAll(const AOrderBy: string = ''): TObjectList<T>;
    /// <summary> Preenche a entidade com a linha atual de um dataset (por nome de coluna). </summary>
    procedure LoadFromDataSet(AEntity: T; ADataSet: TDataSet);

    /// <summary> Dialect resolved from the executor (ISQLDialectInfo/ISQLDriverInfo). </summary>
    property DatabaseType: TSQLDatabaseType read FDatabaseType;
    /// <summary>
    /// Quotes table/column identifiers using the dialect rules (default True),
    /// so reserved words such as "user" or "order" work as table/column names.
    /// Rules that keep legacy mappings working:
    ///  - names already written with quotes in the attribute ("x", `x`, [x]) are kept;
    ///  - PostgreSQL: only all-lowercase names are quoted (an unquoted name is
    ///    folded to lowercase, so quoting [Table('Usuario')] would break it);
    ///  - Firebird: only all-uppercase names are quoted (same reason).
    /// Set False to emit identifiers exactly as written in the attributes.
    /// </summary>
    property QuoteIdentifiers: Boolean read FQuoteIdentifiers write FQuoteIdentifiers;
  end;

implementation

{ TRepository<T> }

class function TRepository<T>.IsInvalidKeyValue(const AValue: Variant): Boolean;
begin
  if VarIsNull(AValue) or VarIsEmpty(AValue) then
    Exit(True);

  if VarIsStr(AValue) then
    Exit(Trim(VarToStr(AValue)) = '');

  Result := False;
end;

class function TRepository<T>.SafeParamName(const AName: string): string;
var
  I: Integer;
  C: Char;
begin
  Result := '';
  for I := 1 to Length(AName) do
  begin
    C := AName[I];
    if CharInSet(C, ['A'..'Z', 'a'..'z', '0'..'9', '_']) then
      Result := Result + C
    else
      Result := Result + '_';
  end;

  if Result = '' then
    Result := 'p';

  if CharInSet(Result[1], ['0'..'9']) then
    Result := 'p_' + Result;
end;

class function TRepository<T>.IsDateTimeType(ATypeInfo: PTypeInfo): Boolean;
begin
  Result := (ATypeInfo = TypeInfo(TDateTime)) or (ATypeInfo = TypeInfo(TDate)) or
            (ATypeInfo = TypeInfo(TTime));
end;

class function TRepository<T>.IsBooleanType(ATypeInfo: PTypeInfo): Boolean;
begin
  Result := (ATypeInfo = TypeInfo(Boolean)) or (ATypeInfo = TypeInfo(ByteBool)) or
            (ATypeInfo = TypeInfo(WordBool)) or (ATypeInfo = TypeInfo(LongBool));
end;

constructor TRepository<T>.Create(const AExecutor: ISQLExecutor);
var
  Ctx: TRttiContext;
  RType: TRttiType;
  InstType: TRttiInstanceType;
  DialectInfo: ISQLDialectInfo;
  DriverInfo: ISQLDriverInfo;
begin
  inherited Create;
  if AExecutor = nil then
    raise Exception.Create('ISQLExecutor is required.');

  FExecutor := AExecutor;
  FQuoteIdentifiers := True;

  if Supports(FExecutor, ISQLDialectInfo, DialectInfo) then
    FDatabaseType := DialectInfo.GetDatabaseType
  else if Supports(FExecutor, ISQLDriverInfo, DriverInfo) then
    FDatabaseType := TSQLDialect.FromDriverID(DriverInfo.GetDriverID)
  else
    FDatabaseType := dbGeneric;

  Ctx := TRttiContext.Create;
  RType := Ctx.GetType(TypeInfo(T));
  if (RType = nil) or not (RType is TRttiInstanceType) then
    raise Exception.Create('TRepository<T> requires T to be a class type.');
  InstType := TRttiInstanceType(RType);
  FMeta := TOrmMetadataCache.GetEntityMeta(InstType.MetaclassType);
end;

function TRepository<T>.QuoteIdentifier(const AIdentifier: string): string;
var
  S: string;
begin
  S := Trim(AIdentifier);
  if (not FQuoteIdentifiers) or (S = '') then
    Exit(S);

  // Already quoted in the attribute: respect it.
  if CharInSet(S[1], ['"', '`', '[']) then
    Exit(S);

  // Case folding databases: quoting would make a mixed-case name case sensitive.
  if (FDatabaseType = dbPostgreSQL) and (S <> LowerCase(S)) then
    Exit(S);
  if (FDatabaseType = dbFirebird) and (S <> UpperCase(S)) then
    Exit(S);

  Result := TSQLDialect.QuoteIdentifier(S, FDatabaseType, True);
end;

function TRepository<T>.TableNameSQL: string;
begin
  Result := QuoteIdentifier(FMeta.TableName);
end;

function TRepository<T>.FieldTypeFor(AType: TRttiType): TFieldType;
var
  TI: PTypeInfo;
begin
  TI := AType.Handle;
  case AType.TypeKind of
    tkInteger:
      if GetTypeData(TI)^.OrdType = otULong then
        Result := ftLargeint
      else
        Result := ftInteger;
    tkInt64:
      Result := ftLargeint;
    tkEnumeration:
      if IsBooleanType(TI) then
        Result := ftBoolean
      else
        Result := ftInteger;
    tkFloat:
      if TI = TypeInfo(TDateTime) then
        Result := ftDateTime
      else if TI = TypeInfo(TDate) then
        Result := ftDate
      else if TI = TypeInfo(TTime) then
        Result := ftTime
      else if GetTypeData(TI)^.FloatType = TFloatType.ftCurr then
        // ftBCD -> numeric/decimal. (ftCurrency maps to the "money" type on
        // PostgreSQL and breaks inserts into numeric columns.)
        Result := ftBCD
      else
        Result := ftFloat;
    tkChar, tkWChar, tkString, tkLString, tkWString, tkUString:
      Result := ftWideString;
    tkRecord:
      if TI = TypeInfo(TGUID) then
      begin
        // MySQL and SQLite have no uuid type: GUIDs are stored as CHAR(36) text.
        if FDatabaseType in [dbMySQL, dbSQLite] then
          Result := ftWideString
        else
          Result := ftGuid;
      end
      else
        Result := ftUnknown;
    tkDynArray:
      if TI = TypeInfo(TBytes) then
        Result := ftBlob
      else
        Result := ftUnknown;
  else
    Result := ftUnknown;
  end;
end;

function TRepository<T>.ValueToVariant(const AValue: TValue; AType: TRttiType): Variant;
var
  TI: PTypeInfo;
  G: TGUID;
  B: TBytes;
  P: Pointer;
begin
  // Dispatch on the exact declared type. TValue.IsType<X> also returns True
  // for *convertible* types, so a Double property could be taken as TDateTime.
  TI := AType.Handle;
  case AType.TypeKind of
    tkInteger:
      if GetTypeData(TI)^.OrdType = otULong then
        Result := Int64(AValue.AsOrdinal)
      else
        Result := Integer(AValue.AsOrdinal);

    tkInt64:
      Result := AValue.AsInt64;

    tkEnumeration:
      if IsBooleanType(TI) then
        Result := AValue.AsOrdinal <> 0
      else
        Result := Integer(AValue.AsOrdinal);

    tkFloat:
      if IsDateTimeType(TI) then
        Result := VarFromDateTime(AValue.AsExtended)
      else if GetTypeData(TI)^.FloatType = TFloatType.ftCurr then
        Result := AValue.AsCurrency
      else
        Result := Double(AValue.AsExtended);

    tkChar:
      Result := string(AValue.AsType<AnsiChar>);

    tkWChar:
      Result := string(AValue.AsType<Char>);

    tkString, tkLString, tkWString, tkUString:
      Result := AValue.AsString;

    tkVariant:
      begin
        Result := AValue.AsVariant;
        if VarIsEmpty(Result) then
          Result := Null;
      end;

    tkRecord:
      if TI = TypeInfo(TGUID) then
      begin
        G := AValue.AsType<TGUID>;
        if FDatabaseType in [dbMySQL, dbSQLite] then
          Result := Copy(GUIDToString(G), 2, 36) // CHAR(36), without braces
        else
          Result := GUIDToString(G);
      end
      else
        raise Exception.CreateFmt('Unsupported record property type "%s" in TRepository<T>.',
          [AType.Name]);

    tkDynArray:
      if TI = TypeInfo(TBytes) then
      begin
        B := AValue.AsType<TBytes>;
        if Length(B) = 0 then
          Result := Null
        else
        begin
          Result := VarArrayCreate([0, High(B)], varByte);
          P := VarArrayLock(Result);
          try
            Move(B[0], P^, Length(B));
          finally
            VarArrayUnlock(Result);
          end;
        end;
      end
      else
        raise Exception.CreateFmt('Unsupported array property type "%s" in TRepository<T>.',
          [AType.Name]);

  else
    raise Exception.CreateFmt('Unsupported property type "%s" in TRepository<T>.',
      [AType.Name]);
  end;
end;

function TRepository<T>.GetEntityValue(AEntity: T;
  const APropMeta: TOrmPropertyMeta): Variant;
begin
  Result := ValueToVariant(APropMeta.PropertyInfo.GetValue(TObject(AEntity)),
    APropMeta.PropertyInfo.PropertyType);
end;

function TRepository<T>.MakeParam(const AName: string; AEntity: T;
  const APropMeta: TOrmPropertyMeta): TSQLParam;
var
  V: Variant;
  DT: TFieldType;
begin
  V := GetEntityValue(AEntity, APropMeta);
  DT := APropMeta.DataType; // [Column('x', ftTipo)] tem prioridade
  if DT = ftUnknown then
    DT := FieldTypeFor(APropMeta.PropertyInfo.PropertyType);
  if (DT = ftWideString) and VarIsStr(V) and (Length(VarToStr(V)) > MAX_WIDE_STRING_PARAM) then
    DT := ftWideMemo;
  Result := SQLParam(AName, V, DT);
end;

function TRepository<T>.NormalizeKeyValue(const AValue: Variant): Variant;
var
  S: string;
begin
  Result := AValue;
  // GUID keys passed as '{...}' to DeleteById on MySQL/SQLite (CHAR(36) column).
  if FMeta.HasKey and (FDatabaseType in [dbMySQL, dbSQLite]) and VarIsStr(AValue) and
     (FMeta.KeyProperty.PropertyInfo.PropertyType.Handle = TypeInfo(TGUID)) then
  begin
    S := Trim(VarToStr(AValue));
    if (Length(S) = 38) and (S[1] = '{') then
      Result := Copy(S, 2, 36);
  end;
end;

function TRepository<T>.MakeKeyParam(const AName: string; const AValue: Variant): TSQLParam;
begin
  if FMeta.KeyProperty.DataType <> ftUnknown then
    Result := SQLParam(AName, NormalizeKeyValue(AValue), FMeta.KeyProperty.DataType)
  else
    Result := SQLParam(AName, NormalizeKeyValue(AValue),
      FieldTypeFor(FMeta.KeyProperty.PropertyInfo.PropertyType));
end;

function TRepository<T>.MSSQLKeyTypeName: string;
var
  KeyType: TRttiType;
begin
  KeyType := FMeta.KeyProperty.PropertyInfo.PropertyType;
  case KeyType.TypeKind of
    tkInteger:
      if GetTypeData(KeyType.Handle)^.OrdType = otULong then
        Result := 'BIGINT'
      else
        Result := 'INT';
    tkInt64:
      Result := 'BIGINT';
    tkChar, tkWChar, tkString, tkLString, tkWString, tkUString:
      Result := 'NVARCHAR(450)';
    tkRecord:
      if KeyType.Handle = TypeInfo(TGUID) then
        Result := 'UNIQUEIDENTIFIER'
      else
        Result := 'SQL_VARIANT';
    tkFloat:
      Result := 'DECIMAL(38, 0)';
  else
    Result := 'SQL_VARIANT';
  end;
end;

procedure TRepository<T>.SetEntityValue(AEntity: T;
  const APropMeta: TOrmPropertyMeta; const AValue: Variant);
var
  Prop: TRttiProperty;
  PropType: TRttiType;
  Kind: TTypeKind;
  S: string;
  B: TBytes;
  P: Pointer;
begin
  Prop := APropMeta.PropertyInfo;
  if not Prop.IsWritable then
    Exit;

  PropType := Prop.PropertyType;
  Kind := PropType.TypeKind;

  if VarIsNull(AValue) or VarIsEmpty(AValue) then
  begin
    // Value types keep their default value; assigning TValue.Empty to them
    // raises. Strings/chars receive an empty value instead.
    case Kind of
      tkUString, tkString, tkLString, tkWString:
        Prop.SetValue(TObject(AEntity), TValue.From<string>(''));
      tkChar:
        Prop.SetValue(TObject(AEntity), TValue.From<AnsiChar>(#0));
      tkWChar:
        Prop.SetValue(TObject(AEntity), TValue.From<Char>(#0));
      tkVariant:
        Prop.SetValue(TObject(AEntity), TValue.FromVariant(Null));
    end;
    Exit;
  end;

  case Kind of
    tkInteger, tkInt64:
      // FromOrdinal keeps the exact property type (Byte, Word, Cardinal...).
      Prop.SetValue(TObject(AEntity),
        TValue.FromOrdinal(PropType.Handle, VarAsType(AValue, varInt64)));

    tkChar:
      begin
        S := VarToStr(AValue);
        if S = '' then
          Prop.SetValue(TObject(AEntity), TValue.From<AnsiChar>(#0))
        else
          Prop.SetValue(TObject(AEntity), TValue.From<AnsiChar>(AnsiChar(S[1])));
      end;

    tkWChar:
      begin
        S := VarToStr(AValue);
        if S = '' then
          Prop.SetValue(TObject(AEntity), TValue.From<Char>(#0))
        else
          Prop.SetValue(TObject(AEntity), TValue.From<Char>(S[1]));
      end;

    tkFloat:
      begin
        if PropType.Handle = TypeInfo(TDateTime) then
          Prop.SetValue(TObject(AEntity),
            TValue.From<TDateTime>(VarToDateTime(AValue)))
        else if PropType.Handle = TypeInfo(TDate) then
          Prop.SetValue(TObject(AEntity),
            TValue.From<TDate>(VarToDateTime(AValue)))
        else if PropType.Handle = TypeInfo(TTime) then
          Prop.SetValue(TObject(AEntity),
            TValue.From<TTime>(VarToDateTime(AValue)))
        else if PropType.Handle = TypeInfo(Currency) then
          Prop.SetValue(TObject(AEntity),
            TValue.From<Currency>(VarAsType(AValue, varCurrency)))
        else if PropType.Handle = TypeInfo(Single) then
          Prop.SetValue(TObject(AEntity),
            TValue.From<Single>(VarAsType(AValue, varSingle)))
        else if PropType.Handle = TypeInfo(Extended) then
          Prop.SetValue(TObject(AEntity),
            TValue.From<Extended>(VarAsType(AValue, varDouble)))
        else
          Prop.SetValue(TObject(AEntity),
            TValue.From<Double>(VarAsType(AValue, varDouble)));
      end;

    tkUString, tkString, tkLString, tkWString:
      Prop.SetValue(TObject(AEntity), TValue.From<string>(VarToStr(AValue)));

    tkEnumeration:
      begin
        if PropType.Handle = TypeInfo(Boolean) then
          Prop.SetValue(TObject(AEntity), TValue.From<Boolean>(AValue))
        else if PropType.Handle = TypeInfo(ByteBool) then
          Prop.SetValue(TObject(AEntity), TValue.From<ByteBool>(ByteBool(Boolean(AValue))))
        else if PropType.Handle = TypeInfo(WordBool) then
          Prop.SetValue(TObject(AEntity), TValue.From<WordBool>(WordBool(Boolean(AValue))))
        else if PropType.Handle = TypeInfo(LongBool) then
          Prop.SetValue(TObject(AEntity), TValue.From<LongBool>(LongBool(Boolean(AValue))))
        else
          Prop.SetValue(TObject(AEntity),
            TValue.FromOrdinal(PropType.Handle, VarAsType(AValue, varInteger)));
      end;

    tkRecord:
      if PropType.Handle = TypeInfo(TGUID) then
      begin
        S := Trim(VarToStr(AValue));
        // MySQL CHAR(36) / PostgreSQL uuid come without braces.
        if (S <> '') and (S[1] <> '{') then
          S := '{' + S + '}';
        Prop.SetValue(TObject(AEntity), TValue.From<TGUID>(StringToGUID(S)));
      end
      else
        raise Exception.CreateFmt('Unsupported record property "%s" in TRepository<T>.',
          [APropMeta.PropertyName]);

    tkDynArray:
      if PropType.Handle = TypeInfo(TBytes) then
      begin
        if VarIsArray(AValue) then
        begin
          SetLength(B, VarArrayHighBound(AValue, 1) - VarArrayLowBound(AValue, 1) + 1);
          if Length(B) > 0 then
          begin
            P := VarArrayLock(AValue);
            try
              Move(P^, B[0], Length(B));
            finally
              VarArrayUnlock(AValue);
            end;
          end;
        end
        else
          B := TEncoding.UTF8.GetBytes(VarToStr(AValue));
        Prop.SetValue(TObject(AEntity), TValue.From<TBytes>(B));
      end
      else
        raise Exception.CreateFmt('Unsupported array property "%s" in TRepository<T>.',
          [APropMeta.PropertyName]);

    tkVariant:
      Prop.SetValue(TObject(AEntity), TValue.FromVariant(AValue));

  else
    raise Exception.CreateFmt('Unsupported property type "%s" (%s) in TRepository<T>.',
      [APropMeta.PropertyName, PropType.Name]);
  end;
end;

function TRepository<T>.BuildInsertSQL(AEntity: T; out AParams: TSQLParams;
  const AReturningColumn: string; const AOutputColumn: string;
  AUseDefaultValues: Boolean): string;
var
  P: TOrmPropertyMeta;
  Fields: string;
  Values: string;
  ParamList: TArray<TSQLParam>;
  ParamName: string;
  BaseParamName: string;
  UsedNames: TStringList;
  Suffix: Integer;
begin
  Fields := '';
  Values := '';
  SetLength(ParamList, 0);
  UsedNames := TStringList.Create;
  try
    UsedNames.CaseSensitive := False;
    UsedNames.Duplicates := dupIgnore;

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

      Fields := Fields + QuoteIdentifier(P.ColumnName);

      BaseParamName := SafeParamName('p_' + P.ColumnName);
      ParamName := BaseParamName;
      Suffix := 1;
      while UsedNames.IndexOf(ParamName) >= 0 do
      begin
        Inc(Suffix);
        ParamName := BaseParamName + '_' + Suffix.ToString;
      end;
      UsedNames.Add(ParamName);

      Values := Values + ':' + ParamName;

      SetLength(ParamList, Length(ParamList) + 1);
      ParamList[High(ParamList)] := MakeParam(ParamName, AEntity, P);
    end;
  finally
    UsedNames.Free;
  end;

  AParams := ParamList;

  Result := 'INSERT INTO ' + TableNameSQL;
  if Fields <> '' then
    Result := Result + ' (' + Fields + ')';

  // SQL Server: OUTPUT ... INTO @table must come after the column list and
  // before VALUES/DEFAULT VALUES. (INTO is required for tables with triggers.)
  if Trim(AOutputColumn) <> '' then
    Result := Result + ' OUTPUT INSERTED.' + QuoteIdentifier(AOutputColumn) +
      ' INTO ' + MSSQL_ID_TABLE;

  if Fields = '' then
  begin
    if AUseDefaultValues then
      Result := Result + ' DEFAULT VALUES'
    else
      // MySQL syntax for "all columns default".
      Result := Result + ' () VALUES ()';
  end
  else
    Result := Result + ' VALUES (' + Values + ')';

  // PostgreSQL: RETURNING goes at the end of the statement.
  if Trim(AReturningColumn) <> '' then
    Result := Result + ' RETURNING ' + QuoteIdentifier(AReturningColumn);
end;

function TRepository<T>.BuildUpdateSQL(AEntity: T; out AParams: TSQLParams): string;
var
  P: TOrmPropertyMeta;
  SetClause: string;
  ParamList: TArray<TSQLParam>;
  ParamName: string;
  KeyMeta: TOrmPropertyMeta;
  KeyValue: Variant;
  UsedNames: TStringList;
  BaseParamName: string;
  Suffix: Integer;
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
  UsedNames := TStringList.Create;
  try
    UsedNames.CaseSensitive := False;
    UsedNames.Duplicates := dupIgnore;

    for P in FMeta.Properties do
    begin
      if P.IsKey or P.IsReadOnly then
        Continue;

      BaseParamName := SafeParamName('p_' + P.ColumnName);
      ParamName := BaseParamName;
      Suffix := 1;
      while UsedNames.IndexOf(ParamName) >= 0 do
      begin
        Inc(Suffix);
        ParamName := BaseParamName + '_' + Suffix.ToString;
      end;
      UsedNames.Add(ParamName);

      if SetClause <> '' then
        SetClause := SetClause + ', ';
      SetClause := SetClause + QuoteIdentifier(P.ColumnName) + ' = :' + ParamName;

      SetLength(ParamList, Length(ParamList) + 1);
      ParamList[High(ParamList)] := MakeParam(ParamName, AEntity, P);
    end;

    if SetClause = '' then
      raise Exception.CreateFmt('Entity %s has no writable non-key fields to update.',
        [FMeta.EntityClass.ClassName]);

    ParamName := SafeParamName('k_' + KeyMeta.ColumnName);
    SetLength(ParamList, Length(ParamList) + 1);
    ParamList[High(ParamList)] := MakeKeyParam(ParamName, KeyValue);
  finally
    UsedNames.Free;
  end;

  AParams := ParamList;
  Result := Format('UPDATE %s SET %s WHERE %s = :%s',
    [TableNameSQL, SetClause, QuoteIdentifier(KeyMeta.ColumnName), ParamName]);
end;

function TRepository<T>.BuildDeleteSQL(const AId: Variant;
  out AParams: TSQLParams): string;
var
  KeyMeta: TOrmPropertyMeta;
  ParamName: string;
begin
  if not FMeta.HasKey then
    raise Exception.CreateFmt('Entity %s has no key. Cannot delete.',
      [FMeta.EntityClass.ClassName]);
  if IsInvalidKeyValue(AId) then
    raise Exception.CreateFmt('Entity %s received null/empty key for delete.',
      [FMeta.EntityClass.ClassName]);

  KeyMeta := FMeta.KeyProperty;
  ParamName := SafeParamName('k_' + KeyMeta.ColumnName);
  SetLength(AParams, 1);
  AParams[0] := MakeKeyParam(ParamName, AId);
  Result := Format('DELETE FROM %s WHERE %s = :%s',
    [TableNameSQL, QuoteIdentifier(KeyMeta.ColumnName), ParamName]);
end;

function TRepository<T>.Insert(AEntity: T): Integer;
var
  SQL: string;
  Params: TSQLParams;
  KeyMeta: TOrmPropertyMeta;
  NewId: Variant;
  IdentityExec: ISQLIdentityExecutor;
  HasAutoKey: Boolean;
begin
  if AEntity = nil then
    raise Exception.CreateFmt('Entity %s instance is nil. Cannot insert.',
      [FMeta.EntityClass.ClassName]);

  HasAutoKey := FMeta.HasKey and FMeta.KeyProperty.IsAutoGenerated;
  if HasAutoKey then
    KeyMeta := FMeta.KeyProperty;

  if HasAutoKey then
  begin
    case FDatabaseType of
      dbPostgreSQL:
        begin
          SQL := BuildInsertSQL(AEntity, Params, KeyMeta.ColumnName, '', True);
          NewId := FExecutor.ExecuteScalar(SQL, Params);
          if not VarIsNull(NewId) and not VarIsEmpty(NewId) then
            SetEntityValue(AEntity, KeyMeta, NewId);
          Exit(1);
        end;

      dbMSSQL:
        begin
          // One batch: works with identity (INT/BIGINT) and default keys
          // (NEWID()/NEWSEQUENTIALID()), and with tables that have triggers.
          SQL := 'SET NOCOUNT ON; DECLARE ' + MSSQL_ID_TABLE + ' TABLE (id ' +
            MSSQLKeyTypeName + '); ' +
            BuildInsertSQL(AEntity, Params, '', KeyMeta.ColumnName, True) +
            '; SELECT TOP 1 id FROM ' + MSSQL_ID_TABLE + ';';
          NewId := FExecutor.ExecuteScalar(SQL, Params);
          if not VarIsNull(NewId) and not VarIsEmpty(NewId) then
            SetEntityValue(AEntity, KeyMeta, NewId);
          Exit(1);
        end;
    end;
  end;

  // MySQL: "LAST_INSERT_ID()" is connection scoped and is read by the executor.
  // SQL Server/PostgreSQL were handled above. Firebird/generic keep the
  // executor fallback (which returns Null when the driver has no portable API).
  SQL := BuildInsertSQL(AEntity, Params, '', '', FDatabaseType <> dbMySQL);
  Result := FExecutor.Execute(SQL, Params);

  if HasAutoKey and Supports(FExecutor, ISQLIdentityExecutor, IdentityExec) then
  begin
    NewId := IdentityExec.GetLastInsertedId;
    if not VarIsNull(NewId) and not VarIsEmpty(NewId) then
      SetEntityValue(AEntity, KeyMeta, NewId);
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

class function TRepository<T>.UnquotedName(const AName: string): string;
var
  I: Integer;
begin
  Result := '';
  for I := 1 to Length(AName) do
    if not CharInSet(AName[I], ['"', '`', '[', ']']) then
      Result := Result + AName[I];
  Result := Trim(Result);
end;

function TRepository<T>.QueryExecutor: ISQLQueryExecutor;
begin
  if not Supports(FExecutor, ISQLQueryExecutor, Result) then
    raise Exception.Create('The executor does not implement ISQLQueryExecutor ' +
      '(required by FindById/FindAll).');
end;

function TRepository<T>.CreateEntity: T;
var
  Ctx: TRttiContext;
  InstType: TRttiInstanceType;
  M: TRttiMethod;
begin
  // Usa o construtor sem parametros mais especifico da classe (inicializa
  // valores padrao definidos no DTO); TObject.Create como ultimo recurso.
  Ctx := TRttiContext.Create;
  InstType := Ctx.GetType(FMeta.EntityClass) as TRttiInstanceType;
  for M in InstType.GetMethods do
    if M.IsConstructor and (Length(M.GetParameters) = 0) then
      Exit(M.Invoke(InstType.MetaclassType, []).AsType<T>);
  Result := TValue.From<TObject>(FMeta.EntityClass.Create).AsType<T>;
end;

function TRepository<T>.BuildSelectSQL: string;
var
  P: TOrmPropertyMeta;
  Cols: string;
begin
  Cols := '';
  for P in FMeta.Properties do
  begin
    if Cols <> '' then
      Cols := Cols + ', ';
    Cols := Cols + QuoteIdentifier(P.ColumnName);
  end;
  Result := 'SELECT ' + Cols + ' FROM ' + TableNameSQL;
end;

procedure TRepository<T>.LoadFromDataSet(AEntity: T; ADataSet: TDataSet);
var
  P: TOrmPropertyMeta;
  F: TField;
begin
  if (AEntity = nil) or (ADataSet = nil) then
    Exit;
  for P in FMeta.Properties do
  begin
    F := ADataSet.FindField(UnquotedName(P.ColumnName));
    if F = nil then
      Continue;
    if (P.PropertyInfo.PropertyType.Handle = TypeInfo(TBytes)) and P.PropertyInfo.IsWritable then
    begin
      if F.IsNull then
        P.PropertyInfo.SetValue(TObject(AEntity), TValue.From<TBytes>(nil))
      else
        P.PropertyInfo.SetValue(TObject(AEntity), TValue.From<TBytes>(F.AsBytes));
    end
    else
      SetEntityValue(AEntity, P, F.Value);
  end;
end;

function TRepository<T>.FindById(const AId: Variant): T;
var
  KeyMeta: TOrmPropertyMeta;
  ParamName: string;
  DS: TDataSet;
begin
  Result := Default(T);
  if not FMeta.HasKey then
    raise Exception.CreateFmt('Entity %s has no key. Cannot find by id.',
      [FMeta.EntityClass.ClassName]);
  if IsInvalidKeyValue(AId) then
    raise Exception.CreateFmt('Entity %s received null/empty key for FindById.',
      [FMeta.EntityClass.ClassName]);

  KeyMeta := FMeta.KeyProperty;
  ParamName := SafeParamName('k_' + KeyMeta.ColumnName);
  DS := QueryExecutor.OpenDataSet(
    BuildSelectSQL + ' WHERE ' + QuoteIdentifier(KeyMeta.ColumnName) + ' = :' + ParamName,
    [MakeKeyParam(ParamName, AId)]);
  try
    if DS.Eof then
      Exit;
    Result := CreateEntity;
    try
      LoadFromDataSet(Result, DS);
    except
      TObject(Result).Free;
      raise;
    end;
  finally
    DS.Free;
  end;
end;

function TRepository<T>.FindAll(const AOrderBy: string): TObjectList<T>;
var
  SQL: string;
  DS: TDataSet;
  E: T;
begin
  SQL := BuildSelectSQL;
  if Trim(AOrderBy) <> '' then
    SQL := SQL + ' ORDER BY ' + QuoteIdentifier(AOrderBy);

  Result := TObjectList<T>.Create(True);
  try
    DS := QueryExecutor.OpenDataSet(SQL, []);
    try
      while not DS.Eof do
      begin
        E := CreateEntity;
        Result.Add(E);
        LoadFromDataSet(E, DS);
        DS.Next;
      end;
    finally
      DS.Free;
    end;
  except
    Result.Free;
    raise;
  end;
end;

function TRepository<T>.Count: Int64;
var
  V: Variant;
begin
  V := FExecutor.ExecuteScalar('SELECT COUNT(*) AS Total FROM ' + TableNameSQL, []);
  if VarIsNull(V) then
    Exit(0);
  Result := V;
end;

end.
