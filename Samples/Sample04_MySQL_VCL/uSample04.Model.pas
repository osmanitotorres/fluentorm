unit uSample04.Model;

{ Modelo do Sample04:
  - TClienteDTO: entidade mapeada para a tabela "cliente";
  - TLoggingExecutor: decorator de ISQLExecutor que registra cada comando
    (SQL + parametros) antes de repassar ao executor FireDAC. Mostra como o
    executor desacoplado permite adicionar log/auditoria sem tocar no ORM. }

interface

uses
  System.SysUtils,
  System.Variants,
  Data.DB,
  uFluentORM.Types,
  uFluentORM.Attributes,
  uFluentORM.Executor,
  uFluentORM.Executor.FireDAC;

const
  SQL_CREATE_TABLE_CLIENTE =
    'CREATE TABLE IF NOT EXISTS cliente (' + sLineBreak +
    '  id              INT AUTO_INCREMENT PRIMARY KEY,' + sLineBreak +
    '  nome            VARCHAR(100)   NOT NULL,' + sLineBreak +
    '  email           VARCHAR(120)   NULL,' + sLineBreak +
    '  cpf             VARCHAR(14)    NULL,' + sLineBreak +
    '  telefone        VARCHAR(20)    NULL,' + sLineBreak +
    '  data_nascimento DATE           NULL,' + sLineBreak +
    '  limite_credito  DECIMAL(12,2)  NOT NULL DEFAULT 0,' + sLineBreak +
    '  ativo           TINYINT(1)     NOT NULL DEFAULT 1,' + sLineBreak +
    '  observacao      TEXT           NULL,' + sLineBreak +
    '  criado_em       DATETIME       NOT NULL DEFAULT CURRENT_TIMESTAMP,' + sLineBreak +
    '  atualizado_em   DATETIME       NULL ON UPDATE CURRENT_TIMESTAMP,' + sLineBreak +
    '  KEY ix_cliente_nome (nome)' + sLineBreak +
    ') ENGINE=InnoDB DEFAULT CHARSET=utf8mb4';

type
  [Table('cliente')]
  TClienteDTO = class
  private
    FId: Integer;
    FNome: string;
    FEmail: string;
    FCpf: string;
    FTelefone: string;
    FDataNascimento: Variant;
    FLimiteCredito: Currency;
    FAtivo: Boolean;
    FObservacao: string;
    FCriadoEm: TDateTime;
    FAtualizadoEm: Variant;
  public
    // Chamado tambem pelo TRepository<T>.FindById/FindAll.
    constructor Create;

    [Key(True)]
    [Column('id')]
    property Id: Integer read FId write FId;

    [Column('nome')]
    property Nome: string read FNome write FNome;

    [Column('email')]
    property Email: string read FEmail write FEmail;

    [Column('cpf')]
    property Cpf: string read FCpf write FCpf;

    [Column('telefone')]
    property Telefone: string read FTelefone write FTelefone;

    // Variant: permite NULL (data nao informada).
    [Column('data_nascimento')]
    property DataNascimento: Variant read FDataNascimento write FDataNascimento;

    [Column('limite_credito')]
    property LimiteCredito: Currency read FLimiteCredito write FLimiteCredito;

    [Column('ativo')]
    property Ativo: Boolean read FAtivo write FAtivo;

    [Column('observacao')]
    property Observacao: string read FObservacao write FObservacao;

    // Preenchidas pelo banco: lidas no FindById, nunca enviadas no INSERT/UPDATE.
    [ReadOnly]
    [Column('criado_em')]
    property CriadoEm: TDateTime read FCriadoEm write FCriadoEm;

    [ReadOnly]
    [Column('atualizado_em')]
    property AtualizadoEm: Variant read FAtualizadoEm write FAtualizadoEm;
  end;

  TLogProc = procedure(const AText: string) of object;

  TLoggingExecutor = class(TInterfacedObject, ISQLExecutor, ISQLQueryExecutor,
    ISQLDialectInfo, ISQLTransactionalExecutor, ISQLIdentityExecutor)
  private
    FInner: TFireDACSQLExecutor;
    FInnerRef: ISQLExecutor; // mantem o executor interno vivo
    FLog: TLogProc;
    procedure DoLog(const AText: string);
    procedure LogCommand(const AKind, ASQL: string; const AParams: TSQLParams);
    class function ParamText(const AValue: Variant): string; static;
  public
    constructor Create(AInner: TFireDACSQLExecutor; ALog: TLogProc);
    function Execute(const ASQL: string; const AParams: TSQLParams): Integer;
    function ExecuteScalar(const ASQL: string; const AParams: TSQLParams): Variant;
    function OpenDataSet(const ASQL: string; const AParams: TSQLParams): TDataSet;
    function GetDatabaseType: TSQLDatabaseType;
    function GetLastInsertedId: Variant;
    procedure BeginTransaction;
    procedure Commit;
    procedure Rollback;
    function InTransaction: Boolean;
  end;

