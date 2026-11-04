unit uFraBase;

{ Frame que representa UMA base de dados: escolha do banco (MySQL/PostgreSQL),
  conexao, criacao da estrutura, geracao de dados, lista paginada, edicao e
  exclusao. O formulario principal usa duas instancias (Base A e Base B), cada
  uma com sua propria TFDConnection, executor e TRepository<TClienteDTO>. }

interface

uses
  System.SysUtils,
  System.Variants,
  System.Classes,
  System.Math,
  System.UITypes,
  Vcl.Graphics,
  Vcl.Controls,
  Vcl.Forms,
  Vcl.Dialogs,
  Vcl.StdCtrls,
  Vcl.ExtCtrls,
  Vcl.Grids,
  Vcl.DBGrids,
  Data.DB,
  FireDAC.Stan.Intf,
  FireDAC.Stan.Option,
  FireDAC.Stan.Error,
  FireDAC.Stan.Def,
  FireDAC.Stan.Async,
  FireDAC.Stan.Param,
  FireDAC.Phys.Intf,
  FireDAC.Phys,
  FireDAC.DApt,
  FireDAC.Comp.Client,
  uFluentORM.Types,
  uFluentORM,
  uFluentORM.Executor,
  uFluentORM.Executor.FireDAC,
  uFluentORM.Repository,
  uSample06.Model;

type
  TfraBase = class(TFrame)
    pnlTitulo: TPanel;
    pnlConfig: TPanel;
    lblBanco: TLabel;
    cbBanco: TComboBox;
    lblServer: TLabel;
    edtServer: TEdit;
    lblPort: TLabel;
    edtPort: TEdit;
    lblDatabase: TLabel;
    edtDatabase: TEdit;
    lblUser: TLabel;
    edtUser: TEdit;
    lblPassword: TLabel;
    edtPassword: TEdit;
    btnConectar: TButton;
    btnCriarEstrutura: TButton;
    btnGerarDados: TButton;
    lblConexao: TLabel;
    pnlFiltro: TPanel;
    edtFiltro: TEdit;
    chkAtivos: TCheckBox;
    btnPesquisar: TButton;
    btnEditar: TButton;
    btnExcluir: TButton;
    grdLista: TDBGrid;
    pnlRodape: TPanel;
    btnAnterior: TButton;
    lblPagina: TLabel;
    btnProxima: TButton;
    dsLista: TDataSource;
    procedure cbBancoChange(Sender: TObject);
    procedure btnConectarClick(Sender: TObject);
    procedure btnCriarEstruturaClick(Sender: TObject);
    procedure btnGerarDadosClick(Sender: TObject);
    procedure btnPesquisarClick(Sender: TObject);
    procedure btnEditarClick(Sender: TObject);
    procedure btnExcluirClick(Sender: TObject);
    procedure btnAnteriorClick(Sender: TObject);
    procedure btnProximaClick(Sender: TObject);
    procedure edtFiltroKeyPress(Sender: TObject; var Key: Char);
    procedure grdListaDblClick(Sender: TObject);
  private
    FCode: string;
    FLog: TLogProc;
    FConnection: TFDConnection;
    FExecutor: ISQLExecutor;
    FQueryExecutor: ISQLQueryExecutor;
    FRepo: TRepository<TClienteDTO>;
    FListData: TDataSet;
    FPage: Integer;
    FTotal: Int64;
    FOnChanged: TNotifyEvent;
    function GetDatabaseType: TSQLDatabaseType;
    function GetConnected: Boolean;
    procedure DoLog(const AText: string);
    procedure DoChanged;
    procedure ApplyDefaults;
    procedure ApplyConnectionParams(const ADatabase: string);
    procedure Connect(ALoadList: Boolean);
    procedure CreateDatabaseIfMissing;
    procedure LoadPage;
    procedure ConfigureGridFields;
    procedure UpdateControls;
    function PageCount: Integer;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure Setup(const ACode: string; ADatabaseType: TSQLDatabaseType; ALog: TLogProc);
    procedure Disconnect;
    procedure ReloadList;
    procedure EnsureConnected;
    /// Id do cliente selecionado no grid (0 = nenhum).
    function SelectedId: Integer;
    /// Ex.: "Base A (MySQL / fluentorm_demo)".
    function Description: string;
    property Code: string read FCode;
    property Connected: Boolean read GetConnected;
    property DatabaseType: TSQLDatabaseType read GetDatabaseType;
    property Executor: ISQLExecutor read FExecutor;
    property Repo: TRepository<TClienteDTO> read FRepo;
    property OnChanged: TNotifyEvent read FOnChanged write FOnChanged;
  end;

