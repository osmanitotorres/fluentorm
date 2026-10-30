unit unMain;
interface
uses
  Winapi.Windows,
  Winapi.Messages,
  System.SysUtils,
  System.Classes,
  Vcl.Controls,
  Vcl.Forms,
  Vcl.StdCtrls,
  Vcl.DBGrids,
  Vcl.Grids,
  Data.DB,
  FireDAC.Comp.Client,
  uFluentORM, FireDAC.Stan.Intf, FireDAC.Stan.Option, FireDAC.Stan.Error,
  FireDAC.UI.Intf, FireDAC.Phys.Intf, FireDAC.Stan.Def, FireDAC.Stan.Pool,
  FireDAC.Stan.Async, FireDAC.Phys, FireDAC.VCLUI.Wait, FireDAC.Stan.Param,
  FireDAC.DatS, FireDAC.DApt.Intf, FireDAC.DApt, FireDAC.Comp.DataSet,
  FireDAC.Phys.MySQLDef, FireDAC.Phys.MySQL, FireDAC.Phys.PG,
  FireDAC.Phys.PGDef;
type
  TfrmMain = class(TForm)
    lblDb: TLabel;
    cbDbType: TComboBox;
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
    lblDriver: TLabel;
    edtDriver: TEdit;
    btnCarregar: TButton;
    DBGrid1: TDBGrid;
    FDConnection1: TFDConnection;
    FDQuery1: TFDQuery;
    DataSource1: TDataSource;
    FDPhysMySQLDriverLink1: TFDPhysMySQLDriverLink;
    procedure FormCreate(Sender: TObject);
    procedure cbDbTypeChange(Sender: TObject);
    procedure btnCarregarClick(Sender: TObject);
  private
    function BuildSQL: string;
    procedure ApplyDbDefaults;
    procedure ConnectDatabase;
  public
  end;
var
  frmMain: TfrmMain;
implementation

{$R *.dfm}

procedure TfrmMain.FormCreate(Sender: TObject);
begin
  cbDbType.Items.Clear;
  cbDbType.Items.Add('MySQL');
  cbDbType.Items.Add('SQL Server');
  cbDbType.Items.Add('PostgreSQL');
  cbDbType.ItemIndex := 0;
  ApplyDbDefaults;
  DataSource1.DataSet := FDQuery1;
  DBGrid1.DataSource := DataSource1;
end;


procedure TfrmMain.cbDbTypeChange(Sender: TObject);
begin
  ApplyDbDefaults;
  if FDConnection1.Connected then
    FDConnection1.Connected := False;
end;
procedure TfrmMain.ApplyDbDefaults;
begin
  edtServer.Text := 'localhost';
  edtDatabase.Text := 'chat_database';
  lblDriver.Caption := 'DriverID';
  case cbDbType.ItemIndex of
    0: // MySQL
      begin
        edtPort.Text := '3306';
        edtUser.Text := 'root';
        edtPassword.Text := 'admin';
        edtDriver.Text := 'MySQL';
      end;
    1: // SQL Server
      begin
        edtPort.Text := '1433';
        edtUser.Text := 'sa';
        edtPassword.Text := 'admin';
        edtDriver.Text := 'MSSQL';
      end;
  else // PostgreSQL
    edtPort.Text := '5432';
    edtUser.Text := 'postgres';
    edtPassword.Text := 'admin';
    edtDriver.Text := 'PG';
  end;
end;


procedure TfrmMain.ConnectDatabase;
begin
  if FDConnection1.Connected then
    Exit;
  FDConnection1.LoginPrompt := False;
  FDConnection1.Params.Clear;
  FDConnection1.Params.Values['DriverID'] := Trim(edtDriver.Text);
  FDConnection1.Params.Values['Server'] := Trim(edtServer.Text);
  FDConnection1.Params.Values['Port'] := Trim(edtPort.Text);
  FDConnection1.Params.Values['Database'] := Trim(edtDatabase.Text);
  FDConnection1.Params.Values['User_Name'] := Trim(edtUser.Text);
  FDConnection1.Params.Values['Password'] := edtPassword.Text;
  FDConnection1.Connected := True;
end;
//o Gerador de SQL do FluentORM e desacoplado, por isso pode usar FireDac/Unidac/Zeos etc...
//Nesse exemplo, uso FireDAC/MySQL, FireDAC/MSSQL e FireDAC/PostgreSQL
function TfrmMain.BuildSQL: string;
var
  SQL: TSQLBuilder;
begin
  SQL := TSQLBuilder.Create;
  try
    case cbDbType.ItemIndex of
      0: SQL.SetDatabaseType(dbMySQL);
      1: SQL.SetDatabaseType(dbMSSQL);
    else
      SQL.SetDatabaseType(dbPostgreSQL);
    end;
    Result := SQL.Select
                 .All
                 .From('usuario')
                 .OrderBy('id', odAsc)
                 .ToSQL;
  finally
    SQL.Free;
  end;
end;


procedure TfrmMain.btnCarregarClick(Sender: TObject);
begin
  ConnectDatabase;
  FDQuery1.Close;
  FDQuery1.Connection := FDConnection1;
  FDQuery1.SQL.Text := BuildSQL;
  FDQuery1.Open;
end;

end.
