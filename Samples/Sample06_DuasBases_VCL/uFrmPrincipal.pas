unit uFrmPrincipal;

{ Sample06 - duas bases de dados abertas ao mesmo tempo.

  - Cada lado (Base A / Base B) e um TfraBase com sua propria conexao,
    executor e TRepository<TClienteDTO>. O banco de cada lado e escolhido na
    tela (MySQL ou PostgreSQL) e os dois podem ser iguais ou diferentes.
  - Os botoes do meio copiam clientes de uma base para a outra usando o MESMO
    DTO: le com Repo.FindById/FindAll na origem e grava com Repo.Insert no
    destino. O FluentORM gera o SQL de cada dialeto.
  - O log mostra, com o prefixo da base, todo o SQL executado. }

interface

uses
  Winapi.Windows,
  Winapi.Messages,
  System.SysUtils,
  System.Variants,
  System.Classes,
  System.Generics.Collections,
  System.Math,
  System.UITypes,
  Vcl.Graphics,
  Vcl.Controls,
  Vcl.Forms,
  Vcl.Dialogs,
  Vcl.StdCtrls,
  Vcl.ExtCtrls,
  Vcl.ComCtrls,
  FireDAC.Stan.Intf,
  FireDAC.Phys.Intf,
  FireDAC.Phys,
  FireDAC.Phys.MySQL,
  FireDAC.Phys.MySQLDef,
  FireDAC.Phys.PG,
  FireDAC.Phys.PGDef,
  FireDAC.VCLUI.Wait,
  FireDAC.Comp.UI,
  uFluentORM.Types,
  uFluentORM.Executor,
  uFluentORM.Repository,
  uSample06.Model,
  uFraBase;

type
  TfrmPrincipal = class(TForm)
    pnlTopo: TPanel;
    lblInfo: TLabel;
    pnlA: TPanel;
    pnlMeio: TPanel;
    btnCopiarAB: TButton;
    btnCopiarBA: TButton;
    btnCopiarTodosAB: TButton;
    btnCopiarTodosBA: TButton;
    btnComparar: TButton;
    btnLimparLog: TButton;
    pnlB: TPanel;
    splLog: TSplitter;
    memLog: TMemo;
    stbStatus: TStatusBar;
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure FormResize(Sender: TObject);
    procedure btnCopiarABClick(Sender: TObject);
    procedure btnCopiarBAClick(Sender: TObject);
    procedure btnCopiarTodosABClick(Sender: TObject);
    procedure btnCopiarTodosBAClick(Sender: TObject);
    procedure btnCompararClick(Sender: TObject);
    procedure btnLimparLogClick(Sender: TObject);
  private
    FMySQLLink: TFDPhysMySQLDriverLink;
    FPgLink: TFDPhysPgDriverLink;
    FWaitCursor: TFDGUIxWaitCursor;
    FBaseA: TfraBase;
    FBaseB: TfraBase;
    procedure Log(const AText: string);
    procedure SetStatus(const AText: string);
    procedure PreloadClientLibraries;
    function CreateBase(const ACode: string; AParent: TPanel;
      ADatabaseType: TSQLDatabaseType): TfraBase;
    procedure BaseChanged(Sender: TObject);
    procedure UpdateButtons;
    procedure CopySelected(ASource, ATarget: TfraBase);
    procedure CopyAll(ASource, ATarget: TfraBase);
  end;

var
  frmPrincipal: TfrmPrincipal;

implementation

{$R *.dfm}

{ Log / status }

procedure TfrmPrincipal.Log(const AText: string);
begin
  if Assigned(memLog) then
    memLog.Lines.Add(FormatDateTime('hh:nn:ss.zzz', Now) + '  ' + AText);
end;

procedure TfrmPrincipal.SetStatus(const AText: string);
begin
  stbStatus.SimpleText := AText;
end;

{ Inicializacao }

procedure TfrmPrincipal.FormCreate(Sender: TObject);
begin
  Randomize;
  FWaitCursor := TFDGUIxWaitCursor.Create(Self);
  FMySQLLink := TFDPhysMySQLDriverLink.Create(Self);
  FPgLink := TFDPhysPgDriverLink.Create(Self);
  PreloadClientLibraries;

  // Duas instancias independentes do mesmo frame.
  FBaseA := CreateBase('A', pnlA, dbMySQL);
  FBaseB := CreateBase('B', pnlB, dbPostgreSQL);

  FormResize(nil);
  UpdateButtons;
  SetStatus('Escolha o banco de cada lado, informe a senha e clique em "Conectar" ' +
    '(na primeira vez, "Criar banco/tabela").');
end;

procedure TfrmPrincipal.FormDestroy(Sender: TObject);
begin
  FreeAndNil(FBaseA);
  FreeAndNil(FBaseB);
end;

procedure TfrmPrincipal.FormResize(Sender: TObject);
begin
  pnlA.Width := Max(300, (ClientWidth - pnlMeio.Width) div 2);
end;

procedure TfrmPrincipal.PreloadClientLibraries;
var
  Lib: string;
begin
  // As duas DLLs ficam carregadas no mesmo processo. PostgreSQL primeiro:
  // libpq e libmysql usam OpenSSL 3 (libssl-3-x64.dll) e a primeira carregada
  // e compartilhada.
  Lib := PreloadVendorLib(dbPostgreSQL, Log);
  if Lib <> '' then
  begin
    FPgLink.VendorLib := Lib;
    Log('libpq.dll: ' + Lib);
  end;
  Lib := PreloadVendorLib(dbMySQL, Log);
  if Lib <> '' then
  begin
    FMySQLLink.VendorLib := Lib;
    Log('libmysql.dll: ' + Lib);
  end;