implementation

{$R *.dfm}

const
  PAGE_SIZE = 10;

{ TfraBase }

constructor TfraBase.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FConnection := TFDConnection.Create(Self);
  FConnection.LoginPrompt := False;
  FPage := 1;
end;

destructor TfraBase.Destroy;
begin
  FOnChanged := nil;
  Disconnect;
  inherited;
end;

procedure TfraBase.Setup(const ACode: string; ADatabaseType: TSQLDatabaseType;
  ALog: TLogProc);
begin
  FCode := ACode;
  FLog := ALog;
  pnlTitulo.Caption := '  Base ' + ACode;
  if ADatabaseType = dbPostgreSQL then
    cbBanco.ItemIndex := 1
  else
    cbBanco.ItemIndex := 0;
  ApplyDefaults;
  UpdateControls;
end;

function TfraBase.GetDatabaseType: TSQLDatabaseType;
begin
  if cbBanco.ItemIndex = 1 then
    Result := dbPostgreSQL
  else
    Result := dbMySQL;
end;

function TfraBase.GetConnected: Boolean;
begin
  Result := FRepo <> nil;
end;

function TfraBase.Description: string;
begin
  Result := Format('Base %s (%s / %s)',
    [FCode, DatabaseCaption(DatabaseType), Trim(edtDatabase.Text)]);
end;

procedure TfraBase.DoLog(const AText: string);
begin
  if Assigned(FLog) then
    FLog(AText);
end;

procedure TfraBase.DoChanged;
begin
  if Assigned(FOnChanged) then
    FOnChanged(Self);
end;

procedure TfraBase.ApplyDefaults;
begin
  edtServer.Text := 'localhost';
  edtDatabase.Text := 'fluentorm_sample06';
  edtPassword.Text := '';
  if DatabaseType = dbPostgreSQL then
  begin
    edtPort.Text := '5432';
    edtUser.Text := 'postgres';
  end
  else
  begin
    edtPort.Text := '3306';
    edtUser.Text := 'osmanito';
  end;
end;

procedure TfraBase.cbBancoChange(Sender: TObject);
begin
  if Connected then
  begin
    Disconnect;
    DoLog(Format('[%s] Desconectado (troca de banco).', [FCode]));
  end;
  ApplyDefaults;
  UpdateControls;
end;

{ Conexao }

procedure TfraBase.ApplyConnectionParams(const ADatabase: string);
begin
  FConnection.Connected := False;
  FConnection.Params.Clear;
  if DatabaseType = dbPostgreSQL then
  begin
    FConnection.Params.Values['DriverID'] := 'PG';
    FConnection.Params.Values['CharacterSet'] := 'UTF8';
  end
  else
  begin
    FConnection.Params.Values['DriverID'] := 'MySQL';
    FConnection.Params.Values['CharacterSet'] := 'utf8mb4';
  end;
  FConnection.Params.Values['Server'] := Trim(edtServer.Text);
  FConnection.Params.Values['Port'] := Trim(edtPort.Text);
  FConnection.Params.Values['User_Name'] := Trim(edtUser.Text);
  FConnection.Params.Values['Password'] := edtPassword.Text;
  if ADatabase <> '' then
    FConnection.Params.Values['Database'] := ADatabase;
end;

procedure TfraBase.Connect(ALoadList: Boolean);
var
  Inner: TFireDACSQLExecutor;
  Logger: TLoggingExecutor;
