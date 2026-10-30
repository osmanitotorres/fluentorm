unit uFrmClientes;

{ Cadastro de clientes com FluentORM + FireDAC + MySQL.

  O que este formulario demonstra:
  - conexao FireDAC com MySQL (localiza a libmysql.dll do MySQL Server);
  - criacao do banco e da tabela;
  - listagem com TSQLBuilder: filtro (LIKE em grupo OR), "somente ativos",
    ordenacao, paginacao (LIMIT/OFFSET) e total com ToSQLCount;
  - TRepository<T>: FindById, Insert (id volta para a entidade), Update, DeleteById;
  - TSQLTransaction.ExecuteInTransaction para gerar varios clientes de uma vez;
  - log de todo o SQL executado (decorator TLoggingExecutor) e do SQL gerado
    pelo builder (evento OnSQLGenerated). }

interface

uses
  Winapi.Windows,
  Winapi.Messages,
  System.SysUtils,
  System.Variants,
  System.Classes,
  System.IOUtils,
  System.Math,
  System.UITypes,
  Vcl.Graphics,
  Vcl.Controls,
  Vcl.Forms,
  Vcl.Dialogs,
  Vcl.StdCtrls,
  Vcl.ExtCtrls,
  Vcl.ComCtrls,
  Vcl.Grids,
  Vcl.DBGrids,
  Data.DB,
  FireDAC.Stan.Intf,
  FireDAC.Stan.Option,
  FireDAC.Stan.Error,
  FireDAC.UI.Intf,
  FireDAC.Phys.Intf,
  FireDAC.Stan.Def,
  FireDAC.Stan.Pool,
  FireDAC.Stan.Async,
  FireDAC.Phys,
  FireDAC.Phys.MySQL,
  FireDAC.Phys.MySQLDef,
  FireDAC.VCLUI.Wait,
  FireDAC.Stan.Param,
  FireDAC.DatS,
  FireDAC.DApt.Intf,
  FireDAC.DApt,
  FireDAC.Comp.DataSet,
  FireDAC.Comp.Client,
  uFluentORM.Types,
  uFluentORM,
  uFluentORM.Executor,
  uFluentORM.Executor.FireDAC,
  uFluentORM.Repository,
  uSample04.Model;

type
  TfrmClientes = class(TForm)
    pnlConexao: TPanel;
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
    pgcPrincipal: TPageControl;
    tsLista: TTabSheet;
    tsEdicao: TTabSheet;
    tsSQL: TTabSheet;
    pnlFiltro: TPanel;
    edtFiltro: TEdit;
    chkSomenteAtivos: TCheckBox;
    btnPesquisar: TButton;
    btnNovo: TButton;
    btnEditar: TButton;
    btnExcluir: TButton;
    grdClientes: TDBGrid;
    pnlPaginacao: TPanel;
    btnAnterior: TButton;
    lblPagina: TLabel;
    btnProxima: TButton;
    dsClientes: TDataSource;
    lblId: TLabel;
    edtId: TEdit;
    lblNome: TLabel;
    edtNome: TEdit;
    lblEmail: TLabel;
    edtEmail: TEdit;
    lblCpf: TLabel;
    edtCpf: TEdit;
    lblTelefone: TLabel;
    edtTelefone: TEdit;
    lblNascimento: TLabel;
    dtpNascimento: TDateTimePicker;
    lblLimite: TLabel;
    edtLimite: TEdit;
    chkAtivo: TCheckBox;
    lblObservacao: TLabel;
    memObservacao: TMemo;
    lblAuditoria: TLabel;
    btnSalvar: TButton;
    btnCancelar: TButton;
    pnlLog: TPanel;
    btnLimparLog: TButton;
    memSQL: TMemo;
    stbStatus: TStatusBar;
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure btnConectarClick(Sender: TObject);
    procedure btnCriarEstruturaClick(Sender: TObject);
    procedure btnGerarDadosClick(Sender: TObject);
    procedure btnPesquisarClick(Sender: TObject);
    procedure btnNovoClick(Sender: TObject);
    procedure btnEditarClick(Sender: TObject);
    procedure btnExcluirClick(Sender: TObject);
    procedure btnAnteriorClick(Sender: TObject);
    procedure btnProximaClick(Sender: TObject);
    procedure btnSalvarClick(Sender: TObject);
    procedure btnCancelarClick(Sender: TObject);
    procedure btnLimparLogClick(Sender: TObject);
    procedure grdClientesDblClick(Sender: TObject);
    procedure edtFiltroKeyPress(Sender: TObject; var Key: Char);
  private
    FConnection: TFDConnection;
    FDriverLink: TFDPhysMySQLDriverLink;
    FExecutor: ISQLExecutor;
    FQueryExecutor: ISQLQueryExecutor;
    FRepo: TRepository<TClienteDTO>;
    FListData: TDataSet;
    FPage: Integer;
    FTotal: Int64;
    FEditing: TClienteDTO; // cliente em edicao; nil = novo
    procedure Log(const AText: string);
    procedure SQLGenerated(Sender: TObject; const ASQL: string);
    procedure SetStatus(const AText: string);
    procedure ConfigureVendorLib;
    procedure ApplyConnectionParams(AWithDatabase: Boolean);
    procedure Connect(ALoadList: Boolean);
    procedure Disconnect;
    procedure EnsureConnected;
    procedure LoadPage;
    procedure ConfigureGridFields;
    procedure UpdateControls;
    function PageCount: Integer;
    function SelectedId: Integer;
    procedure ShowList;
    procedure ShowEditor(ACliente: TClienteDTO);
    procedure ClearEditor;
    procedure EntityToEditor(ACliente: TClienteDTO);
    procedure EditorToEntity(ACliente: TClienteDTO);
  end;