end;

function TfrmPrincipal.CreateBase(const ACode: string; AParent: TPanel;
  ADatabaseType: TSQLDatabaseType): TfraBase;
begin
  // Owner nil: duas instancias do mesmo frame com Owner = Self gerariam
  // conflito de nome ("fraBase" ja existe). Liberado em FormDestroy.
  Result := TfraBase.Create(nil);
  Result.Name := 'fraBase' + ACode;
  Result.Parent := AParent;
  Result.Align := alClient;
  Result.Setup(ACode, ADatabaseType, Log);
  Result.OnChanged := BaseChanged;
end;

procedure TfrmPrincipal.BaseChanged(Sender: TObject);
begin
  UpdateButtons;
end;

procedure TfrmPrincipal.UpdateButtons;
var
  Both: Boolean;
begin
  Both := Assigned(FBaseA) and Assigned(FBaseB) and FBaseA.Connected and FBaseB.Connected;
  btnCopiarAB.Enabled := Both;
  btnCopiarBA.Enabled := Both;
  btnCopiarTodosAB.Enabled := Both;
  btnCopiarTodosBA.Enabled := Both;
  btnComparar.Enabled := Both;
end;

{ Operacoes entre as duas bases }

procedure TfrmPrincipal.CopySelected(ASource, ATarget: TfraBase);
var
  Id: Integer;
  Src, Dst: TClienteDTO;
begin
  ASource.EnsureConnected;
  ATarget.EnsureConnected;
  Id := ASource.SelectedId;
  if Id = 0 then
    raise Exception.CreateFmt('Selecione um cliente na Base %s.', [ASource.Code]);

  Src := ASource.Repo.FindById(Id);           // SELECT no dialeto da origem
  if Src = nil then
    raise Exception.Create('Cliente nao encontrado na origem.');
  try
    Dst := TClienteDTO.Create;
    try
      Dst.AssignData(Src);
      ATarget.Repo.Insert(Dst);               // INSERT no dialeto do destino
      Log(Format('Copiado cliente #%d de %s para %s (novo id #%d).',
        [Src.Id, ASource.Description, ATarget.Description, Dst.Id]));
      SetStatus(Format('Cliente "%s" copiado: %s -> %s',
        [Src.Nome, ASource.Description, ATarget.Description]));
    finally
      Dst.Free;
    end;
  finally
    Src.Free;
  end;
  ATarget.ReloadList;
end;

procedure TfrmPrincipal.CopyAll(ASource, ATarget: TfraBase);
var
  Lista: TObjectList<TClienteDTO>;
  Target: TfraBase;
begin
  ASource.EnsureConnected;
  ATarget.EnsureConnected;
  if MessageDlg(Format('Copiar TODOS os clientes de %s para %s?',
       [ASource.Description, ATarget.Description]),
       mtConfirmation, [mbYes, mbNo], 0) <> mrYes then
    Exit;

  Target := ATarget;
  Screen.Cursor := crHourGlass;
  Lista := ASource.Repo.FindAll('id');
  try
    // Uma unica transacao no DESTINO: se algum insert falhar, nada fica gravado.
    TSQLTransaction.ExecuteInTransaction(Target.Executor,
      procedure
      var
        C, D: TClienteDTO;
      begin
        for C in Lista do
        begin
          D := TClienteDTO.Create;
          try
            D.AssignData(C);
            Target.Repo.Insert(D);
          finally
            D.Free;
          end;
        end;
      end);
    Log(Format('%d cliente(s) copiados de %s para %s em uma transacao.',
      [Lista.Count, ASource.Description, ATarget.Description]));
    SetStatus(Format('%d cliente(s) copiados.', [Lista.Count]));
  finally
    Lista.Free;
    Screen.Cursor := crDefault;
  end;
  ATarget.ReloadList;
end;

procedure TfrmPrincipal.btnCopiarABClick(Sender: TObject);
begin
  CopySelected(FBaseA, FBaseB);
end;

procedure TfrmPrincipal.btnCopiarBAClick(Sender: TObject);
begin
  CopySelected(FBaseB, FBaseA);
end;

procedure TfrmPrincipal.btnCopiarTodosABClick(Sender: TObject);
begin
  CopyAll(FBaseA, FBaseB);
end;

procedure TfrmPrincipal.btnCopiarTodosBAClick(Sender: TObject);
begin
  CopyAll(FBaseB, FBaseA);
end;

procedure TfrmPrincipal.btnCompararClick(Sender: TObject);
var
  CountA, CountB: Int64;
begin
  FBaseA.EnsureConnected;
  FBaseB.EnsureConnected;
  CountA := FBaseA.Repo.Count;
  CountB := FBaseB.Repo.Count;
  Log(Format('Comparacao: %s = %d | %s = %d',
    [FBaseA.Description, CountA, FBaseB.Description, CountB]));
  ShowMessage(Format('%s: %d cliente(s)' + sLineBreak + '%s: %d cliente(s)',
    [FBaseA.Description, CountA, FBaseB.Description, CountB]));
end;

procedure TfrmPrincipal.btnLimparLogClick(Sender: TObject);
begin
  memLog.Clear;
end;

end.