begin
  Disconnect;
  ApplyConnectionParams(Trim(edtDatabase.Text));
  FConnection.Connected := True;

  // Cada base tem seu executor e seu repositorio; nada e compartilhado.
  Inner := TFireDACSQLExecutor.Create(FConnection);
  Logger := TLoggingExecutor.Create(Inner,
    Format('[%s/%s]', [FCode, DatabaseCaption(DatabaseType)]), FLog);
  FExecutor := Logger;
  FQueryExecutor := Logger;
  FRepo := TRepository<TClienteDTO>.Create(FExecutor);

  DoLog(Format('[%s] Conectado: %s (driver FireDAC %s)',
    [FCode, Description, Inner.GetDriverID]));
  FPage := 1;
  UpdateControls;
  if ALoadList then
    LoadPage;
  DoChanged;
end;

procedure TfraBase.Disconnect;
begin
  dsLista.DataSet := nil;
  FreeAndNil(FListData);
  FreeAndNil(FRepo);
  FQueryExecutor := nil;
  FExecutor := nil;
  if Assigned(FConnection) then
    FConnection.Connected := False;
  if not (csDestroying in ComponentState) then
  begin
    UpdateControls;
    DoChanged;
  end;
end;

procedure TfraBase.EnsureConnected;
begin
  if not Connected then
    raise Exception.CreateFmt('Base %s: conecte primeiro.', [FCode]);
end;

procedure TfraBase.btnConectarClick(Sender: TObject);
begin
  Screen.Cursor := crHourGlass;
  try
    if Connected then
    begin
      Disconnect;
      DoLog(Format('[%s] Desconectado.', [FCode]));
    end
    else
      Connect(True);
  finally
    Screen.Cursor := crDefault;
  end;
end;

procedure TfraBase.CreateDatabaseIfMissing;
var
  DbName: string;
  Exists: Variant;
begin
  DbName := Trim(edtDatabase.Text);
  if not TSQLDialect.IsSimpleIdentifier(DbName) or (Pos('.', DbName) > 0) then
    raise Exception.Create('Nome de banco invalido: use letras minusculas, numeros e "_".');

  Disconnect;
  if DatabaseType = dbPostgreSQL then
  begin
    // PostgreSQL: conecta no banco "postgres" e cria se nao existir
    // (CREATE DATABASE nao aceita IF NOT EXISTS nem roda em transacao).
    ApplyConnectionParams('postgres');
    FConnection.Connected := True;
    try
      Exists := FConnection.ExecSQLScalar(
        'SELECT 1 FROM pg_database WHERE datname = :n', [DbName]);
      if VarIsNull(Exists) or VarIsEmpty(Exists) then
      begin
        FConnection.ExecSQL('CREATE DATABASE ' +
          TSQLDialect.QuoteIdentifier(DbName, dbPostgreSQL));
        DoLog(Format('[%s] CREATE DATABASE %s', [FCode, DbName]));
      end
      else
        DoLog(Format('[%s] Banco %s ja existe.', [FCode, DbName]));
    finally
      FConnection.Connected := False;
    end;
  end
  else
  begin
    ApplyConnectionParams('');
    FConnection.Connected := True;
    try
      FConnection.ExecSQL('CREATE DATABASE IF NOT EXISTS ' +
        TSQLDialect.QuoteIdentifier(DbName, dbMySQL) +
        ' CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci');
      DoLog(Format('[%s] CREATE DATABASE IF NOT EXISTS %s', [FCode, DbName]));
    finally
      FConnection.Connected := False;
    end;
  end;
end;

procedure TfraBase.btnCriarEstruturaClick(Sender: TObject);
begin
  Screen.Cursor := crHourGlass;
  try
    CreateDatabaseIfMissing;
    Connect(False);
    FExecutor.Execute(CreateTableSQL(DatabaseType), []);
    if DatabaseType = dbPostgreSQL then
      FExecutor.Execute('CREATE INDEX IF NOT EXISTS ix_cliente_nome ON cliente (nome)', []);
    LoadPage;
  finally
    Screen.Cursor := crDefault;
  end;
  ShowMessage(Description + ': banco e tabela "cliente" prontos.');
end;

{ Dados }

procedure TfraBase.btnGerarDadosClick(Sender: TObject);
const
  NOMES: array[0..7] of string = ('Ana', 'Bruno', 'Carla', 'Diego', 'Elisa',
    'Fabio', 'Gabriela', 'Heitor');
  SOBRENOMES: array[0..3] of string = ('Silva', 'Souza', 'Oliveira', 'Costa');