var
  frmClientes: TfrmClientes;

implementation

{$R *.dfm}

const
  PAGE_SIZE = 10;

{ Log / status }

procedure TfrmClientes.Log(const AText: string);
begin
  memSQL.Lines.Add(FormatDateTime('hh:nn:ss.zzz', Now) + '  ' + AText);
end;

procedure TfrmClientes.SQLGenerated(Sender: TObject; const ASQL: string);
begin
  Log('[Builder] ' + ASQL);
end;

procedure TfrmClientes.SetStatus(const AText: string);
begin
  stbStatus.SimpleText := AText;
end;

{ Criacao / destruicao }

procedure TfrmClientes.FormCreate(Sender: TObject);
begin
  FConnection := TFDConnection.Create(Self);
  FConnection.LoginPrompt := False;
  FDriverLink := TFDPhysMySQLDriverLink.Create(Self);
  FPage := 1;
  Randomize;

  tsEdicao.TabVisible := False;
  pgcPrincipal.ActivePage := tsLista;
  dtpNascimento.Date := Date;
  dtpNascimento.Checked := False;

  ConfigureVendorLib;
  UpdateControls;
  SetStatus('Desconectado. Confira os dados de acesso e clique em "Conectar" ' +
    '(na primeira vez, use "Criar banco/tabela").');
end;

procedure TfrmClientes.FormDestroy(Sender: TObject);
begin
  Disconnect;
  FreeAndNil(FEditing);
end;

{ Conexao }

procedure TfrmClientes.ConfigureVendorLib;
var
  ExeLib, Root, Lib: string;
  Dirs: TArray<string>;
  I: Integer;
begin
  // 1) libmysql.dll ao lado do executavel: o FireDAC encontra sozinho.
  ExeLib := TPath.Combine(ExtractFilePath(ParamStr(0)), 'libmysql.dll');
  if FileExists(ExeLib) then
  begin
    Log('libmysql.dll: ' + ExeLib);
    Exit;
  end;

  // 2) Instalacao do MySQL Server (C:\Program Files\MySQL\MySQL Server x.y).
  //    A libmysql.dll fica em "lib" e as dependencias (OpenSSL) em "bin".
  Root := TPath.Combine(GetEnvironmentVariable('ProgramFiles'), 'MySQL');
  if TDirectory.Exists(Root) then
  begin
    Dirs := TDirectory.GetDirectories(Root, 'MySQL Server*');
    for I := High(Dirs) downto Low(Dirs) do // versao mais nova primeiro
    begin
      Lib := TPath.Combine(Dirs[I], 'lib\libmysql.dll');
      if FileExists(Lib) then
      begin
        SetDllDirectory(PChar(TPath.Combine(Dirs[I], 'bin')));
        FDriverLink.VendorLib := Lib;
        Log('libmysql.dll: ' + Lib);
        Exit;
      end;
    end;
  end;

  Log('libmysql.dll nao encontrada. Copie a libmysql.dll (mesma arquitetura do ' +
    'executavel) para a pasta do .exe.');
  {$IFDEF WIN32}
  Log('Atencao: este executavel e 32 bits; o MySQL Server instala a libmysql.dll ' +
    '64 bits. Compile o projeto em Win64.');
  {$ENDIF}
