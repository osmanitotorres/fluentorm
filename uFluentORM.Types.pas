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

unit uFluentORM.Types;

interface

uses
  System.SysUtils,
  System.Variants,
  Data.DB;

type
  TSQLParam = record
    Name: string;
    Value: Variant;
    /// <summary>
    /// Optional database field type. When ftUnknown the executor infers the
    /// type from the value (needed when a NULL is sent to FireDAC).
    /// </summary>
    DataType: TFieldType;
  end;

  TSQLParams = TArray<TSQLParam>;

  /// <summary>
  /// Target database dialect. Used by both the SQL builder and the repository
  /// to emit dialect specific SQL (identifier quoting, pagination, identity).
  /// </summary>
  TSQLDatabaseType = (dbGeneric, dbMySQL, dbPostgreSQL, dbFirebird, dbSQLite, dbMSSQL);

  /// <summary>
  /// Central place for the small dialect differences handled by FluentORM.
  /// </summary>
  TSQLDialect = class
  public
    /// <summary> Maps a FireDAC DriverID (MySQL, MSSQL, PG, FB, SQLite...) to a dialect. </summary>
    class function FromDriverID(const ADriverID: string): TSQLDatabaseType; static;
    /// <summary> Returns the FireDAC DriverID usually associated with the dialect. </summary>
    class function ToDriverID(ADatabaseType: TSQLDatabaseType): string; static;
    /// <summary>
    /// Returns the parameter marker for the dialect.
    /// ':' is used for every dialect because it is understood by FireDAC
    /// (and most Delphi data access layers) for all supported databases.
    /// Use TSQLBuilder.ParamPrefix to override when a native marker is required.
    /// </summary>
    class function ParamPrefix(ADatabaseType: TSQLDatabaseType): string; static;
    /// <summary> True when the value is a plain [A-Za-z_][A-Za-z0-9_]* identifier (dotted names allowed). </summary>
    class function IsSimpleIdentifier(const AIdentifier: string): Boolean; static;
    /// <summary>
    /// Quotes a (possibly dotted) identifier using the dialect rules:
    /// [name] for SQL Server, `name` for MySQL and "name" for the others.
    /// Non simple identifiers (expressions) are returned unchanged unless
    /// AForce is True, which is used for metadata (table/column names).
    /// </summary>
    class function QuoteIdentifier(const AIdentifier: string;
      ADatabaseType: TSQLDatabaseType; AForce: Boolean = False): string; static;
  end;

implementation

class function TSQLDialect.FromDriverID(const ADriverID: string): TSQLDatabaseType;
var
  ID: string;
begin
  ID := UpperCase(Trim(ADriverID));
  if (ID = 'MYSQL') or (ID = 'MYSQL55') or (ID = 'MYSQL56') or
     (ID = 'MYSQL57') or (ID = 'MYSQL80') or (ID = 'MYSQL81') or (ID = 'MYSQL84') or
     (ID = 'MYSQL90') or (ID = 'MARIADB') then
    Exit(dbMySQL);
  if (ID = 'PG') or (ID = 'POSTGRESQL') or (ID = 'POSTGRES') then
    Exit(dbPostgreSQL);
  if (ID = 'MSSQL') or (ID = 'SQLSERVER') or (ID = 'SQL SERVER') then
    Exit(dbMSSQL);
  if (ID = 'FB') or (ID = 'FIREBIRD') or (ID = 'IB') or
     (ID = 'INTERBASE') or (ID = 'IBLITE') then
    Exit(dbFirebird);
  if (ID = 'SQLITE') then
    Exit(dbSQLite);
  Result := dbGeneric;
end;

class function TSQLDialect.ToDriverID(ADatabaseType: TSQLDatabaseType): string;
begin
  case ADatabaseType of
    dbMySQL: Result := 'MySQL';
    dbPostgreSQL: Result := 'PG';
    dbFirebird: Result := 'FB';
    dbSQLite: Result := 'SQLite';
    dbMSSQL: Result := 'MSSQL';
  else
    Result := '';
  end;
end;

class function TSQLDialect.ParamPrefix(ADatabaseType: TSQLDatabaseType): string;
begin
  // FireDAC (and Zeos/UniDAC/dbExpress) expect ':' markers for every RDBMS.
  // Native '@' can be enabled through TSQLBuilder.ParamPrefix when needed.
  Result := ':';
end;

class function TSQLDialect.IsSimpleIdentifier(const AIdentifier: string): Boolean;
var
  I: Integer;
  Part: string;
  Parts: TArray<string>;
  C: Char;

  function IsIdentStart(AChar: Char): Boolean;
  begin
    Result := CharInSet(AChar, ['A'..'Z', 'a'..'z', '_']);
  end;

  function IsIdentChar(AChar: Char): Boolean;
  begin
    Result := IsIdentStart(AChar) or CharInSet(AChar, ['0'..'9']);
  end;

begin
  Result := False;
  if Trim(AIdentifier) = '' then
    Exit;

  Parts := Trim(AIdentifier).Split(['.']);
  if Length(Parts) = 0 then
    Exit;

  for Part in Parts do
  begin
    if Part = '' then
      Exit;
    if not IsIdentStart(Part[1]) then
      Exit;
    for I := 2 to Length(Part) do
    begin
      C := Part[I];
      if not IsIdentChar(C) then
        Exit;
    end;
  end;
  Result := True;
end;

class function TSQLDialect.QuoteIdentifier(const AIdentifier: string;
  ADatabaseType: TSQLDatabaseType; AForce: Boolean): string;
var
  I: Integer;
  Parts: TArray<string>;
  LeftQuote, RightQuote: Char;

  function EscapePart(const APart: string): string;
  begin
    case ADatabaseType of
      dbMSSQL:
        Result := StringReplace(APart, ']', ']]', [rfReplaceAll]);
      dbMySQL:
        Result := StringReplace(APart, '`', '``', [rfReplaceAll]);
    else
      Result := StringReplace(APart, '"', '""', [rfReplaceAll]);
    end;
  end;

begin
  if Trim(AIdentifier) = '' then
    Exit(AIdentifier);

  if not AForce then
  begin
    if not IsSimpleIdentifier(AIdentifier) then
      Exit(AIdentifier);
  end;

  case ADatabaseType of
    dbMSSQL:
      begin
        LeftQuote := '[';
        RightQuote := ']';
      end;
    dbMySQL:
      begin
        LeftQuote := '`';
        RightQuote := '`';
      end;
  else
    begin
      LeftQuote := '"';
      RightQuote := '"';
    end;
  end;

  Parts := Trim(AIdentifier).Split(['.']);
  for I := Low(Parts) to High(Parts) do
    if Parts[I] <> '' then
      Parts[I] := LeftQuote + EscapePart(Parts[I]) + RightQuote;
  Result := string.Join('.', Parts);
end;

end.
