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

unit uFluentORM;
interface
uses
  System.SysUtils, System.Classes, System.Generics.Collections, System.Variants,
  System.StrUtils, System.Math, Data.DB, uFluentORM.Types;

const
  // Enum literals are not imported by a type alias, so the dialect values are
  // re-exported here to keep code that only uses uFluentORM compiling unchanged.
  dbGeneric = uFluentORM.Types.dbGeneric;
  dbMySQL = uFluentORM.Types.dbMySQL;
  dbPostgreSQL = uFluentORM.Types.dbPostgreSQL;
  dbFirebird = uFluentORM.Types.dbFirebird;
  dbSQLite = uFluentORM.Types.dbSQLite;
  dbMSSQL = uFluentORM.Types.dbMSSQL;

type
  TSQLGeneratedEvent = procedure(Sender: TObject; const ASQL: string) of object;
  TSQLOperator = (opEqual, opNotEqual, opGreater, opLess, 
                  opGreaterOrEqual, opLessOrEqual, opLike, opIn, opNotIn,
                  opBetween, opNotBetween, opIsNull, opIsNotNull);
  
  TSQLOrderDirection = (odAsc, odDesc);
  TSQLJoinType = (jtInner, jtLeft, jtRight, jtFull);
  // TSQLDatabaseType is declared in uFluentORM.Types and kept here for
  // backward compatibility (the enum values dbGeneric/dbMySQL/... are the same).
  TSQLDatabaseType = uFluentORM.Types.TSQLDatabaseType;
  
  TWhereCondition = record
    Field: string;
    Operator: TSQLOperator;
    Value: string;
    Value2: string; // Para BETWEEN
    RawValue: Variant;
    RawValue2: Variant;
    RawValues: TArray<Variant>;
    HasRawValue: Boolean;
    HasRawValue2: Boolean;
    HasRawValues: Boolean;
    IsGroupStart: Boolean;
    IsGroupEnd: Boolean;
    IsAnd: Boolean;
    IsRaw: Boolean; // Para condições raw (sem formatação)
  end;
  
  TOrderByClause = record
    Field: string;
    Direction: TSQLOrderDirection;
  end;
  
  TJoinClause = record
    JoinType: TSQLJoinType;
    Table: string;
    Condition: string;
  end;
  TUnionClause = record
    OperatorText: string;
    SQL: string;
    IsAll: Boolean;
    ParamNames: TArray<string>;
    ParamValues: TArray<Variant>;
  end;
  TCteClause = record
    Name: string;
    SQL: string;
    IsRecursive: Boolean;
    ParamNames: TArray<string>;
    ParamValues: TArray<Variant>;
  end;
  TSQLFormatter = class
  public
    class function Format(const ASQL: string; AIndentSize: Integer = 2): string; static;
  end;
  TSQLBuilder = class
  private
    FSelectFields: TStringList;
    FFromTable: string;
    FWhereConditions: TList<TWhereCondition>;
    FOrderByFields: TList<TOrderByClause>;
    FGroupByFields: TStringList;
    FHavingConditions: TList<TWhereCondition>;
    FJoinClauses: TList<TJoinClause>;
    FUnions: TList<TUnionClause>;
    FCtes: TList<TCteClause>;
    FDistinct: Boolean;
    FLimit: Integer;
    FOffset: Integer;
    FDatabaseType: TSQLDatabaseType;
    FParameters: TStringList;
    FParamValues: TDictionary<string, Variant>;
    FStrictMode: Boolean;
    FUseNamedParams: Boolean;
    FQuoteIdentifiers: Boolean;
    FParamPrefix: string;
    FOnSQLGenerated: TSQLGeneratedEvent;
    
    function GetOperatorText(AOperator: TSQLOperator): string;
    function FormatValue(const AValue: Variant): string;
    function QuoteStringLiteral(const AValue: string): string;
    function FormatDateLiteral(const AValue: TDateTime): string;
    function BuildSQL(ACountOnly: Boolean): string;
    function CreateParamName(const AField: string): string;
    function GetParamPrefix: string;
    function GetParamPlaceholder(const AParamName: string): string;
    procedure AddParameter(const AParamName: string; const AValue: Variant);
    procedure AddGroupMarker(AConditions: TList<TWhereCondition>; AIsStart, AIsAnd: Boolean);
    procedure AddExistsCondition(AConditions: TList<TWhereCondition>; const ASubQuery: string;
      AIsNotExists, AIsAnd: Boolean);
    function StripEndingSemicolon(const ASQL: string): string;
    function CaptureBuilderAsUnionClause(ABuilder: TSQLBuilder; const AOperatorText: string;
      AIsAll: Boolean): TUnionClause;
    function BuildUnionClause(const ASQL, AOperatorText: string; AIsAll: Boolean): TUnionClause;
    function BuildCteClause(const AName, ASQL: string; AIsRecursive: Boolean): TCteClause;
    function CaptureBuilderAsCteClause(const AName: string; ABuilder: TSQLBuilder;
      AIsRecursive: Boolean): TCteClause;
    function IsSimpleIdentifier(const AValue: string): Boolean;
    function QuoteIdentifier(const AValue: string): string;
    function NormalizeIdentifier(const AValue: string): string;
    function NormalizeFieldExpression(const AValue: string): string;
    procedure EnsureRawAllowed;
    procedure Reset;
    function BuildWhereClause: string;
    function BuildJoinClause: string;
    function BuildOrderByClause: string;
    function BuildGroupByClause: string;
    function BuildHavingClause: string;
    function BuildLimitOffsetClause: string;
    procedure NormalizeFieldAndOperator(var AField: string; var AOperator: TSQLOperator);
    
  public
    constructor Create;
    destructor Destroy; override;
    // Configuração
    procedure SetDatabaseType(ADatabaseType: TSQLDatabaseType);
    function GetDatabaseType: TSQLDatabaseType;
    
    // Métodos fluentes - SELECT
    function Select: TSQLBuilder;
    function SelectDistinct: TSQLBuilder;
    function &From(const ATable: string): TSQLBuilder;
    function FromSQL(const ASQL: string; const AAlias: string = ''): TSQLBuilder;
    function Union(const ASQL: string): TSQLBuilder; overload;
    function UnionAll(const ASQL: string): TSQLBuilder; overload;
    function Union(ABuilder: TSQLBuilder): TSQLBuilder; overload;
    function UnionAll(ABuilder: TSQLBuilder): TSQLBuilder; overload;
    function Intersect(const ASQL: string): TSQLBuilder; overload;
    function Intersect(ABuilder: TSQLBuilder): TSQLBuilder; overload;
    function &Except(const ASQL: string): TSQLBuilder; overload;
    function &Except(ABuilder: TSQLBuilder): TSQLBuilder; overload;
    function WithCTE(const AName, ASQL: string): TSQLBuilder; overload;
    function WithCTE(const AName: string; ABuilder: TSQLBuilder): TSQLBuilder; overload;
    function WithRecursiveCTE(const AName, ASQL: string): TSQLBuilder; overload;
    function WithRecursiveCTE(const AName: string; ABuilder: TSQLBuilder): TSQLBuilder; overload;
    
    // Campos
    function Fields(const AFields: string): TSQLBuilder; overload;
    function Fields(AFields: array of string): TSQLBuilder; overload;
    function Field(const AField: string; const AAlias: string = ''): TSQLBuilder; overload;
    function FieldSQL(const ASQL: string; const AAlias: string = ''): TSQLBuilder;
    function All: TSQLBuilder;

    // JOINs
    function Join(const ATable: string; const ACondition: string): TSQLBuilder;
    function LeftJoin(const ATable: string; const ACondition: string): TSQLBuilder;
    function RightJoin(const ATable: string; const ACondition: string): TSQLBuilder;
    function FullJoin(const ATable: string; const ACondition: string): TSQLBuilder;
    
    // WHERE conditions
    function Where(const AField: string; AValue: Variant; 
                   AOperator: TSQLOperator = opEqual): TSQLBuilder; overload;
    function Where(const ACondition: string): TSQLBuilder; overload;
    function WhereRaw(const ACondition: string): TSQLBuilder;
    
    function AndWhere(const AField: string; AValue: Variant; 
                      AOperator: TSQLOperator = opEqual): TSQLBuilder; overload;
    function AndWhere(const ACondition: string): TSQLBuilder; overload;
    function AndWhereRaw(const ACondition: string): TSQLBuilder;
    
    function OrWhere(const AField: string; AValue: Variant; 
                     AOperator: TSQLOperator = opEqual): TSQLBuilder; overload;
    function OrWhere(const ACondition: string): TSQLBuilder; overload;
    function OrWhereRaw(const ACondition: string): TSQLBuilder;
    function WhereExists(const ASubQuery: string): TSQLBuilder;
    function WhereNotExists(const ASubQuery: string): TSQLBuilder;
    function AndWhereExists(const ASubQuery: string): TSQLBuilder;
    function AndWhereNotExists(const ASubQuery: string): TSQLBuilder;
    function OrWhereExists(const ASubQuery: string): TSQLBuilder;
    function OrWhereNotExists(const ASubQuery: string): TSQLBuilder;
    function BeginWhereGroup: TSQLBuilder;
    function AndBeginWhereGroup: TSQLBuilder;
    function OrBeginWhereGroup: TSQLBuilder;
    function EndWhereGroup: TSQLBuilder;
    
    // Where helpers
    function WhereNull(const AField: string): TSQLBuilder;
    function WhereNotNull(const AField: string): TSQLBuilder;
    function WhereBetween(const AField: string; AValue1, AValue2: Variant): TSQLBuilder;
    function WhereNotBetween(const AField: string; AValue1, AValue2: Variant): TSQLBuilder;
    function WhereIn(const AField: string; AValues: array of Variant): TSQLBuilder;
    function WhereNotIn(const AField: string; AValues: array of Variant): TSQLBuilder;
    function WhereLike(const AField, AValue: string): TSQLBuilder;
    
    // AndWhere helpers
    function AndWhereNull(const AField: string): TSQLBuilder;
    function AndWhereNotNull(const AField: string): TSQLBuilder;
    function AndWhereBetween(const AField: string; AValue1, AValue2: Variant): TSQLBuilder;
    function AndWhereLike(const AField, AValue: string): TSQLBuilder;
    // OrWhere helpers
    function OrWhereNull(const AField: string): TSQLBuilder;
    function OrWhereNotNull(const AField: string): TSQLBuilder;
    function OrWhereBetween(const AField: string; AValue1, AValue2: Variant): TSQLBuilder;
    
    // Order By
    function OrderBy(const AField: string; 
                     ADirection: TSQLOrderDirection = odAsc): TSQLBuilder; overload;
    function OrderBy(const AFields: string): TSQLBuilder; overload;
    function OrderByAsc(const AField: string): TSQLBuilder;
    function OrderByDesc(const AField: string): TSQLBuilder;
    function OrderByRaw(const AOrderBy: string): TSQLBuilder;
    
    // Group By
    function GroupBy(const AFields: string): TSQLBuilder; overload;
    function GroupBy(AFields: array of string): TSQLBuilder; overload;
    
    // Having
    function Having(const AField: string; AValue: Variant; 
                    AOperator: TSQLOperator = opEqual): TSQLBuilder;
    function AndHaving(const AField: string; AValue: Variant;
                       AOperator: TSQLOperator = opEqual): TSQLBuilder;
    function OrHaving(const AField: string; AValue: Variant;
                      AOperator: TSQLOperator = opEqual): TSQLBuilder;
    function HavingRaw(const ACondition: string): TSQLBuilder;
    function AndHavingRaw(const ACondition: string): TSQLBuilder;
    function OrHavingRaw(const ACondition: string): TSQLBuilder;
    function HavingExists(const ASubQuery: string): TSQLBuilder;
    function HavingNotExists(const ASubQuery: string): TSQLBuilder;
    function AndHavingExists(const ASubQuery: string): TSQLBuilder;
    function AndHavingNotExists(const ASubQuery: string): TSQLBuilder;
    function OrHavingExists(const ASubQuery: string): TSQLBuilder;
    function OrHavingNotExists(const ASubQuery: string): TSQLBuilder;
    function BeginHavingGroup: TSQLBuilder;
    function AndBeginHavingGroup: TSQLBuilder;
    function OrBeginHavingGroup: TSQLBuilder;
    function EndHavingGroup: TSQLBuilder;
    
    // Limit/Offset
    function Limit(ALimit: Integer): TSQLBuilder;
    function Offset(AOffset: Integer): TSQLBuilder;
    
    // Paginação - CORRIGIDO: Paginate em vez de Paginaté
    function Paginate(APage, APageSize: Integer): TSQLBuilder;
    
    // Geração do SQL
    function ToSQL: string;
    function ToFormattedSQL(AIndentSize: Integer = 2): string;
    function ToSQLCount: string; // CORRIGIDO: Implementado
    function ToFormattedSQLCount(AIndentSize: Integer = 2): string;
    
    // Parâmetros
    function GetParameters: TArray<string>;
    function GetParamValue(const AParamName: string): Variant;
    // Parametros da ultima geracao (ToSQL/ToSQLCount) no formato do executor:
    //   SQLText := B.ToSQL;  Exec.ExecuteScalar(SQLText, B.ToSQLParams);
    function ToSQLParams: TSQLParams;
    
    // Utilitários
    procedure Clear;
    function IsEmpty: Boolean;
    property StrictMode: Boolean read FStrictMode write FStrictMode;
    property UseNamedParams: Boolean read FUseNamedParams write FUseNamedParams;
    property QuoteIdentifiers: Boolean read FQuoteIdentifiers write FQuoteIdentifiers;
    // Prefixo dos placeholders gerados. Padrao ':' (FireDAC, Zeos, UniDAC, ADO e
    // dbExpress reconhecem ':nome' em todos os bancos, inclusive SQL Server).
    property ParamPrefix: string read FParamPrefix write FParamPrefix;
    property OnSQLGenerated: TSQLGeneratedEvent read FOnSQLGenerated write FOnSQLGenerated;
  end;