end;

procedure TfrmClientes.ApplyConnectionParams(AWithDatabase: Boolean);
begin
  FConnection.Connected := False;
  FConnection.Params.Clear;
  FConnection.Params.Values['DriverID'] := 'MySQL';
  FConnection.Params.Values['Server'] := Trim(edtServer.Text);
  FConnection.Params.Values['Port'] := Trim(edtPort.Text);
  FConnection.Params.Values['User_Name'] := Trim(edtUser.Text);
  FConnection.Params.Values['Password'] := edtPassword.Text;
  FConnection.Params.Values['CharacterSet'] := 'utf8mb4';
  if AWithDatabase then
    FConnection.Params.Values['Database'] := Trim(edtDatabase.Text);
end;

procedure TfrmClientes.Connect(ALoadList: Boolean);
var
  Inner: TFireDACSQLExecutor;
  Logger: TLoggingExecutor;
begin
  Disconnect;
  ApplyConnectionParams(True);
  FConnection.Connected := True;

  // Executor FireDAC (nao e dono da conexao) envolvido pelo decorator de log.
  Inner := TFireDACSQLExecutor.Create(FConnection);
  Logger := TLoggingExecutor.Create(Inner, Log);
  FExecutor := Logger;
  FQueryExecutor := Logger;
  FRepo := TRepository<TClienteDTO>.Create(FExecutor);

  Log(Format('Conectado: %s:%s / %s (driver %s)',
    [edtServer.Text, edtPort.Text, edtDatabase.Text, Inner.GetDriverID]));
  SetStatus('Conectado a ' + edtServer.Text + ' / ' + edtDatabase.Text);
  FPage := 1;
  UpdateControls;
  if ALoadList then
    LoadPage;
end;

procedure TfrmClientes.Disconnect;
begin
  dsClientes.DataSet := nil;
  FreeAndNil(FListData);
  FreeAndNil(FRepo);
  FQueryExecutor := nil;
  FExecutor := nil;
  if Assigned(FConnection) then
    FConnection.Connected := False;
end;

procedure TfrmClientes.EnsureConnected;
begin
  if FRepo = nil then
    raise Exception.Create('Conecte ao banco primeiro (botao "Conectar").');
end;

procedure TfrmClientes.btnConectarClick(Sender: TObject);
begin
  Screen.Cursor := crHourGlass;
  try
    Connect(True);
  finally
    Screen.Cursor := crDefault;
  end;
end;

procedure TfrmClientes.btnCriarEstruturaClick(Sender: TObject);
var
  DbName: string;
begin
  DbName := Trim(edtDatabase.Text);
  if not TSQLDialect.IsSimpleIdentifier(DbName) or (Pos('.', DbName) > 0) then
    raise Exception.Create('Nome de banco invalido: use letras, numeros e "_".');

  Screen.Cursor := crHourGlass;
  try
    // 1) Conecta sem banco e cria o database.
    Disconnect;
    ApplyConnectionParams(False);
    FConnection.Connected := True;
    try
      FConnection.ExecSQL('CREATE DATABASE IF NOT EXISTS ' +
        TSQLDialect.QuoteIdentifier(DbName, dbMySQL) +
        ' CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci');
      Log('[DDL] CREATE DATABASE IF NOT EXISTS ' + DbName);
    finally
      FConnection.Connected := False;
    end;

    // 2) Conecta no banco e cria a tabela pelo executor (aparece no log).
    Connect(False);
    FExecutor.Execute(SQL_CREATE_TABLE_CLIENTE, []);
    LoadPage;
  finally
    Screen.Cursor := crDefault;
  end;
  ShowMessage('Banco "' + DbName + '" e tabela "cliente" prontos.');
end;

{ Listagem com o SQL Builder }

function TfrmClientes.PageCount: Integer;
begin
  Result := Max(1, Ceil(FTotal / PAGE_SIZE));
end;