var
  Lote, Origem: string;
begin
  EnsureConnected;
  Lote := FormatDateTime('hhnnss', Now);
  Origem := Format('Base %s - %s', [FCode, DatabaseCaption(DatabaseType)]);
  TSQLTransaction.ExecuteInTransaction(FExecutor,
    procedure
    var
      I: Integer;
      C: TClienteDTO;
      Nome: string;
    begin
      for I := 1 to 10 do
      begin
        C := TClienteDTO.Create;
        try
          Nome := NOMES[Random(Length(NOMES))] + ' ' +
                  SOBRENOMES[Random(Length(SOBRENOMES))];
          C.Nome := Nome;
          C.Email := LowerCase(StringReplace(Nome, ' ', '.', [rfReplaceAll])) +
                     '.' + LowerCase(FCode) + Lote + IntToStr(I) + '@exemplo.com';
          C.Cpf := Format('%.3d.%.3d.%.3d-%.2d',
            [Random(1000), Random(1000), Random(1000), Random(100)]);
          if I mod 3 <> 0 then
            C.DataNascimento := VarFromDateTime(
              EncodeDate(1960 + Random(45), 1 + Random(12), 1 + Random(28)))
          else
            C.DataNascimento := Null; // testa NULL em coluna DATE
          C.LimiteCredito := Random(500000) / 100;
          C.Ativo := I mod 4 <> 0;
          C.Origem := Origem;
          FRepo.Insert(C);
        finally
          C.Free;
        end;
      end;
    end);
  FPage := 1;
  LoadPage;
  DoLog(Format('[%s] 10 clientes gerados em uma transacao.', [FCode]));
end;

function TfraBase.PageCount: Integer;
begin
  Result := Max(1, Ceil(FTotal / PAGE_SIZE));
end;

procedure TfraBase.LoadPage;
var
  SQL: TSQLBuilder;
  Filtro, SQLText: string;
  Total: Variant;
  NewData: TDataSet;
begin
  EnsureConnected;
  SQL := TSQLBuilder.Create;
  try
    // O mesmo codigo gera SQL de MySQL ou PostgreSQL conforme o dialeto.
    SQL.SetDatabaseType(DatabaseType);
    SQL.QuoteIdentifiers := True;
    SQL.Select
       .Fields(['id', 'nome', 'email', 'cpf', 'data_nascimento',
                'limite_credito', 'ativo', 'origem'])
       .From('cliente');

    Filtro := LowerCase(Trim(edtFiltro.Text));
    if Filtro <> '' then
      // LOWER(...) deixa a pesquisa sem diferenca de maiusculas tambem no
      // PostgreSQL (onde LIKE diferencia maiusculas/minusculas).
      SQL.BeginWhereGroup
           .WhereLike('LOWER(nome)', Filtro)
           .OrWhere('LOWER(email)', '%' + Filtro + '%', opLike)
           .OrWhere('cpf', '%' + Filtro + '%', opLike)
         .EndWhereGroup;
    if chkAtivos.Checked then
      SQL.AndWhere('ativo', True);

    SQLText := SQL.ToSQLCount;
    Total := FExecutor.ExecuteScalar(SQLText, SQL.ToSQLParams);
    if VarIsNull(Total) or VarIsEmpty(Total) then
      FTotal := 0
    else
      FTotal := Total;
    if FPage > PageCount then
      FPage := PageCount;

    SQL.OrderByDesc('id').Paginate(FPage, PAGE_SIZE);
    SQLText := SQL.ToSQL;
    NewData := FQueryExecutor.OpenDataSet(SQLText, SQL.ToSQLParams);
  finally
    SQL.Free;
  end;

  dsLista.DataSet := NewData;
  FreeAndNil(FListData);
  FListData := NewData;
  ConfigureGridFields;
  UpdateControls;
end;

procedure TfraBase.ReloadList;
begin
  if Connected then
    LoadPage;
end;

procedure TfraBase.ConfigureGridFields;

  procedure SetupField(const AName, ALabel: string; AWidth: Integer);
  var
    F: TField;
  begin
    F := FListData.FindField(AName);
    if F <> nil then
    begin
      F.DisplayLabel := ALabel;
      F.DisplayWidth := AWidth;
    end;
  end;