implementation
function IsSQLIdentChar(const C: Char): Boolean;
begin
  Result := CharInSet(C, ['A'..'Z', 'a'..'z', '0'..'9', '_']);
end;

// Substitui um placeholder de parametro respeitando limites de token,
// evitando que ':cidade' altere ':cidade1' ou um cast PostgreSQL '::tipo'.
function ReplaceParamToken(const ASQL, AOld, ANew: string): string;
var
  P, StartPos, L: Integer;
  NextCh, PrevCh: Char;
begin
  if AOld = '' then
    Exit(ASQL);
  Result := '';
  StartPos := 1;
  L := Length(AOld);
  P := PosEx(AOld, ASQL, StartPos);
  while P > 0 do
  begin
    if P + L <= Length(ASQL) then
      NextCh := ASQL[P + L]
    else
      NextCh := #0;
    if P > 1 then
      PrevCh := ASQL[P - 1]
    else
      PrevCh := #0;
    if IsSQLIdentChar(NextCh) or (PrevCh = ':') or IsSQLIdentChar(PrevCh) then
      Result := Result + Copy(ASQL, StartPos, P - StartPos + L)
    else
      Result := Result + Copy(ASQL, StartPos, P - StartPos) + ANew;
    StartPos := P + L;
    P := PosEx(AOld, ASQL, StartPos);
  end;
  Result := Result + Copy(ASQL, StartPos, MaxInt);
end;

// Splits a comma separated SQL list honouring parentheses and quotes, so
// expressions like CAST(x AS DECIMAL(10,2)) are not broken in the middle.
function SplitSQLList(const AValue: string; ASeparator: Char): TArray<string>;
var
  I, StartPos, Depth: Integer;
  Quote: Char;
  Parts: TList<string>;