procedure TfrmClientes.LoadPage;
var
  SQL: TSQLBuilder;
  Filtro: string;
  SQLText: string;
  Total: Variant;
  NewData: TDataSet;
begin
  EnsureConnected;
  SQL := TSQLBuilder.Create;
  try
    SQL.SetDatabaseType(dbMySQL);
    SQL.QuoteIdentifiers := True;          // `cliente`.`nome`...
    SQL.OnSQLGenerated := SQLGenerated;    // StrictMode e UseNamedParams ja vem True

    SQL.Select
       .Fields(['id', 'nome', 'email', 'cpf', 'telefone',
                'data_nascimento', 'limite_credito', 'ativo'])
       .From('cliente');

    Filtro := Trim(edtFiltro.Text);
    if Filtro <> '' then
      SQL.BeginWhereGroup
           .WhereLike('nome', Filtro)
           .OrWhere('email', '%' + Filtro + '%', opLike)
           .OrWhere('cpf', '%' + Filtro + '%', opLike)
         .EndWhereGroup;

    if chkSomenteAtivos.Checked then
      SQL.AndWhere('ativo', True);

    // Total de registros (mesmo filtro, sem ORDER BY/LIMIT).
    SQLText := SQL.ToSQLCount;
    Total := FExecutor.ExecuteScalar(SQLText, SQL.ToSQLParams);
    if VarIsNull(Total) then
      FTotal := 0
    else
      FTotal := Total;
    if FPage > PageCount then
      FPage := PageCount;

    // Pagina atual.
    SQL.OrderByAsc('nome').OrderByAsc('id').Paginate(FPage, PAGE_SIZE);
    SQLText := SQL.ToSQL;
    NewData := FQueryExecutor.OpenDataSet(SQLText, SQL.ToSQLParams);
  finally
    SQL.Free;
  end;

  dsClientes.DataSet := NewData;
  FreeAndNil(FListData);
  FListData := NewData;
  ConfigureGridFields;
  UpdateControls;
end;

procedure TfrmClientes.ConfigureGridFields;

  procedure SetupField(const AName, ALabel: string; AWidth: Integer);
  var
    F: TField;
  begin
    F := FListData.FindField(AName);
    if F = nil then
      Exit;
    F.DisplayLabel := ALabel;
    F.DisplayWidth := AWidth;
  end;

var
  F: TField;
begin
  if FListData = nil then
    Exit;
  SetupField('id', 'Id', 6);
  SetupField('nome', 'Nome', 28);
  SetupField('email', 'E-mail', 28);
  SetupField('cpf', 'CPF', 15);
  SetupField('telefone', 'Telefone', 15);
  SetupField('data_nascimento', 'Nascimento', 11);
  SetupField('limite_credito', 'Limite', 12);
  SetupField('ativo', 'Ativo', 6);

  F := FListData.FindField('limite_credito');
  if F is TNumericField then
    TNumericField(F).DisplayFormat := '#,##0.00';
  F := FListData.FindField('ativo');
  if F is TBooleanField then
    TBooleanField(F).DisplayValues := 'Sim;Nao';
end;

procedure TfrmClientes.UpdateControls;
var
  Connected: Boolean;
begin
  Connected := FRepo <> nil;
  btnGerarDados.Enabled := Connected;
  btnPesquisar.Enabled := Connected;
  btnNovo.Enabled := Connected;
  btnEditar.Enabled := Connected and (FListData <> nil) and not FListData.IsEmpty;
  btnExcluir.Enabled := btnEditar.Enabled;
  btnAnterior.Enabled := Connected and (FPage > 1);
  btnProxima.Enabled := Connected and (FPage < PageCount);
  if Connected then
    lblPagina.Caption := Format('Pagina %d de %d  -  %d cliente(s)',
      [FPage, PageCount, FTotal])
  else
    lblPagina.Caption := '';
end;

procedure TfrmClientes.btnPesquisarClick(Sender: TObject);
begin
  if (Sender = chkSomenteAtivos) and (FRepo = nil) then
    Exit; // checkbox marcado antes de conectar
  FPage := 1;
  LoadPage;
end;

procedure TfrmClientes.edtFiltroKeyPress(Sender: TObject; var Key: Char);
begin
  if Key = #13 then
  begin
    Key := #0;
    btnPesquisarClick(Sender);
  end;
end;