var
  F: TField;
begin
  if FListData = nil then
    Exit;
  SetupField('id', 'Id', 5);
  SetupField('nome', 'Nome', 20);
  SetupField('email', 'E-mail', 26);
  SetupField('cpf', 'CPF', 14);
  SetupField('data_nascimento', 'Nascimento', 10);
  SetupField('limite_credito', 'Limite', 10);
  SetupField('ativo', 'Ativo', 5);
  SetupField('origem', 'Origem', 22);
  F := FListData.FindField('limite_credito');
  if F is TNumericField then
    TNumericField(F).DisplayFormat := '#,##0.00';
  F := FListData.FindField('ativo');
  if F is TBooleanField then
    TBooleanField(F).DisplayValues := 'Sim;Nao';
end;

procedure TfraBase.UpdateControls;
var
  IsConnected: Boolean;
begin
  IsConnected := Connected;
  if IsConnected then
  begin
    btnConectar.Caption := 'Desconectar';
    lblConexao.Caption := 'Conectado';
    lblConexao.Font.Color := clGreen;
  end
  else
  begin
    btnConectar.Caption := 'Conectar';
    lblConexao.Caption := 'Desconectado';
    lblConexao.Font.Color := clRed;
  end;
  btnGerarDados.Enabled := IsConnected;
  btnPesquisar.Enabled := IsConnected;
  btnEditar.Enabled := IsConnected and (FListData <> nil) and not FListData.IsEmpty;
  btnExcluir.Enabled := btnEditar.Enabled;
  btnAnterior.Enabled := IsConnected and (FPage > 1);
  btnProxima.Enabled := IsConnected and (FPage < PageCount);
  if IsConnected then
    lblPagina.Caption := Format('Pagina %d de %d  -  %d cliente(s)',
      [FPage, PageCount, FTotal])
  else
    lblPagina.Caption := '';
end;

function TfraBase.SelectedId: Integer;
begin
  if (FListData = nil) or FListData.IsEmpty then
    Result := 0
  else
    Result := FListData.FieldByName('id').AsInteger;
end;

procedure TfraBase.btnPesquisarClick(Sender: TObject);
begin
  if not Connected then
    Exit;
  FPage := 1;
  LoadPage;
end;

procedure TfraBase.edtFiltroKeyPress(Sender: TObject; var Key: Char);
begin
  if Key = #13 then
  begin
    Key := #0;
    btnPesquisarClick(Sender);
  end;
end;

procedure TfraBase.btnAnteriorClick(Sender: TObject);
begin
  if FPage > 1 then
  begin
    Dec(FPage);
    LoadPage;
  end;
end;

procedure TfraBase.btnProximaClick(Sender: TObject);
begin
  if FPage < PageCount then
  begin
    Inc(FPage);
    LoadPage;
  end;
end;

procedure TfraBase.btnEditarClick(Sender: TObject);
var
  C: TClienteDTO;
  Nome: string;
begin
  EnsureConnected;
  if SelectedId = 0 then
    raise Exception.Create('Selecione um cliente.');
  C := FRepo.FindById(SelectedId);
  if C = nil then
    raise Exception.Create('Cliente nao encontrado.');
  try
    Nome := C.Nome;
    if InputQuery(Description, 'Nome do cliente #' + IntToStr(C.Id) + ':', Nome) and
       (Trim(Nome) <> '') then
    begin
      C.Nome := Trim(Nome);
      FRepo.Update(C);
      LoadPage;
    end;
  finally
    C.Free;
  end;
end;

procedure TfraBase.grdListaDblClick(Sender: TObject);
begin
  if btnEditar.Enabled then
    btnEditarClick(Sender);
end;

procedure TfraBase.btnExcluirClick(Sender: TObject);
var
  Id: Integer;
begin
  EnsureConnected;
  Id := SelectedId;
  if Id = 0 then
    raise Exception.Create('Selecione um cliente.');
  if MessageDlg(Format('%s: excluir o cliente #%d?', [Description, Id]),
       mtConfirmation, [mbYes, mbNo], 0) <> mrYes then
    Exit;
  FRepo.DeleteById(Id);
  LoadPage;
  DoChanged;
end;

end.