begin
  Parts := TList<string>.Create;
  try
    Quote := #0;
    Depth := 0;
    StartPos := 1;
    for I := 1 to Length(AValue) do
    begin
      if Quote <> #0 then
      begin
        if AValue[I] = Quote then
          Quote := #0;
      end
      else
      begin
        case AValue[I] of
          '''': Quote := '''';
          '"': Quote := '"';
          '`': Quote := '`';
          '[': Quote := ']';
          '(': Inc(Depth);
          ')':
            if Depth > 0 then
              Dec(Depth);
        end;

        if (AValue[I] = ASeparator) and (Depth = 0) and (Quote = #0) then
        begin
          Parts.Add(Trim(Copy(AValue, StartPos, I - StartPos)));
          StartPos := I + 1;
        end;
      end;
    end;
    Parts.Add(Trim(Copy(AValue, StartPos, MaxInt)));
    Result := Parts.ToArray;
  finally
    Parts.Free;
  end;
end;

{ TSQLFormatter }
class function TSQLFormatter.Format(const ASQL: string; AIndentSize: Integer): string;
type
  TClauseKind = (ckNone, ckSelect, ckWhere, ckHaving, ckGroupBy, ckOrderBy, ckOther);
var
  I: Integer;
  Ch: Char;
  InQuote: Boolean;
  QuoteChar: Char;
  Token: string;
  Tokens: TStringList;
  Lines: TStringList;
  CurrentLine: string;
  Indent: string;
  KeepSemicolon: Boolean;
  ClauseKind: TClauseKind;
  procedure PushToken;
  begin
    if Token <> '' then
    begin
      Tokens.Add(Token);
      Token := '';
    end;
  end;
  function UpperToken(AIndex: Integer): string;
  begin
    if (AIndex >= 0) and (AIndex < Tokens.Count) then
      Result := UpperCase(Tokens[AIndex])
    else
      Result := '';
  end;
  procedure FlushCurrentLine;
  begin
    if Trim(CurrentLine) <> '' then
    begin
      Lines.Add(TrimRight(CurrentLine));
      CurrentLine := '';
    end;
  end;
  procedure StartClause(const AClauseText: string; AKind: TClauseKind);
  begin
    FlushCurrentLine;
    if AKind = ckSelect then
    begin
      Lines.Add(AClauseText);
      CurrentLine := '';
    end
    else
      CurrentLine := AClauseText;
    ClauseKind := AKind;
  end;
  procedure AppendToken(const AValue: string);
  begin
    if CurrentLine = '' then
    begin
      if ClauseKind = ckSelect then
        CurrentLine := Indent + AValue
      else
        CurrentLine := AValue;
    end
    else
      CurrentLine := CurrentLine + ' ' + AValue;
  end;
begin
  if AIndentSize <= 0 then
    AIndentSize := 2;
  Indent := StringOfChar(' ', AIndentSize);
  Tokens := TStringList.Create;
  Lines := TStringList.Create;
  try
    Token := '';
    InQuote := False;
    QuoteChar := #0;
    for I := 1 to Length(ASQL) do
    begin
      Ch := ASQL[I];
      if InQuote then
      begin
        Token := Token + Ch;
        if Ch = QuoteChar then
          InQuote := False;
      end
      else
      begin
        if (Ch = '''') or (Ch = '"') or (Ch = '`') or (Ch = '[') then
        begin
          InQuote := True;
          if Ch = '[' then
            QuoteChar := ']'
          else
            QuoteChar := Ch;
          Token := Token + Ch;
        end
        else if Ch <= ' ' then
          PushToken
        else
          Token := Token + Ch;
      end;
    end;
    PushToken;
    if Tokens.Count = 0 then
      Exit('');
    KeepSemicolon := False;
    if EndsText(';', Tokens[Tokens.Count - 1]) then
    begin
      Tokens[Tokens.Count - 1] := Trim(Copy(Tokens[Tokens.Count - 1], 1, Length(Tokens[Tokens.Count - 1]) - 1));
      KeepSemicolon := True;
      if Tokens[Tokens.Count - 1] = '' then
        Tokens.Delete(Tokens.Count - 1);
    end;
    ClauseKind := ckNone;
    CurrentLine := '';
    I := 0;
    while I < Tokens.Count do
    begin
      if UpperToken(I) = 'SELECT' then
      begin
        StartClause('SELECT', ckSelect);
        Inc(I);
        Continue;
      end;
      if UpperToken(I) = 'FROM' then
      begin
        StartClause('FROM', ckOther);
        Inc(I);
        Continue;
      end;
      if (UpperToken(I) = 'INNER') and (UpperToken(I + 1) = 'JOIN') then
      begin
        StartClause('INNER JOIN', ckOther);
        Inc(I, 2);
        Continue;
      end;
      if (UpperToken(I) = 'LEFT') and (UpperToken(I + 1) = 'JOIN') then
      begin
        StartClause('LEFT JOIN', ckOther);
        Inc(I, 2);
        Continue;
      end;
      if (UpperToken(I) = 'RIGHT') and (UpperToken(I + 1) = 'JOIN') then
      begin
        StartClause('RIGHT JOIN', ckOther);
        Inc(I, 2);
        Continue;
      end;
      if (UpperToken(I) = 'FULL') and (UpperToken(I + 1) = 'JOIN') then
      begin
        StartClause('FULL JOIN', ckOther);
        Inc(I, 2);
        Continue;
      end;
      if UpperToken(I) = 'JOIN' then
      begin
        StartClause('JOIN', ckOther);
        Inc(I);
        Continue;
      end;
      if UpperToken(I) = 'WHERE' then
      begin
        StartClause('WHERE', ckWhere);
        Inc(I);
        Continue;
      end;
      if (UpperToken(I) = 'GROUP') and (UpperToken(I + 1) = 'BY') then
      begin
        StartClause('GROUP BY', ckGroupBy);
        Inc(I, 2);
        Continue;
      end;
      if UpperToken(I) = 'HAVING' then
      begin
        StartClause('HAVING', ckHaving);
        Inc(I);
        Continue;
      end;
      if (UpperToken(I) = 'ORDER') and (UpperToken(I + 1) = 'BY') then
      begin
        StartClause('ORDER BY', ckOrderBy);
        Inc(I, 2);
        Continue;
      end;
      if UpperToken(I) = 'LIMIT' then
      begin
        StartClause('LIMIT', ckOther);
        Inc(I);
        Continue;
      end;
      if UpperToken(I) = 'OFFSET' then
      begin
        StartClause('OFFSET', ckOther);
        Inc(I);
        Continue;
      end;
      if (UpperToken(I) = 'UNION') or (UpperToken(I) = 'INTERSECT') or
         (UpperToken(I) = 'EXCEPT') then
      begin
        StartClause(UpperToken(I), ckOther);
        Inc(I);
        Continue;
      end;
      if (ClauseKind in [ckWhere, ckHaving]) and
         ((UpperToken(I) = 'AND') or (UpperToken(I) = 'OR')) then
      begin
        FlushCurrentLine;
        CurrentLine := Indent + UpperToken(I);
        Inc(I);
        Continue;
      end;
      AppendToken(Tokens[I]);
      if (ClauseKind in [ckSelect, ckGroupBy, ckOrderBy]) and
         EndsText(',', Tokens[I]) then
        FlushCurrentLine;
      Inc(I);
    end;
    FlushCurrentLine;
    Result := TrimRight(Lines.Text);
    if KeepSemicolon then
      Result := Result + ';';
  finally
    Tokens.Free;
    Lines.Free;
  end;
end;

{ TSQLBuilder }
constructor TSQLBuilder.Create;
begin
  inherited Create;
  FSelectFields := TStringList.Create;
  FWhereConditions := TList<TWhereCondition>.Create;
  FOrderByFields := TList<TOrderByClause>.Create;
  FGroupByFields := TStringList.Create;
  FHavingConditions := TList<TWhereCondition>.Create;
  FJoinClauses := TList<TJoinClause>.Create;
  FUnions := TList<TUnionClause>.Create;
  FCtes := TList<TCteClause>.Create;
  FParameters := TStringList.Create;
  FParamValues := TDictionary<string, Variant>.Create;
  FDatabaseType := dbGeneric;
  FStrictMode := True;
  FUseNamedParams := True;
  FQuoteIdentifiers := False;
  FParamPrefix := ':';
  Reset;
end;

destructor TSQLBuilder.Destroy;
begin
  FSelectFields.Free;
  FWhereConditions.Free;
  FOrderByFields.Free;
  FGroupByFields.Free;
  FHavingConditions.Free;
  FJoinClauses.Free;
  FUnions.Free;
  FCtes.Free;
  FParamValues.Free;
  FParameters.Free;
  inherited;
end;

procedure TSQLBuilder.SetDatabaseType(ADatabaseType: TSQLDatabaseType);
begin
  FDatabaseType := ADatabaseType;
end;

function TSQLBuilder.GetDatabaseType: TSQLDatabaseType;
begin
  Result := FDatabaseType;
end;

procedure TSQLBuilder.Reset;
begin
  FSelectFields.Clear;
  FFromTable := '';
  FWhereConditions.Clear;
  FOrderByFields.Clear;
  FGroupByFields.Clear;
  FHavingConditions.Clear;
  FJoinClauses.Clear;
  FUnions.Clear;
  FCtes.Clear;
  FParameters.Clear;
  FParamValues.Clear;
  FDistinct := False;
  FLimit := 0;
  FOffset := 0;
end;

procedure TSQLBuilder.Clear;
begin
  Reset;
end;

function TSQLBuilder.IsEmpty: Boolean;
begin
  Result := (FFromTable = '') and (FSelectFields.Count = 0);
end;

function TSQLBuilder.Select: TSQLBuilder;
begin
  Reset;
  FDistinct := False;
  Result := Self;
end;

function TSQLBuilder.SelectDistinct: TSQLBuilder;
begin
  Reset;
  FDistinct := True;
  Result := Self;
end;

function TSQLBuilder.&From(const ATable: string): TSQLBuilder;
begin
  FFromTable := NormalizeIdentifier(ATable);
  Result := Self;
end;

function TSQLBuilder.FromSQL(const ASQL: string; const AAlias: string): TSQLBuilder;
begin
  EnsureRawAllowed;
  if AAlias <> '' then
    FFromTable := '(' + ASQL + ') ' + NormalizeIdentifier(AAlias)
  else
    FFromTable := '(' + ASQL + ')';
  Result := Self;
end;
function TSQLBuilder.StripEndingSemicolon(const ASQL: string): string;
begin
  Result := Trim(ASQL);
  while (Result <> '') and CharInSet(Result[Length(Result)], [';', ' ']) do
    Delete(Result, Length(Result), 1);
end;
function TSQLBuilder.BuildUnionClause(const ASQL, AOperatorText: string;
  AIsAll: Boolean): TUnionClause;
begin
  Result := Default(TUnionClause);
  Result.SQL := StripEndingSemicolon(ASQL);
  Result.OperatorText := AOperatorText;
  Result.IsAll := AIsAll;
end;
function TSQLBuilder.CaptureBuilderAsUnionClause(ABuilder: TSQLBuilder;
  const AOperatorText: string; AIsAll: Boolean): TUnionClause;
var
  I: Integer;
  PName: string;
  Params: TArray<string>;
begin
  if ABuilder = nil then
    raise Exception.Create('Set operation builder cannot be nil.');
  Result := BuildUnionClause(ABuilder.ToSQL, AOperatorText, AIsAll);
  Params := ABuilder.GetParameters;
  SetLength(Result.ParamNames, Length(Params));
  SetLength(Result.ParamValues, Length(Params));
  for I := 0 to High(Result.ParamNames) do
  begin
    PName := Params[I];
    Result.ParamNames[I] := PName;
    Result.ParamValues[I] := ABuilder.GetParamValue(PName);
  end;
end;
function TSQLBuilder.BuildCteClause(const AName, ASQL: string;
  AIsRecursive: Boolean): TCteClause;
begin
  Result := Default(TCteClause);
  if Trim(AName) = '' then
    raise Exception.Create('CTE name cannot be empty.');
  if FQuoteIdentifiers and IsSimpleIdentifier(Trim(AName)) then
    Result.Name := NormalizeIdentifier(AName)
  else
    Result.Name := Trim(AName);
  Result.SQL := StripEndingSemicolon(ASQL);
  Result.IsRecursive := AIsRecursive;
end;
function TSQLBuilder.CaptureBuilderAsCteClause(const AName: string;
  ABuilder: TSQLBuilder; AIsRecursive: Boolean): TCteClause;
var
  I: Integer;
  PName: string;
  Params: TArray<string>;
begin
  if ABuilder = nil then
    raise Exception.Create('CTE builder cannot be nil.');
  Result := BuildCteClause(AName, ABuilder.ToSQL, AIsRecursive);
  Params := ABuilder.GetParameters;
  SetLength(Result.ParamNames, Length(Params));
  SetLength(Result.ParamValues, Length(Params));
  for I := 0 to High(Result.ParamNames) do
  begin
    PName := Params[I];
    Result.ParamNames[I] := PName;
    Result.ParamValues[I] := ABuilder.GetParamValue(PName);
  end;
end;
function TSQLBuilder.Union(const ASQL: string): TSQLBuilder;
begin
  EnsureRawAllowed;
  FUnions.Add(BuildUnionClause(ASQL, 'UNION', False));
  Result := Self;
end;
function TSQLBuilder.UnionAll(const ASQL: string): TSQLBuilder;
begin
  EnsureRawAllowed;
  FUnions.Add(BuildUnionClause(ASQL, 'UNION', True));
  Result := Self;
end;
function TSQLBuilder.Union(ABuilder: TSQLBuilder): TSQLBuilder;
begin
  FUnions.Add(CaptureBuilderAsUnionClause(ABuilder, 'UNION', False));
  Result := Self;
end;
function TSQLBuilder.UnionAll(ABuilder: TSQLBuilder): TSQLBuilder;
begin
  FUnions.Add(CaptureBuilderAsUnionClause(ABuilder, 'UNION', True));
  Result := Self;
end;
function TSQLBuilder.Intersect(const ASQL: string): TSQLBuilder;
begin
  EnsureRawAllowed;
  FUnions.Add(BuildUnionClause(ASQL, 'INTERSECT', False));
  Result := Self;
end;
function TSQLBuilder.Intersect(ABuilder: TSQLBuilder): TSQLBuilder;
begin
  FUnions.Add(CaptureBuilderAsUnionClause(ABuilder, 'INTERSECT', False));
  Result := Self;
end;
function TSQLBuilder.&Except(const ASQL: string): TSQLBuilder;
begin
  EnsureRawAllowed;
  FUnions.Add(BuildUnionClause(ASQL, 'EXCEPT', False));
  Result := Self;
end;
function TSQLBuilder.&Except(ABuilder: TSQLBuilder): TSQLBuilder;
begin
  FUnions.Add(CaptureBuilderAsUnionClause(ABuilder, 'EXCEPT', False));
  Result := Self;
end;
function TSQLBuilder.WithCTE(const AName, ASQL: string): TSQLBuilder;
begin
  EnsureRawAllowed;
  FCtes.Add(BuildCteClause(AName, ASQL, False));
  Result := Self;
end;
function TSQLBuilder.WithCTE(const AName: string; ABuilder: TSQLBuilder): TSQLBuilder;
begin
  FCtes.Add(CaptureBuilderAsCteClause(AName, ABuilder, False));
  Result := Self;
end;
function TSQLBuilder.WithRecursiveCTE(const AName, ASQL: string): TSQLBuilder;
begin
  EnsureRawAllowed;
  FCtes.Add(BuildCteClause(AName, ASQL, True));
  Result := Self;
end;
function TSQLBuilder.WithRecursiveCTE(const AName: string; ABuilder: TSQLBuilder): TSQLBuilder;
begin
  FCtes.Add(CaptureBuilderAsCteClause(AName, ABuilder, True));
  Result := Self;
end;

function TSQLBuilder.Fields(const AFields: string): TSQLBuilder;
var
  FieldArray: TArray<string>;
  FieldName: string;
begin
  // Divide apenas nas virgulas de nivel zero (preserva CAST(x AS DECIMAL(10,2)))
  FieldArray := SplitSQLList(AFields, ',');
  for FieldName in FieldArray do
    if FieldName <> '' then
      FSelectFields.Add(NormalizeFieldExpression(FieldName));
  Result := Self;
end;

function TSQLBuilder.Fields(AFields: array of string): TSQLBuilder;
var
  I: Integer;
begin
  for I := Low(AFields) to High(AFields) do
    FSelectFields.Add(NormalizeFieldExpression(AFields[I]));
  Result := Self;
end;

function TSQLBuilder.Field(const AField, AAlias: string): TSQLBuilder;
begin
  if AAlias <> '' then
    FSelectFields.Add(NormalizeFieldExpression(AField) + ' AS ' + NormalizeIdentifier(AAlias))
  else
    FSelectFields.Add(NormalizeFieldExpression(AField));
  Result := Self;
end;

function TSQLBuilder.FieldSQL(const ASQL, AAlias: string): TSQLBuilder;
begin
  if AAlias <> '' then
    FSelectFields.Add('(' + ASQL + ') AS ' + NormalizeIdentifier(AAlias))
  else
    FSelectFields.Add('(' + ASQL + ')');
  Result := Self;
end;

function TSQLBuilder.All: TSQLBuilder;
begin
  FSelectFields.Add('*');
  Result := Self;
end;

function TSQLBuilder.Join(const ATable, ACondition: string): TSQLBuilder;
var
  JoinClause: TJoinClause;
begin
  JoinClause.JoinType := jtInner;
  JoinClause.Table := NormalizeIdentifier(ATable);
  JoinClause.Condition := ACondition;
  FJoinClauses.Add(JoinClause);
  Result := Self;
end;

function TSQLBuilder.LeftJoin(const ATable, ACondition: string): TSQLBuilder;
var
  JoinClause: TJoinClause;
begin
  JoinClause.JoinType := jtLeft;
  JoinClause.Table := NormalizeIdentifier(ATable);
  JoinClause.Condition := ACondition;
  FJoinClauses.Add(JoinClause);
  Result := Self;
end;

function TSQLBuilder.RightJoin(const ATable, ACondition: string): TSQLBuilder;
var
  JoinClause: TJoinClause;
begin
  JoinClause.JoinType := jtRight;
  JoinClause.Table := NormalizeIdentifier(ATable);
  JoinClause.Condition := ACondition;
  FJoinClauses.Add(JoinClause);
  Result := Self;
end;

function TSQLBuilder.FullJoin(const ATable, ACondition: string): TSQLBuilder;
var
  JoinClause: TJoinClause;
begin
  JoinClause.JoinType := jtFull;
  JoinClause.Table := NormalizeIdentifier(ATable);
  JoinClause.Condition := ACondition;
  FJoinClauses.Add(JoinClause);
  Result := Self;
end;

function TSQLBuilder.CreateParamName(const AField: string): string;
var
  BaseName, FinalName: string;
  I, Counter: Integer;
  C: Char;
begin
  BaseName := '';
  for I := 1 to Length(AField) do
  begin
    C := AField[I];
    if CharInSet(C, ['A'..'Z', 'a'..'z', '0'..'9', '_']) then
      BaseName := BaseName + C
    else
      BaseName := BaseName + '_';
  end;
  while Pos('__', BaseName) > 0 do
    BaseName := StringReplace(BaseName, '__', '_', [rfReplaceAll]);
  while (BaseName <> '') and (BaseName[1] = '_') do
    Delete(BaseName, 1, 1);
  while (BaseName <> '') and (BaseName[Length(BaseName)] = '_') do
    Delete(BaseName, Length(BaseName), 1);
  if BaseName = '' then
    BaseName := 'p';
  
  FinalName := BaseName;
  Counter := 1;
  
  while FParameters.IndexOf(FinalName) >= 0 do
  begin
    FinalName := BaseName + Counter.ToString;
    Inc(Counter);
  end;
  
  FParameters.Add(FinalName);
  Result := FinalName;
end;
function TSQLBuilder.GetParamPrefix: string;
begin
  // Antes o MSSQL usava '@', mas os componentes Delphi (FireDAC inclusive)
  // so reconhecem ':nome' como parametro; '@nome' virava variavel T-SQL nao
  // declarada ("Must declare the scalar variable").
  Result := FParamPrefix;
  if Result = '' then
    Result := ':';
end;
function TSQLBuilder.GetParamPlaceholder(const AParamName: string): string;
begin
  Result := GetParamPrefix + AParamName;
end;
procedure TSQLBuilder.AddParameter(const AParamName: string; const AValue: Variant);
begin
  FParamValues.AddOrSetValue(AParamName, AValue);
end;
procedure TSQLBuilder.AddGroupMarker(AConditions: TList<TWhereCondition>; AIsStart,
  AIsAnd: Boolean);
var
  Condition: TWhereCondition;
begin
  Condition := Default(TWhereCondition);
  Condition.IsGroupStart := AIsStart;
  Condition.IsGroupEnd := not AIsStart;
  Condition.IsAnd := AIsAnd;
  Condition.IsRaw := False;
  AConditions.Add(Condition);
end;
procedure TSQLBuilder.AddExistsCondition(AConditions: TList<TWhereCondition>;
  const ASubQuery: string; AIsNotExists, AIsAnd: Boolean);
var
  Condition: TWhereCondition;
  ClauseText: string;
begin
  if Trim(ASubQuery) = '' then
    raise Exception.Create('SubQuery cannot be empty for EXISTS/NOT EXISTS.');
  Condition := Default(TWhereCondition);
  if AIsNotExists then
    ClauseText := 'NOT EXISTS (' + Trim(ASubQuery) + ')'
  else
    ClauseText := 'EXISTS (' + Trim(ASubQuery) + ')';
  Condition.Field := '';
  Condition.Operator := opEqual;
  Condition.Value := ClauseText;
  Condition.Value2 := '';
  Condition.RawValue := Null;
  Condition.RawValue2 := Null;
  Condition.HasRawValue := False;
  Condition.HasRawValue2 := False;
  Condition.IsAnd := AIsAnd;
  Condition.IsRaw := True;
  AConditions.Add(Condition);
end;
function TSQLBuilder.IsSimpleIdentifier(const AValue: string): Boolean;
begin
  Result := TSQLDialect.IsSimpleIdentifier(AValue);
end;
function TSQLBuilder.QuoteIdentifier(const AValue: string): string;
begin
  Result := TSQLDialect.QuoteIdentifier(AValue, FDatabaseType);
end;
function TSQLBuilder.NormalizeIdentifier(const AValue: string): string;
begin
  if FQuoteIdentifiers then
    Result := QuoteIdentifier(Trim(AValue))
  else
    Result := Trim(AValue);
end;
function TSQLBuilder.NormalizeFieldExpression(const AValue: string): string;
var
  S, U: string;
  P: Integer;
  LeftPart, RightPart: string;
begin
  S := Trim(AValue);
  if S = '' then
    Exit(S);
  if not FQuoteIdentifiers then
    Exit(S);
  U := UpperCase(S);
  P := Pos(' AS ', U);
  if P > 0 then
  begin
    LeftPart := Trim(Copy(S, 1, P - 1));
    RightPart := Trim(Copy(S, P + 4, MaxInt));
    Result := NormalizeIdentifier(LeftPart) + ' AS ' + NormalizeIdentifier(RightPart);
    Exit;
  end;
  // Alias sem AS: "campo alias" (somente caso simples)
  P := LastDelimiter(' ', S);
  if P > 0 then
  begin
    LeftPart := Trim(Copy(S, 1, P - 1));
    RightPart := Trim(Copy(S, P + 1, MaxInt));
    if IsSimpleIdentifier(LeftPart) and IsSimpleIdentifier(RightPart) then
    begin
      Result := NormalizeIdentifier(LeftPart) + ' ' + NormalizeIdentifier(RightPart);
      Exit;
    end;
  end;
  if IsSimpleIdentifier(S) then
    Result := NormalizeIdentifier(S)
  else
    Result := S;
end;
procedure TSQLBuilder.EnsureRawAllowed;
begin
  if FStrictMode then
    raise Exception.Create('Raw SQL is disabled in StrictMode.');
end;

function TSQLBuilder.GetOperatorText(AOperator: TSQLOperator): string;
begin
  case AOperator of
    opEqual: Result := '=';
    opNotEqual: Result := '<>';
    opGreater: Result := '>';
    opLess: Result := '<';
    opGreaterOrEqual: Result := '>=';
    opLessOrEqual: Result := '<=';
    opLike: Result := 'LIKE';
    opIn: Result := 'IN';
    opNotIn: Result := 'NOT IN';
    opBetween: Result := 'BETWEEN';
    opNotBetween: Result := 'NOT BETWEEN';
    opIsNull: Result := 'IS NULL';
    opIsNotNull: Result := 'IS NOT NULL';
  else
    Result := '=';
  end;
end;

procedure TSQLBuilder.NormalizeFieldAndOperator(var AField: string; var AOperator: TSQLOperator);
var
  UpperField: string;
begin
  AField := Trim(AField);
  UpperField := UpperCase(AField);
  if (Length(UpperField) >= 2) and (Copy(UpperField, Length(UpperField) - 1, 2) = '>=') then
  begin
    AField := Trim(Copy(AField, 1, Length(AField) - 2));
    if AOperator = opEqual then
      AOperator := opGreaterOrEqual;
    Exit;
  end;
  if (Length(UpperField) >= 2) and (Copy(UpperField, Length(UpperField) - 1, 2) = '<=') then
  begin
    AField := Trim(Copy(AField, 1, Length(AField) - 2));
    if AOperator = opEqual then
      AOperator := opLessOrEqual;
    Exit;
  end;
  if (Length(UpperField) >= 2) and (Copy(UpperField, Length(UpperField) - 1, 2) = '<>') then
  begin
    AField := Trim(Copy(AField, 1, Length(AField) - 2));
    if AOperator = opEqual then
      AOperator := opNotEqual;
    Exit;
  end;
  if (Length(UpperField) >= 1) and (Copy(UpperField, Length(UpperField), 1) = '>') then
  begin
    AField := Trim(Copy(AField, 1, Length(AField) - 1));
    if AOperator = opEqual then
      AOperator := opGreater;
    Exit;
  end;
  if (Length(UpperField) >= 1) and (Copy(UpperField, Length(UpperField), 1) = '<') then
  begin
    AField := Trim(Copy(AField, 1, Length(AField) - 1));
    if AOperator = opEqual then
      AOperator := opLess;
    Exit;
  end;
  if (Length(UpperField) >= 1) and (Copy(UpperField, Length(UpperField), 1) = '=') then
  begin
    AField := Trim(Copy(AField, 1, Length(AField) - 1));
    Exit;
  end;
end;
function TSQLBuilder.QuoteStringLiteral(const AValue: string): string;
var
  S: string;
begin
  S := StringReplace(AValue, '''', '''''', [rfReplaceAll]);
  // MySQL (sem NO_BACKSLASH_ESCAPES) interpreta '\' como escape dentro de
  // literais: sem duplicar a barra, um valor terminado em '\' quebra o SQL.
  if FDatabaseType = dbMySQL then
    S := StringReplace(S, '\', '\\', [rfReplaceAll]);
  // SQL Server: prefixo N preserva caracteres Unicode (acentos, emojis etc.)
  if FDatabaseType = dbMSSQL then
    Result := 'N''' + S + ''''
  else
    Result := '''' + S + '''';
end;

function TSQLBuilder.FormatDateLiteral(const AValue: TDateTime): string;
var
  FS: TFormatSettings;
  HasTime: Boolean;
begin
  FS := TFormatSettings.Create;
  FS.DateSeparator := '-';
  FS.TimeSeparator := ':';
  FS.DecimalSeparator := '.';
  HasTime := Frac(AValue) <> 0;
  case FDatabaseType of
    dbMSSQL:
      // Formatos ISO independentes de SET LANGUAGE / SET DATEFORMAT.
      // ('yyyy-mm-dd' e interpretado como yyyy-dd-mm em DATETIME com idioma PT/FR.)
      if HasTime then
        Result := '''' + FormatDateTime('yyyy-mm-dd"T"hh:nn:ss.zzz', AValue, FS) + ''''
      else
        Result := '''' + FormatDateTime('yyyymmdd', AValue, FS) + '''';
  else
    if HasTime then
      Result := '''' + FormatDateTime('yyyy-mm-dd hh:nn:ss', AValue, FS) + ''''
    else
      Result := '''' + FormatDateTime('yyyy-mm-dd', AValue, FS) + '''';
  end;
end;

function TSQLBuilder.FormatValue(const AValue: Variant): string;
var
  InvariantFS: TFormatSettings;
begin
  if VarIsNull(AValue) or VarIsEmpty(AValue) then
    Exit('NULL');

  InvariantFS := TFormatSettings.Create;
  InvariantFS.DecimalSeparator := '.';
  InvariantFS.ThousandSeparator := #0;

  case VarType(AValue) and varTypeMask of
    varString, varUString, varOleStr:
      Result := QuoteStringLiteral(VarToStr(AValue));
    varDate:
      Result := FormatDateLiteral(VarToDateTime(AValue));
    varBoolean:
      if FDatabaseType = dbPostgreSQL then
        Result := IfThen(Boolean(AValue), 'TRUE', 'FALSE')
      else
        Result := IfThen(Boolean(AValue), '1', '0');
    varSmallint, varInteger, varShortInt, varByte, varWord, varLongWord,
    varInt64, varUInt64:
      Result := VarToStr(AValue);
    varSingle, varDouble, varCurrency:
      Result := FloatToStr(Double(AValue), InvariantFS);
  else
    if VarIsNumeric(AValue) then
      Result := FloatToStr(Double(AValue), InvariantFS)
    else
      Result := QuoteStringLiteral(VarToStr(AValue));
  end;
end;
function TSQLBuilder.Where(const AField: string; AValue: Variant;
                           AOperator: TSQLOperator): TSQLBuilder;
var
  Condition: TWhereCondition;
  LocalField: string;
  LocalOperator: TSQLOperator;
begin
  Condition := Default(TWhereCondition);
  LocalField := AField;
  LocalOperator := AOperator;
  NormalizeFieldAndOperator(LocalField, LocalOperator);
  if VarIsNull(AValue) or VarIsEmpty(AValue) then
  begin
    if LocalOperator = opEqual then
      LocalOperator := opIsNull
    else if LocalOperator = opNotEqual then
      LocalOperator := opIsNotNull
    else
      raise Exception.Create('NULL value supports only opEqual or opNotEqual.');
  end;
  Condition.Field := NormalizeIdentifier(LocalField);
  Condition.Operator := LocalOperator;
  if LocalOperator in [opIsNull, opIsNotNull] then
    Condition.Value := ''
  else
    Condition.Value := FormatValue(AValue);
  Condition.Value2 := '';
  Condition.RawValue := AValue;
  Condition.RawValue2 := Null;
  Condition.HasRawValue := True;
  Condition.HasRawValue2 := False;
  Condition.IsAnd := True;
  Condition.IsRaw := False;
  FWhereConditions.Add(Condition);
  Result := Self;
end;
function TSQLBuilder.Where(const ACondition: string): TSQLBuilder;
var
  Condition: TWhereCondition;
begin
  Condition := Default(TWhereCondition);
  EnsureRawAllowed;
  Condition.Field := '';
  Condition.Operator := opEqual;
  Condition.Value := ACondition;
  Condition.Value2 := '';
  Condition.RawValue := Null;
  Condition.RawValue2 := Null;
  Condition.HasRawValue := False;
  Condition.HasRawValue2 := False;
  Condition.IsAnd := True;
  Condition.IsRaw := True;
  FWhereConditions.Add(Condition);
  Result := Self;
end;
function TSQLBuilder.WhereRaw(const ACondition: string): TSQLBuilder;
var
  Condition: TWhereCondition;
begin
  Condition := Default(TWhereCondition);
  EnsureRawAllowed;
  Condition.Field := '';
  Condition.Operator := opEqual;
  Condition.Value := ACondition;
  Condition.Value2 := '';
  Condition.RawValue := Null;
  Condition.RawValue2 := Null;
  Condition.HasRawValue := False;
  Condition.HasRawValue2 := False;
  Condition.IsAnd := True;
  Condition.IsRaw := True;
  FWhereConditions.Add(Condition);
  Result := Self;
end;
function TSQLBuilder.AndWhere(const AField: string; AValue: Variant; 
                              AOperator: TSQLOperator): TSQLBuilder;
var
  Condition: TWhereCondition;
  LocalField: string;
  LocalOperator: TSQLOperator;
begin
  Condition := Default(TWhereCondition);
  LocalField := AField;
  LocalOperator := AOperator;
  NormalizeFieldAndOperator(LocalField, LocalOperator);
  if VarIsNull(AValue) or VarIsEmpty(AValue) then
  begin
    if LocalOperator = opEqual then
      LocalOperator := opIsNull
    else if LocalOperator = opNotEqual then
      LocalOperator := opIsNotNull
    else
      raise Exception.Create('NULL value supports only opEqual or opNotEqual.');
  end;
  Condition.Field := NormalizeIdentifier(LocalField);
  Condition.Operator := LocalOperator;
  if LocalOperator in [opIsNull, opIsNotNull] then
    Condition.Value := ''
  else
    Condition.Value := FormatValue(AValue);
  Condition.Value2 := '';
  Condition.RawValue := AValue;
  Condition.RawValue2 := Null;
  Condition.HasRawValue := True;
  Condition.HasRawValue2 := False;
  Condition.IsAnd := True;
  Condition.IsRaw := False;
  FWhereConditions.Add(Condition);
  Result := Self;
end;
function TSQLBuilder.AndWhere(const ACondition: string): TSQLBuilder;
begin
  Result := AndWhereRaw(ACondition);
end;
function TSQLBuilder.AndWhereRaw(const ACondition: string): TSQLBuilder;
var
  Condition: TWhereCondition;
begin
  Condition := Default(TWhereCondition);
  EnsureRawAllowed;
  Condition.Field := '';
  Condition.Operator := opEqual;
  Condition.Value := ACondition;
  Condition.Value2 := '';
  Condition.RawValue := Null;
  Condition.RawValue2 := Null;
  Condition.HasRawValue := False;
  Condition.HasRawValue2 := False;
  Condition.IsAnd := True;
  Condition.IsRaw := True;
  FWhereConditions.Add(Condition);
  Result := Self;
end;
function TSQLBuilder.OrWhere(const AField: string; AValue: Variant; 
                             AOperator: TSQLOperator): TSQLBuilder;
var
  Condition: TWhereCondition;
  LocalField: string;
  LocalOperator: TSQLOperator;
begin
  Condition := Default(TWhereCondition);
  LocalField := AField;
  LocalOperator := AOperator;
  NormalizeFieldAndOperator(LocalField, LocalOperator);
  if VarIsNull(AValue) or VarIsEmpty(AValue) then
  begin
    if LocalOperator = opEqual then
      LocalOperator := opIsNull
    else if LocalOperator = opNotEqual then
      LocalOperator := opIsNotNull
    else
      raise Exception.Create('NULL value supports only opEqual or opNotEqual.');
  end;
  Condition.Field := NormalizeIdentifier(LocalField);
  Condition.Operator := LocalOperator;
  if LocalOperator in [opIsNull, opIsNotNull] then
    Condition.Value := ''
  else
    Condition.Value := FormatValue(AValue);
  Condition.Value2 := '';
  Condition.RawValue := AValue;
  Condition.RawValue2 := Null;
  Condition.HasRawValue := True;
  Condition.HasRawValue2 := False;
  Condition.IsAnd := False;
  Condition.IsRaw := False;
  FWhereConditions.Add(Condition);
  Result := Self;
end;
function TSQLBuilder.OrWhere(const ACondition: string): TSQLBuilder;
begin
  Result := OrWhereRaw(ACondition);
end;
function TSQLBuilder.OrWhereRaw(const ACondition: string): TSQLBuilder;
var
  Condition: TWhereCondition;
begin
  Condition := Default(TWhereCondition);
  EnsureRawAllowed;
  Condition.Field := '';
  Condition.Operator := opEqual;
  Condition.Value := ACondition;
  Condition.Value2 := '';
  Condition.RawValue := Null;
  Condition.RawValue2 := Null;
  Condition.HasRawValue := False;
  Condition.HasRawValue2 := False;
  Condition.IsAnd := False;
  Condition.IsRaw := True;
  FWhereConditions.Add(Condition);
  Result := Self;
end;
function TSQLBuilder.WhereExists(const ASubQuery: string): TSQLBuilder;
begin
  AddExistsCondition(FWhereConditions, ASubQuery, False, True);
  Result := Self;
end;
function TSQLBuilder.WhereNotExists(const ASubQuery: string): TSQLBuilder;
begin
  AddExistsCondition(FWhereConditions, ASubQuery, True, True);
  Result := Self;
end;
function TSQLBuilder.AndWhereExists(const ASubQuery: string): TSQLBuilder;
begin
  AddExistsCondition(FWhereConditions, ASubQuery, False, True);
  Result := Self;
end;
function TSQLBuilder.AndWhereNotExists(const ASubQuery: string): TSQLBuilder;
begin
  AddExistsCondition(FWhereConditions, ASubQuery, True, True);
  Result := Self;
end;
function TSQLBuilder.OrWhereExists(const ASubQuery: string): TSQLBuilder;
begin
  AddExistsCondition(FWhereConditions, ASubQuery, False, False);
  Result := Self;
end;
function TSQLBuilder.OrWhereNotExists(const ASubQuery: string): TSQLBuilder;
begin
  AddExistsCondition(FWhereConditions, ASubQuery, True, False);
  Result := Self;
end;
function TSQLBuilder.BeginWhereGroup: TSQLBuilder;
begin
  AddGroupMarker(FWhereConditions, True, True);
  Result := Self;
end;
function TSQLBuilder.AndBeginWhereGroup: TSQLBuilder;
begin
  AddGroupMarker(FWhereConditions, True, True);
  Result := Self;
end;
function TSQLBuilder.OrBeginWhereGroup: TSQLBuilder;
begin
  AddGroupMarker(FWhereConditions, True, False);
  Result := Self;
end;
function TSQLBuilder.EndWhereGroup: TSQLBuilder;
begin
  AddGroupMarker(FWhereConditions, False, True);
  Result := Self;
end;
function TSQLBuilder.WhereNull(const AField: string): TSQLBuilder;
begin
  Result := Where(AField, Null, opEqual);
end;
function TSQLBuilder.WhereNotNull(const AField: string): TSQLBuilder;
begin
  Result := Where(AField, Null, opNotEqual);
end;
function TSQLBuilder.WhereBetween(const AField: string; AValue1, AValue2: Variant): TSQLBuilder;
var
  Condition: TWhereCondition;
begin
  Condition := Default(TWhereCondition);
  Condition.Field := NormalizeIdentifier(AField);
  Condition.Operator := opBetween;
  Condition.Value := FormatValue(AValue1);
  Condition.Value2 := FormatValue(AValue2);
  Condition.RawValue := AValue1;
  Condition.RawValue2 := AValue2;
  Condition.HasRawValue := True;
  Condition.HasRawValue2 := True;
  Condition.IsAnd := True;
  Condition.IsRaw := False;
  FWhereConditions.Add(Condition);
  Result := Self;
end;
function TSQLBuilder.WhereNotBetween(const AField: string; AValue1, AValue2: Variant): TSQLBuilder;
var
  Condition: TWhereCondition;
begin
  Condition := Default(TWhereCondition);
  Condition.Field := NormalizeIdentifier(AField);
  Condition.Operator := opNotBetween;
  Condition.Value := FormatValue(AValue1);
  Condition.Value2 := FormatValue(AValue2);
  Condition.RawValue := AValue1;
  Condition.RawValue2 := AValue2;
  Condition.HasRawValue := True;
  Condition.HasRawValue2 := True;
  Condition.IsAnd := True;
  Condition.IsRaw := False;
  FWhereConditions.Add(Condition);
  Result := Self;
end;
function TSQLBuilder.WhereIn(const AField: string; AValues: array of Variant): TSQLBuilder;
var
  Condition: TWhereCondition;
  I: Integer;
  ValueList: string;
begin
  if Length(AValues) = 0 then
    raise Exception.Create('WhereIn requires at least one value.');
  Condition := Default(TWhereCondition);
  ValueList := '';
  for I := Low(AValues) to High(AValues) do
  begin
    if I > Low(AValues) then
      ValueList := ValueList + ', ';
    ValueList := ValueList + FormatValue(AValues[I]);
  end;
  Condition.Field := NormalizeIdentifier(AField);
  Condition.Operator := opIn;
  Condition.Value := ValueList;
  Condition.Value2 := '';
  SetLength(Condition.RawValues, Length(AValues));
  for I := Low(AValues) to High(AValues) do
    Condition.RawValues[I - Low(AValues)] := AValues[I];
  Condition.HasRawValues := True;
  Condition.IsAnd := True;
  Condition.IsRaw := False;
  FWhereConditions.Add(Condition);
  Result := Self;
end;
function TSQLBuilder.WhereNotIn(const AField: string; AValues: array of Variant): TSQLBuilder;
var
  Condition: TWhereCondition;
  I: Integer;
  ValueList: string;
begin
  if Length(AValues) = 0 then
    raise Exception.Create('WhereNotIn requires at least one value.');
  Condition := Default(TWhereCondition);
  ValueList := '';
  for I := Low(AValues) to High(AValues) do
  begin
    if I > Low(AValues) then
      ValueList := ValueList + ', ';
    ValueList := ValueList + FormatValue(AValues[I]);
  end;
  Condition.Field := NormalizeIdentifier(AField);
  Condition.Operator := opNotIn;
  Condition.Value := ValueList;
  Condition.Value2 := '';
  SetLength(Condition.RawValues, Length(AValues));
  for I := Low(AValues) to High(AValues) do
    Condition.RawValues[I - Low(AValues)] := AValues[I];
  Condition.HasRawValues := True;
  Condition.IsAnd := True;
  Condition.IsRaw := False;
  FWhereConditions.Add(Condition);
  Result := Self;
end;
function TSQLBuilder.WhereLike(const AField, AValue: string): TSQLBuilder;
begin
  Result := Where(AField, '%' + AValue + '%', opLike);
end;
function TSQLBuilder.AndWhereNull(const AField: string): TSQLBuilder;
begin
  Result := AndWhere(AField, Null, opEqual);
end;
function TSQLBuilder.AndWhereNotNull(const AField: string): TSQLBuilder;
begin
  Result := AndWhere(AField, Null, opNotEqual);
end;
function TSQLBuilder.AndWhereBetween(const AField: string; AValue1, AValue2: Variant): TSQLBuilder;
var
  Condition: TWhereCondition;
begin
  Condition := Default(TWhereCondition);
  Condition.Field := NormalizeIdentifier(AField);
  Condition.Operator := opBetween;
  Condition.Value := FormatValue(AValue1);
  Condition.Value2 := FormatValue(AValue2);
  Condition.RawValue := AValue1;
  Condition.RawValue2 := AValue2;
  Condition.HasRawValue := True;
  Condition.HasRawValue2 := True;
  Condition.IsAnd := True;
  Condition.IsRaw := False;
  FWhereConditions.Add(Condition);
  Result := Self;
end;
function TSQLBuilder.AndWhereLike(const AField, AValue: string): TSQLBuilder;
begin
  Result := AndWhere(AField, '%' + AValue + '%', opLike);
end;
function TSQLBuilder.OrWhereNull(const AField: string): TSQLBuilder;
begin
  Result := OrWhere(AField, Null, opEqual);
end;
function TSQLBuilder.OrWhereNotNull(const AField: string): TSQLBuilder;
begin
  Result := OrWhere(AField, Null, opNotEqual);
end;
function TSQLBuilder.OrWhereBetween(const AField: string; AValue1, AValue2: Variant): TSQLBuilder;
var
  Condition: TWhereCondition;
begin
  Condition := Default(TWhereCondition);
  Condition.Field := NormalizeIdentifier(AField);
  Condition.Operator := opBetween;
  Condition.Value := FormatValue(AValue1);
  Condition.Value2 := FormatValue(AValue2);
  Condition.RawValue := AValue1;
  Condition.RawValue2 := AValue2;
  Condition.HasRawValue := True;
  Condition.HasRawValue2 := True;
  Condition.IsAnd := False;
  Condition.IsRaw := False;
  FWhereConditions.Add(Condition);
  Result := Self;
end;
function TSQLBuilder.OrderBy(const AField: string; ADirection: TSQLOrderDirection): TSQLBuilder;
var
  OrderClause: TOrderByClause;
begin
  OrderClause.Field := NormalizeIdentifier(AField);
  OrderClause.Direction := ADirection;
  FOrderByFields.Add(OrderClause);
  Result := Self;
end;
function TSQLBuilder.OrderBy(const AFields: string): TSQLBuilder;
var
  Parts: TArray<string>;
  Part: string;
  Item: string;
  UPart: string;
  FieldName: string;
  Dir: TSQLOrderDirection;
begin
  Parts := SplitSQLList(AFields, ',');
  for Part in Parts do
  begin
    Item := Trim(Part);
    if Item = '' then
      Continue;
    UPart := UpperCase(Item);
    if EndsText(' DESC', UPart) then
    begin
      FieldName := Trim(Copy(Item, 1, Length(Item) - 5));
      Dir := odDesc;
    end
    else if EndsText(' ASC', UPart) then
    begin
      FieldName := Trim(Copy(Item, 1, Length(Item) - 4));
      Dir := odAsc;
    end
    else
    begin
      FieldName := Item;
      Dir := odAsc;
    end;
    if FStrictMode and (not IsSimpleIdentifier(FieldName)) then
      raise Exception.Create('In StrictMode, OrderBy(string) accepts only simple identifiers.');
    OrderBy(FieldName, Dir);
  end;
  Result := Self;
end;
function TSQLBuilder.OrderByAsc(const AField: string): TSQLBuilder;
begin
  Result := OrderBy(AField, odAsc);
end;
function TSQLBuilder.OrderByDesc(const AField: string): TSQLBuilder;
begin
  Result := OrderBy(AField, odDesc);
end;
function TSQLBuilder.OrderByRaw(const AOrderBy: string): TSQLBuilder;
var
  OrderClause: TOrderByClause;
begin
  EnsureRawAllowed;
  OrderClause.Field := AOrderBy;
  OrderClause.Direction := odAsc;
  FOrderByFields.Add(OrderClause);
  Result := Self;
end;
function TSQLBuilder.GroupBy(const AFields: string): TSQLBuilder;
var
  Parts: TArray<string>;
  Part: string;
begin
  // Antes usava DelimitedText sem StrictDelimiter: quebrava em espacos
  // (ex.: 'DATE(x), y DESC') e apagava os campos ja adicionados.
  Parts := SplitSQLList(AFields, ',');
  for Part in Parts do
    if Trim(Part) <> '' then
      FGroupByFields.Add(NormalizeIdentifier(Part));
  Result := Self;
end;
function TSQLBuilder.GroupBy(AFields: array of string): TSQLBuilder;
var
  I: Integer;
begin
  for I := Low(AFields) to High(AFields) do
    FGroupByFields.Add(NormalizeIdentifier(AFields[I]));
  Result := Self;
end;
function TSQLBuilder.Having(const AField: string; AValue: Variant; 
                            AOperator: TSQLOperator): TSQLBuilder;
var
  Condition: TWhereCondition;
  LocalField: string;
  LocalOperator: TSQLOperator;
begin
  Condition := Default(TWhereCondition);
  LocalField := AField;
  LocalOperator := AOperator;
  NormalizeFieldAndOperator(LocalField, LocalOperator);
  if VarIsNull(AValue) or VarIsEmpty(AValue) then
  begin
    if LocalOperator = opEqual then
      LocalOperator := opIsNull
    else if LocalOperator = opNotEqual then
      LocalOperator := opIsNotNull
    else
      raise Exception.Create('NULL value supports only opEqual or opNotEqual.');
  end;
  Condition.Field := NormalizeIdentifier(LocalField);
  Condition.Operator := LocalOperator;
  if LocalOperator in [opIsNull, opIsNotNull] then
    Condition.Value := ''
  else
    Condition.Value := FormatValue(AValue);
  Condition.Value2 := '';
  Condition.RawValue := AValue;
  Condition.RawValue2 := Null;
  Condition.HasRawValue := True;
  Condition.HasRawValue2 := False;
  Condition.IsAnd := True;
  Condition.IsRaw := False;
  FHavingConditions.Add(Condition);
  Result := Self;
end;
function TSQLBuilder.AndHaving(const AField: string; AValue: Variant;
                               AOperator: TSQLOperator): TSQLBuilder;
var
  Condition: TWhereCondition;
  LocalField: string;
  LocalOperator: TSQLOperator;
begin
  Condition := Default(TWhereCondition);
  LocalField := AField;
  LocalOperator := AOperator;
  NormalizeFieldAndOperator(LocalField, LocalOperator);
  if VarIsNull(AValue) or VarIsEmpty(AValue) then
  begin
    if LocalOperator = opEqual then
      LocalOperator := opIsNull
    else if LocalOperator = opNotEqual then
      LocalOperator := opIsNotNull
    else
      raise Exception.Create('NULL value supports only opEqual or opNotEqual.');
  end;
  Condition.Field := NormalizeIdentifier(LocalField);
  Condition.Operator := LocalOperator;
  if LocalOperator in [opIsNull, opIsNotNull] then
    Condition.Value := ''
  else
    Condition.Value := FormatValue(AValue);
  Condition.Value2 := '';
  Condition.RawValue := AValue;
  Condition.RawValue2 := Null;
  Condition.HasRawValue := True;
  Condition.HasRawValue2 := False;
  Condition.IsAnd := True;
  Condition.IsRaw := False;
  FHavingConditions.Add(Condition);
  Result := Self;
end;
function TSQLBuilder.OrHaving(const AField: string; AValue: Variant;
                              AOperator: TSQLOperator): TSQLBuilder;
var
  Condition: TWhereCondition;
  LocalField: string;
  LocalOperator: TSQLOperator;
begin
  Condition := Default(TWhereCondition);
  LocalField := AField;
  LocalOperator := AOperator;
  NormalizeFieldAndOperator(LocalField, LocalOperator);
  if VarIsNull(AValue) or VarIsEmpty(AValue) then
  begin
    if LocalOperator = opEqual then
      LocalOperator := opIsNull
    else if LocalOperator = opNotEqual then
      LocalOperator := opIsNotNull
    else
      raise Exception.Create('NULL value supports only opEqual or opNotEqual.');
  end;
  Condition.Field := NormalizeIdentifier(LocalField);
  Condition.Operator := LocalOperator;
  if LocalOperator in [opIsNull, opIsNotNull] then
    Condition.Value := ''
  else
    Condition.Value := FormatValue(AValue);
  Condition.Value2 := '';
  Condition.RawValue := AValue;
  Condition.RawValue2 := Null;
  Condition.HasRawValue := True;
  Condition.HasRawValue2 := False;
  Condition.IsAnd := False;
  Condition.IsRaw := False;
  FHavingConditions.Add(Condition);
  Result := Self;
end;
function TSQLBuilder.HavingRaw(const ACondition: string): TSQLBuilder;
var
  Condition: TWhereCondition;
begin
  Condition := Default(TWhereCondition);
  EnsureRawAllowed;
  Condition.Field := '';
  Condition.Operator := opEqual;
  Condition.Value := ACondition;
  Condition.Value2 := '';
  Condition.RawValue := Null;
  Condition.RawValue2 := Null;
  Condition.HasRawValue := False;
  Condition.HasRawValue2 := False;
  Condition.IsAnd := True;
  Condition.IsRaw := True;
  FHavingConditions.Add(Condition);
  Result := Self;
end;
function TSQLBuilder.AndHavingRaw(const ACondition: string): TSQLBuilder;
var
  Condition: TWhereCondition;
begin
  Condition := Default(TWhereCondition);
  EnsureRawAllowed;
  Condition.Field := '';
  Condition.Operator := opEqual;
  Condition.Value := ACondition;
  Condition.Value2 := '';
  Condition.RawValue := Null;
  Condition.RawValue2 := Null;
  Condition.HasRawValue := False;
  Condition.HasRawValue2 := False;
  Condition.IsAnd := True;
  Condition.IsRaw := True;
  FHavingConditions.Add(Condition);
  Result := Self;
end;
function TSQLBuilder.OrHavingRaw(const ACondition: string): TSQLBuilder;
var
  Condition: TWhereCondition;
begin
  Condition := Default(TWhereCondition);
  EnsureRawAllowed;
  Condition.Field := '';
  Condition.Operator := opEqual;
  Condition.Value := ACondition;
  Condition.Value2 := '';
  Condition.RawValue := Null;
  Condition.RawValue2 := Null;
  Condition.HasRawValue := False;
  Condition.HasRawValue2 := False;
  Condition.IsAnd := False;
  Condition.IsRaw := True;
  FHavingConditions.Add(Condition);
  Result := Self;
end;
function TSQLBuilder.HavingExists(const ASubQuery: string): TSQLBuilder;
begin
  AddExistsCondition(FHavingConditions, ASubQuery, False, True);
  Result := Self;
end;
function TSQLBuilder.HavingNotExists(const ASubQuery: string): TSQLBuilder;
begin
  AddExistsCondition(FHavingConditions, ASubQuery, True, True);
  Result := Self;
end;
function TSQLBuilder.AndHavingExists(const ASubQuery: string): TSQLBuilder;
begin
  AddExistsCondition(FHavingConditions, ASubQuery, False, True);
  Result := Self;
end;
function TSQLBuilder.AndHavingNotExists(const ASubQuery: string): TSQLBuilder;
begin
  AddExistsCondition(FHavingConditions, ASubQuery, True, True);
  Result := Self;
end;
function TSQLBuilder.OrHavingExists(const ASubQuery: string): TSQLBuilder;
begin
  AddExistsCondition(FHavingConditions, ASubQuery, False, False);
  Result := Self;
end;
function TSQLBuilder.OrHavingNotExists(const ASubQuery: string): TSQLBuilder;
begin
  AddExistsCondition(FHavingConditions, ASubQuery, True, False);
  Result := Self;
end;
function TSQLBuilder.BeginHavingGroup: TSQLBuilder;
begin
  AddGroupMarker(FHavingConditions, True, True);
  Result := Self;
end;
function TSQLBuilder.AndBeginHavingGroup: TSQLBuilder;
begin
  AddGroupMarker(FHavingConditions, True, True);
  Result := Self;
end;
function TSQLBuilder.OrBeginHavingGroup: TSQLBuilder;
begin
  AddGroupMarker(FHavingConditions, True, False);
  Result := Self;
end;
function TSQLBuilder.EndHavingGroup: TSQLBuilder;
begin
  AddGroupMarker(FHavingConditions, False, True);
  Result := Self;
end;
function TSQLBuilder.Limit(ALimit: Integer): TSQLBuilder;
begin
  if ALimit <= 0 then
    raise Exception.Create('Limit must be greater than zero.');
  FLimit := ALimit;
  Result := Self;
end;
function TSQLBuilder.Offset(AOffset: Integer): TSQLBuilder;
begin
  if AOffset < 0 then
    raise Exception.Create('Offset cannot be negative.');
  FOffset := AOffset;
  Result := Self;
end;
function TSQLBuilder.Paginate(APage, APageSize: Integer): TSQLBuilder;
begin
  if APage < 1 then
    raise Exception.Create('Page must be greater than or equal to 1.');
  if APageSize <= 0 then
    raise Exception.Create('PageSize must be greater than zero.');
  FLimit := APageSize;
  FOffset := (APage - 1) * APageSize;
  Result := Self;
end;
function TSQLBuilder.BuildJoinClause: string;
var
  I: Integer;
  JoinText: string;
begin
  Result := '';
  for I := 0 to FJoinClauses.Count - 1 do
  begin
    case FJoinClauses[I].JoinType of
      jtInner: JoinText := 'INNER JOIN';
      jtLeft: JoinText := 'LEFT JOIN';
      jtRight: JoinText := 'RIGHT JOIN';
      jtFull:
        begin
          if FDatabaseType = dbMySQL then
            raise Exception.Create('FULL JOIN is not supported by MySQL. ' +
              'Use LEFT JOIN ... UNION ... RIGHT JOIN instead.');
          JoinText := 'FULL JOIN';
        end;
    end;
    Result := Result + ' ' + JoinText + ' ' + FJoinClauses[I].Table +
              ' ON ' + FJoinClauses[I].Condition;
  end;
end;
function TSQLBuilder.BuildWhereClause: string;
var
  I: Integer;
  J: Integer;
  GroupBalance: Integer;
  PrevWasGroupStart: Boolean;
  ConditionOperator: string;
  ParamName1: string;
  ParamName2: string;
  InList: string;
begin
  if FWhereConditions.Count = 0 then
    Exit('');

  Result := ' WHERE ';
  GroupBalance := 0;
  PrevWasGroupStart := False;
  for I := 0 to FWhereConditions.Count - 1 do
  begin
    if FWhereConditions[I].IsGroupEnd then
    begin
      Dec(GroupBalance);
      if GroupBalance < 0 then
        raise Exception.Create('Invalid WHERE group: closing parenthesis without matching opening parenthesis.');
      Result := Result + ')';
      PrevWasGroupStart := False;
      Continue;
    end;
    if I > 0 then
    begin
      if not PrevWasGroupStart then
      begin
        if FWhereConditions[I].IsAnd then
          Result := Result + ' AND '
        else
          Result := Result + ' OR ';
      end;
    end;
    if FWhereConditions[I].IsGroupStart then
    begin
      Result := Result + '(';
      Inc(GroupBalance);
      PrevWasGroupStart := True;
      Continue;
    end;
    if FWhereConditions[I].IsRaw then
    begin
      Result := Result + FWhereConditions[I].Value;
    end
    else if FWhereConditions[I].Operator in [opBetween, opNotBetween] then
    begin
      if FWhereConditions[I].Operator = opBetween then
        ConditionOperator := 'BETWEEN'
      else
        ConditionOperator := 'NOT BETWEEN';
      if FUseNamedParams and FWhereConditions[I].HasRawValue and FWhereConditions[I].HasRawValue2 then
      begin
        ParamName1 := CreateParamName(FWhereConditions[I].Field + '_from');
        ParamName2 := CreateParamName(FWhereConditions[I].Field + '_to');
        AddParameter(ParamName1, FWhereConditions[I].RawValue);
        AddParameter(ParamName2, FWhereConditions[I].RawValue2);
        Result := Result + FWhereConditions[I].Field + ' ' + ConditionOperator + ' ' +
                  GetParamPlaceholder(ParamName1) + ' AND ' + GetParamPlaceholder(ParamName2);
      end
      else
      begin
        Result := Result + FWhereConditions[I].Field + ' ' + ConditionOperator + ' ' +
                  FWhereConditions[I].Value + ' AND ' + FWhereConditions[I].Value2;
      end;
    end
    else if FWhereConditions[I].Operator in [opIn, opNotIn] then
    begin
      ConditionOperator := GetOperatorText(FWhereConditions[I].Operator);
      if FUseNamedParams and FWhereConditions[I].HasRawValues then
      begin
        InList := '';
        for J := 0 to Length(FWhereConditions[I].RawValues) - 1 do
        begin
          if J > 0 then
            InList := InList + ', ';
          ParamName1 := CreateParamName(FWhereConditions[I].Field + '_in');
          AddParameter(ParamName1, FWhereConditions[I].RawValues[J]);
          InList := InList + GetParamPlaceholder(ParamName1);
        end;
        Result := Result + FWhereConditions[I].Field + ' ' + ConditionOperator + ' (' + InList + ')';
      end
      else
      begin
        Result := Result + FWhereConditions[I].Field + ' ' + ConditionOperator + ' (' + FWhereConditions[I].Value + ')';
      end;
    end
    else if FWhereConditions[I].Operator in [opIsNull, opIsNotNull] then
    begin
      ConditionOperator := GetOperatorText(FWhereConditions[I].Operator);
      Result := Result + FWhereConditions[I].Field + ' ' + ConditionOperator;
    end
    else
    begin
      ConditionOperator := GetOperatorText(FWhereConditions[I].Operator);
      if FUseNamedParams and FWhereConditions[I].HasRawValue then
      begin
        ParamName1 := CreateParamName(FWhereConditions[I].Field);
        AddParameter(ParamName1, FWhereConditions[I].RawValue);
        Result := Result + FWhereConditions[I].Field + ' ' +
                  ConditionOperator + ' ' + GetParamPlaceholder(ParamName1);
      end
      else
      begin
        Result := Result + FWhereConditions[I].Field + ' ' +
                  ConditionOperator + ' ' + FWhereConditions[I].Value;
      end;
    end;
    PrevWasGroupStart := False;
  end;
  if GroupBalance <> 0 then
    raise Exception.Create('Invalid WHERE group: unmatched opening parenthesis.');
end;

// Função auxiliar para limpar operadores duplicados
function TSQLBuilder.BuildOrderByClause: string;
var
  I: Integer;
  UField: string;
begin
  if FOrderByFields.Count = 0 then
  begin
    // SQL Server exige ORDER BY para OFFSET/FETCH.
    if (FDatabaseType = dbMSSQL) and ((FLimit > 0) or (FOffset > 0)) then
    begin
      // Com UNION/INTERSECT/EXCEPT o ORDER BY precisa referenciar o select list.
      if FUnions.Count > 0 then
        Exit(' ORDER BY 1')
      else
        Exit(' ORDER BY (SELECT NULL)');
    end;
    Exit('');
  end;

  Result := ' ORDER BY ';
  for I := 0 to FOrderByFields.Count - 1 do
  begin
    if I > 0 then
      Result := Result + ', ';
    Result := Result + FOrderByFields[I].Field;

    UField := UpperCase(Trim(FOrderByFields[I].Field));
    if (not EndsText(' ASC', UField)) and (not EndsText(' DESC', UField)) then
    begin
      if FOrderByFields[I].Direction = odDesc then
        Result := Result + ' DESC'
      else
        Result := Result + ' ASC';
    end;
  end;
end;
function TSQLBuilder.BuildGroupByClause: string;
var
  I: Integer;
begin
  if FGroupByFields.Count > 0 then
  begin
    Result := ' GROUP BY ';
    for I := 0 to FGroupByFields.Count - 1 do
    begin
      if I > 0 then
        Result := Result + ',';
      Result := Result + FGroupByFields[I];
    end;
  end
  else
    Result := '';
end;
function TSQLBuilder.BuildHavingClause: string;
var
  I: Integer;
  GroupBalance: Integer;
  PrevWasGroupStart: Boolean;
  ConditionOperator: string;
  ParamName1: string;
begin
  if FHavingConditions.Count = 0 then
    Exit('');

  Result := ' HAVING ';
  GroupBalance := 0;
  PrevWasGroupStart := False;
  for I := 0 to FHavingConditions.Count - 1 do
  begin
    if FHavingConditions[I].IsGroupEnd then
    begin
      Dec(GroupBalance);
      if GroupBalance < 0 then
        raise Exception.Create('Invalid HAVING group: closing parenthesis without matching opening parenthesis.');
      Result := Result + ')';
      PrevWasGroupStart := False;
      Continue;
    end;
    if I > 0 then
    begin
      if not PrevWasGroupStart then
      begin
        if FHavingConditions[I].IsAnd then
          Result := Result + ' AND '
        else
          Result := Result + ' OR ';
      end;
    end;
    if FHavingConditions[I].IsGroupStart then
    begin
      Result := Result + '(';
      Inc(GroupBalance);
      PrevWasGroupStart := True;
      Continue;
    end;
    if FHavingConditions[I].IsRaw then
    begin
      Result := Result + FHavingConditions[I].Value;
    end
    else if FHavingConditions[I].Operator in [opIsNull, opIsNotNull] then
    begin
      ConditionOperator := GetOperatorText(FHavingConditions[I].Operator);
      Result := Result + FHavingConditions[I].Field + ' ' + ConditionOperator;
    end
    else
    begin
      ConditionOperator := GetOperatorText(FHavingConditions[I].Operator);
      if FUseNamedParams and FHavingConditions[I].HasRawValue then
      begin
        ParamName1 := CreateParamName(FHavingConditions[I].Field);
        AddParameter(ParamName1, FHavingConditions[I].RawValue);
        Result := Result + FHavingConditions[I].Field + ' ' +
                  ConditionOperator + ' ' + GetParamPlaceholder(ParamName1);
      end
      else
      begin
        Result := Result + FHavingConditions[I].Field + ' ' +
                  ConditionOperator + ' ' + FHavingConditions[I].Value;
      end;
    end;
    PrevWasGroupStart := False;
  end;
  if GroupBalance <> 0 then
    raise Exception.Create('Invalid HAVING group: unmatched opening parenthesis.');
end;
function TSQLBuilder.BuildLimitOffsetClause: string;
begin
  Result := '';

  if (FLimit <= 0) and (FOffset <= 0) then
    Exit;

  case FDatabaseType of
    dbMySQL:
      begin
        // MySQL nao aceita OFFSET sem LIMIT.
        if FLimit > 0 then
          Result := ' LIMIT ' + FLimit.ToString
        else
          Result := ' LIMIT 18446744073709551615';
        if FOffset > 0 then
          Result := Result + ' OFFSET ' + FOffset.ToString;
      end;

    dbSQLite:
      begin
        if FLimit > 0 then
          Result := ' LIMIT ' + FLimit.ToString
        else
          Result := ' LIMIT -1';
        if FOffset > 0 then
          Result := Result + ' OFFSET ' + FOffset.ToString;
      end;

    dbFirebird:
      begin
        if FLimit <= 0 then
          Result := ' ROWS ' + (FOffset + 1).ToString + ' TO 2147483647'
        else if FOffset > 0 then
          Result := ' ROWS ' + (FOffset + 1).ToString + ' TO ' + (FOffset + FLimit).ToString
        else
          Result := ' ROWS ' + FLimit.ToString;
      end;

    dbMSSQL:
      begin
        Result := ' OFFSET ' + FOffset.ToString + ' ROWS';
        if FLimit > 0 then
          Result := Result + ' FETCH NEXT ' + FLimit.ToString + ' ROWS ONLY';
      end;

  else // dbPostgreSQL, dbGeneric
    begin
      if FLimit > 0 then
        Result := ' LIMIT ' + FLimit.ToString;
      if FOffset > 0 then
        Result := Result + ' OFFSET ' + FOffset.ToString;
    end;
  end;
end;

function TSQLBuilder.BuildSQL(ACountOnly: Boolean): string;
var
  I: Integer;
  J: Integer;
  C: Integer;
  SelectFieldsStr: string;
  BaseSQL: string;
  Body: string;
  UnionSQL: string;
  CteSQL: string;
  OneCteSQL: string;
  HasRecursiveCte: Boolean;
  NewParamName: string;
  BaseParamName: string;
  UnionWord: string;
  NeedsWrap: Boolean;
begin
  if FFromTable = '' then
    raise Exception.Create('Table not specified. Use From() method.');

  if FDatabaseType = dbMySQL then
    for I := 0 to FJoinClauses.Count - 1 do
      if FJoinClauses[I].JoinType = jtFull then
        raise Exception.Create('FULL JOIN is not supported by MySQL. ' +
          'Use LeftJoin/RightJoin or combine two queries with Union.');

  FParameters.Clear;
  FParamValues.Clear;

  // COUNT(*) direto so e correto para consultas simples. Com DISTINCT,
  // GROUP BY ou operacoes de conjunto a consulta e envolvida numa subconsulta
  // (COUNT(DISTINCT a, b) nao existe no SQL Server nem no PostgreSQL, e
  // COUNT(*) com GROUP BY devolveria uma linha por grupo).
  NeedsWrap := ACountOnly and (FDistinct or (FGroupByFields.Count > 0) or (FUnions.Count > 0));

  BaseSQL := 'SELECT ';
  if ACountOnly and not NeedsWrap then
    BaseSQL := BaseSQL + 'COUNT(*) AS Total'
  else if ACountOnly and (not FDistinct) and (FUnions.Count = 0) and
          not ((FDatabaseType = dbMySQL) and (FHavingConditions.Count > 0)) then
    // GROUP BY simples: o select list nao importa para a contagem e evita
    // erros de colunas sem nome/duplicadas na tabela derivada (MSSQL/MySQL).
    // No MySQL o HAVING pode referenciar alias do select, entao ele e mantido.
    BaseSQL := BaseSQL + '1 AS fluent_row'
  else
  begin
    if FDistinct then
      BaseSQL := BaseSQL + 'DISTINCT ';
    if FSelectFields.Count > 0 then
    begin
      SelectFieldsStr := '';
      for I := 0 to FSelectFields.Count - 1 do
      begin
        if I > 0 then
          SelectFieldsStr := SelectFieldsStr + ', ';
        SelectFieldsStr := SelectFieldsStr + FSelectFields[I];
      end;
      BaseSQL := BaseSQL + SelectFieldsStr;
    end
    else
      BaseSQL := BaseSQL + '*';
  end;

  BaseSQL := BaseSQL + ' FROM ' + FFromTable;
  BaseSQL := BaseSQL + BuildJoinClause;
  BaseSQL := BaseSQL + BuildWhereClause;
  BaseSQL := BaseSQL + BuildGroupByClause;
  BaseSQL := BaseSQL + BuildHavingClause;

  if FUnions.Count = 0 then
    Body := BaseSQL
  else
  begin
    // SQLite nao aceita parenteses em volta dos SELECTs de um UNION/INTERSECT/
    // EXCEPT ("(SELECT ...) UNION (SELECT ...)" e erro de sintaxe).
    if FDatabaseType = dbSQLite then
      Body := BaseSQL
    else
      Body := '(' + BaseSQL + ')';
    for I := 0 to FUnions.Count - 1 do
    begin
      UnionSQL := StripEndingSemicolon(FUnions[I].SQL);
      if UnionSQL = '' then
        raise Exception.Create('Union query cannot be empty.');
      for J := 0 to Length(FUnions[I].ParamNames) - 1 do
      begin
        BaseParamName := FUnions[I].ParamNames[J];
        NewParamName := BaseParamName;
        C := 1;
        while FParameters.IndexOf(NewParamName) >= 0 do
        begin
          NewParamName := BaseParamName + '_u' + I.ToString + '_' + C.ToString;
          Inc(C);
        end;
        UnionSQL := ReplaceParamToken(UnionSQL, ':' + BaseParamName, GetParamPlaceholder(NewParamName));
        UnionSQL := ReplaceParamToken(UnionSQL, '@' + BaseParamName, GetParamPlaceholder(NewParamName));
        FParameters.Add(NewParamName);
        AddParameter(NewParamName, FUnions[I].ParamValues[J]);
      end;
      UnionWord := ' ' + Trim(FUnions[I].OperatorText);
      if FUnions[I].IsAll then
        UnionWord := UnionWord + ' ALL';
      UnionWord := UnionWord + ' ';
      if FDatabaseType = dbSQLite then
        Body := Body + UnionWord + UnionSQL
      else
        Body := Body + UnionWord + '(' + UnionSQL + ')';
    end;
  end;

  if not ACountOnly then
    Body := Body + BuildOrderByClause + BuildLimitOffsetClause
  else if NeedsWrap then
    Body := 'SELECT COUNT(*) AS Total FROM (' + Body + ') fluent_count';

  if FCtes.Count > 0 then
  begin
    CteSQL := '';
    HasRecursiveCte := False;
    for I := 0 to FCtes.Count - 1 do
    begin
      OneCteSQL := StripEndingSemicolon(FCtes[I].SQL);
      if OneCteSQL = '' then
        raise Exception.Create('CTE query cannot be empty.');
      for J := 0 to Length(FCtes[I].ParamNames) - 1 do
      begin
        BaseParamName := FCtes[I].ParamNames[J];
        NewParamName := BaseParamName;
        C := 1;
        while FParameters.IndexOf(NewParamName) >= 0 do
        begin
          NewParamName := BaseParamName + '_c' + I.ToString + '_' + C.ToString;
          Inc(C);
        end;
        OneCteSQL := ReplaceParamToken(OneCteSQL, ':' + BaseParamName, GetParamPlaceholder(NewParamName));
        OneCteSQL := ReplaceParamToken(OneCteSQL, '@' + BaseParamName, GetParamPlaceholder(NewParamName));
        FParameters.Add(NewParamName);
        AddParameter(NewParamName, FCtes[I].ParamValues[J]);
      end;
      if I > 0 then
        CteSQL := CteSQL + ', ';
      CteSQL := CteSQL + FCtes[I].Name + ' AS (' + OneCteSQL + ')';
      if FCtes[I].IsRecursive then
        HasRecursiveCte := True;
    end;
    // SQL Server nao aceita a palavra RECURSIVE (CTEs recursivas usam WITH).
    if HasRecursiveCte and (FDatabaseType <> dbMSSQL) then
      Body := 'WITH RECURSIVE ' + CteSQL + ' ' + Body
    else
      Body := 'WITH ' + CteSQL + ' ' + Body;
  end;

  Result := Body + ';';
  if Assigned(FOnSQLGenerated) then
    FOnSQLGenerated(Self, Result);
end;

function TSQLBuilder.ToSQL: string;
begin
  Result := BuildSQL(False);
end;

function TSQLBuilder.ToFormattedSQL(AIndentSize: Integer): string;
begin
  Result := TSQLFormatter.Format(ToSQL, AIndentSize);
end;

function TSQLBuilder.ToSQLCount: string;
begin
  Result := BuildSQL(True);
end;

function TSQLBuilder.ToFormattedSQLCount(AIndentSize: Integer): string;
begin
  Result := TSQLFormatter.Format(ToSQLCount, AIndentSize);
end;
function TSQLBuilder.GetParameters: TArray<string>;
begin
  Result := FParameters.ToStringArray;
end;
function TSQLBuilder.ToSQLParams: TSQLParams;
var
  I: Integer;
begin
  SetLength(Result, FParameters.Count);
  for I := 0 to FParameters.Count - 1 do
  begin
    Result[I].Name := FParameters[I];
    Result[I].Value := GetParamValue(FParameters[I]);
    Result[I].DataType := ftUnknown;
  end;
end;

function TSQLBuilder.GetParamValue(const AParamName: string): Variant;
begin
  if not FParamValues.TryGetValue(AParamName, Result) then
    Result := Null;
end;
end.