procedure TfrmClientes.btnAnteriorClick(Sender: TObject);
begin
  if FPage > 1 then
  begin
    Dec(FPage);
    LoadPage;
  end;
end;

procedure TfrmClientes.btnProximaClick(Sender: TObject);
begin
  if FPage < PageCount then
  begin
    Inc(FPage);
    LoadPage;
  end;
end;

function TfrmClientes.SelectedId: Integer;
begin
  if (FListData = nil) or FListData.IsEmpty then
    raise Exception.Create('Selecione um cliente na lista.');
  Result := FListData.FieldByName('id').AsInteger;
end;

{ Gerar dados em transacao }

procedure TfrmClientes.btnGerarDadosClick(Sender: TObject);
const
  NOMES: array[0..9] of string = ('Ana', 'Bruno', 'Carla', 'Diego', 'Elisa',
    'Fabio', 'Gabriela', 'Heitor', 'Isabela', 'Joao');
  SOBRENOMES: array[0..4] of string = ('Silva', 'Souza', 'Oliveira', 'Pereira', 'Costa');
var
  Lote: string;
begin
  EnsureConnected;
  Lote := FormatDateTime('hhnnss', Now);
  Screen.Cursor := crHourGlass;
  try
    // Todos os INSERTs no mesmo commit; qualquer erro desfaz o lote inteiro.
    TSQLTransaction.ExecuteInTransaction(FExecutor,
      procedure
      var
        I: Integer;
        C: TClienteDTO;
        Nome: string;
      begin
        for I := 1 to 25 do
        begin
          C := TClienteDTO.Create;
          try
            Nome := NOMES[Random(Length(NOMES))] + ' ' +
                    SOBRENOMES[Random(Length(SOBRENOMES))];
            C.Nome := Nome;
            C.Email := LowerCase(StringReplace(Nome, ' ', '.', [rfReplaceAll])) +
                       '.' + Lote + IntToStr(I) + '@exemplo.com';
            C.Cpf := Format('%.3d.%.3d.%.3d-%.2d',
              [Random(1000), Random(1000), Random(1000), Random(100)]);
            C.Telefone := Format('(11) 9%.4d-%.4d', [Random(10000), Random(10000)]);
            if I mod 4 <> 0 then
              C.DataNascimento := VarFromDateTime(
                EncodeDate(1960 + Random(45), 1 + Random(12), 1 + Random(28)));
            C.LimiteCredito := Random(500000) / 100;
            C.Ativo := I mod 5 <> 0;
            C.Observacao := 'Gerado pelo Sample04 (lote ' + Lote + ')';
            FRepo.Insert(C);
          finally
            C.Free;
          end;
        end;
      end);
  finally
    Screen.Cursor := crDefault;
  end;
  FPage := 1;
  LoadPage;
  SetStatus('25 clientes gerados em uma unica transacao.');
end;

{ Edicao }

procedure TfrmClientes.ShowList;
begin
  FreeAndNil(FEditing);
  tsEdicao.TabVisible := False;
  pgcPrincipal.ActivePage := tsLista;
end;

procedure TfrmClientes.ShowEditor(ACliente: TClienteDTO);
begin
  if FEditing <> ACliente then
    FreeAndNil(FEditing);
  FEditing := ACliente;
  if ACliente = nil then
  begin
    ClearEditor;
    tsEdicao.Caption := 'Novo cliente';
  end
  else
  begin
    EntityToEditor(ACliente);
    tsEdicao.Caption := 'Cliente #' + IntToStr(ACliente.Id);
  end;
  tsEdicao.TabVisible := True;
  pgcPrincipal.ActivePage := tsEdicao;
  edtNome.SetFocus;
end;

procedure TfrmClientes.ClearEditor;
begin
  edtId.Text := '(novo)';
  edtNome.Text := '';
  edtEmail.Text := '';
  edtCpf.Text := '';
  edtTelefone.Text := '';
  dtpNascimento.Date := Date;
  dtpNascimento.Checked := False;
  edtLimite.Text := FormatFloat('0.00', 0);
  chkAtivo.Checked := True;
  memObservacao.Clear;
  lblAuditoria.Caption := '';
end;