implementation

{ TClienteDTO }

constructor TClienteDTO.Create;
begin
  inherited Create;
  FAtivo := True;
  FDataNascimento := Null;
  FAtualizadoEm := Null;
end;

{ TLoggingExecutor }

constructor TLoggingExecutor.Create(AInner: TFireDACSQLExecutor; ALog: TLogProc);
begin
  inherited Create;
  FInner := AInner;
  FInnerRef := AInner;
  FLog := ALog;
end;

procedure TLoggingExecutor.DoLog(const AText: string);
begin
  if Assigned(FLog) then
    FLog(AText);
end;

class function TLoggingExecutor.ParamText(const AValue: Variant): string;
begin
  if VarIsNull(AValue) or VarIsEmpty(AValue) then
    Result := 'NULL'
  else if VarIsArray(AValue) then
    Result := Format('<blob %d bytes>',
      [VarArrayHighBound(AValue, 1) - VarArrayLowBound(AValue, 1) + 1])
  else if VarIsStr(AValue) then
    Result := QuotedStr(VarToStr(AValue))
  else
    Result := VarToStr(AValue);
end;

procedure TLoggingExecutor.LogCommand(const AKind, ASQL: string; const AParams: TSQLParams);
var
  S: string;
  P: TSQLParam;
begin
  S := '[' + AKind + '] ' + ASQL;
  for P in AParams do
    S := S + sLineBreak + '      :' + P.Name + ' = ' + ParamText(P.Value);
  DoLog(S);
end;

function TLoggingExecutor.Execute(const ASQL: string; const AParams: TSQLParams): Integer;
begin
  LogCommand('Execute', ASQL, AParams);
  Result := FInner.Execute(ASQL, AParams);
  DoLog('      -> linhas afetadas: ' + IntToStr(Result));
end;

function TLoggingExecutor.ExecuteScalar(const ASQL: string; const AParams: TSQLParams): Variant;
begin
  LogCommand('Scalar', ASQL, AParams);
  Result := FInner.ExecuteScalar(ASQL, AParams);
  DoLog('      -> ' + ParamText(Result));
end;

function TLoggingExecutor.OpenDataSet(const ASQL: string; const AParams: TSQLParams): TDataSet;
begin
  LogCommand('Query', ASQL, AParams);
  Result := FInner.OpenDataSet(ASQL, AParams);
end;

function TLoggingExecutor.GetDatabaseType: TSQLDatabaseType;
begin
  Result := FInner.GetDatabaseType;
end;

function TLoggingExecutor.GetLastInsertedId: Variant;
begin
  Result := FInner.GetLastInsertedId;
  DoLog('[Identity] LAST_INSERT_ID() -> ' + ParamText(Result));
end;

procedure TLoggingExecutor.BeginTransaction;
begin
  DoLog('[Tx] BEGIN');
  FInner.BeginTransaction;
end;

procedure TLoggingExecutor.Commit;
begin
  DoLog('[Tx] COMMIT');
  FInner.Commit;
end;

procedure TLoggingExecutor.Rollback;
begin
  DoLog('[Tx] ROLLBACK');
  FInner.Rollback;
end;

function TLoggingExecutor.InTransaction: Boolean;
begin
  Result := FInner.InTransaction;
end;

end.