procedure TfrmClientes.EntityToEditor(ACliente: TClienteDTO);
begin
  edtId.Text := IntToStr(ACliente.Id);
  edtNome.Text := ACliente.Nome;
  edtEmail.Text := ACliente.Email;
  edtCpf.Text := ACliente.Cpf;
  edtTelefone.Text := ACliente.Telefone;
  if VarIsNull(ACliente.DataNascimento) or VarIsEmpty(ACliente.DataNascimento) then
  begin
    dtpNascimento.Date := Date;
    dtpNascimento.Checked := False;
  end
  else
  begin
    dtpNascimento.Date := VarToDateTime(ACliente.DataNascimento);
    dtpNascimento.Checked := True;
  end;
  edtLimite.Text := FormatFloat('0.00', ACliente.LimiteCredito);
  chkAtivo.Checked := ACliente.Ativo;
  memObservacao.Text := ACliente.Observacao;

  lblAuditoria.Caption := 'Criado em ' + DateTimeToStr(ACliente.CriadoEm);
  if not (VarIsNull(ACliente.AtualizadoEm) or VarIsEmpty(ACliente.AtualizadoEm)) then
    lblAuditoria.Caption := lblAuditoria.Caption + '   |   Atualizado em ' +
      DateTimeToStr(VarToDateTime(ACliente.AtualizadoEm));
end;

procedure TfrmClientes.EditorToEntity(ACliente: TClienteDTO);
var
  Limite: Currency;
begin
  if Trim(edtNome.Text) = '' then
  begin
    edtNome.SetFocus;
    raise Exception.Create('Informe o nome do cliente.');
  end;
  if not TryStrToCurr(Trim(edtLimite.Text), Limite) then
  begin
    edtLimite.SetFocus;
    raise Exception.Create('Limite de credito invalido.');
  end;

  ACliente.Nome := Trim(edtNome.Text);
  ACliente.Email := Trim(edtEmail.Text);
  ACliente.Cpf := Trim(edtCpf.Text);
  ACliente.Telefone := Trim(edtTelefone.Text);
  if dtpNascimento.Checked then
    ACliente.DataNascimento := VarFromDateTime(Trunc(dtpNascimento.Date))
  else
    ACliente.DataNascimento := Null;
  ACliente.LimiteCredito := Limite;
  ACliente.Ativo := chkAtivo.Checked;
  ACliente.Observacao := memObservacao.Text;
end;

procedure TfrmClientes.btnNovoClick(Sender: TObject);
begin
  EnsureConnected;
  ShowEditor(nil);
end;

procedure TfrmClientes.btnEditarClick(Sender: TObject);
var
  C: TClienteDTO;
begin
  EnsureConnected;
  C := FRepo.FindById(SelectedId); // SELECT ... WHERE `id` = :k_id
  if C = nil then
    raise Exception.Create('Cliente nao encontrado (pode ter sido excluido).');
  ShowEditor(C);
end;

procedure TfrmClientes.grdClientesDblClick(Sender: TObject);
begin
  if btnEditar.Enabled then
    btnEditarClick(Sender);
end;

procedure TfrmClientes.btnSalvarClick(Sender: TObject);
var
  C: TClienteDTO;
begin
  EnsureConnected;
  if FEditing = nil then
  begin
    C := TClienteDTO.Create;
    try
      EditorToEntity(C);
      FRepo.Insert(C); // o id gerado volta para C.Id
      SetStatus('Cliente #' + IntToStr(C.Id) + ' incluido.');
    finally
      C.Free;
    end;
  end
  else
  begin
    EditorToEntity(FEditing);
    FRepo.Update(FEditing);
    SetStatus('Cliente #' + IntToStr(FEditing.Id) + ' alterado.');
  end;
  ShowList;
  LoadPage;
end;

procedure TfrmClientes.btnCancelarClick(Sender: TObject);
begin
  ShowList;
end;

procedure TfrmClientes.btnExcluirClick(Sender: TObject);
var
  Id: Integer;
  Nome: string;
begin
  EnsureConnected;
  Id := SelectedId;
  Nome := FListData.FieldByName('nome').AsString;
  if MessageDlg(Format('Excluir o cliente #%d - %s?', [Id, Nome]),
       mtConfirmation, [mbYes, mbNo], 0) <> mrYes then
    Exit;
  FRepo.DeleteById(Id);
  SetStatus(Format('Cliente #%d excluido.', [Id]));
  LoadPage;
end;

procedure TfrmClientes.btnLimparLogClick(Sender: TObject);
begin
  memSQL.Clear;
end;

end.
