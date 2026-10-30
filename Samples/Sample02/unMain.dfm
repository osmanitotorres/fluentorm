object frmMain: TfrmMain
  Left = 0
  Top = 0
  Caption = 'FluentORM - Sample02 (MySQL / SQL Server / PostgreSQL)'
  ClientHeight = 560
  ClientWidth = 940
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'Tahoma'
  Font.Style = []
  OldCreateOrder = False
  Position = poScreenCenter
  OnCreate = FormCreate
  PixelsPerInch = 96
  TextHeight = 13
  object lblDb: TLabel
    Left = 16
    Top = 14
    Width = 45
    Height = 13
    Caption = 'Banco DB'
  end
  object lblServer: TLabel
    Left = 208
    Top = 14
    Width = 32
    Height = 13
    Caption = 'Server'
  end
  object lblPort: TLabel
    Left = 432
    Top = 14
    Width = 20
    Height = 13
    Caption = 'Port'
  end
  object lblDatabase: TLabel
    Left = 516
    Top = 14
    Width = 46
    Height = 13
    Caption = 'Database'
  end
  object lblUser: TLabel
    Left = 16
    Top = 60
    Width = 22
    Height = 13
    Caption = 'User'
  end
  object lblPassword: TLabel
    Left = 188
    Top = 60
    Width = 46
    Height = 13
    Caption = 'Password'
  end
  object lblDriver: TLabel
    Left = 432
    Top = 60
    Width = 40
    Height = 13
    Caption = 'DriverID'
  end
  object cbDbType: TComboBox
    Left = 16
    Top = 32
    Width = 177
    Height = 21
    Style = csDropDownList
    TabOrder = 0
    OnChange = cbDbTypeChange
  end
  object edtServer: TEdit
    Left = 208
    Top = 32
    Width = 209
    Height = 21
    TabOrder = 1
  end
  object edtPort: TEdit
    Left = 432
    Top = 32
    Width = 73
    Height = 21
    TabOrder = 2
  end
  object edtDatabase: TEdit
    Left = 516
    Top = 32
    Width = 225
    Height = 21
    TabOrder = 3
  end
  object edtUser: TEdit
    Left = 16
    Top = 78
    Width = 161
    Height = 21
    TabOrder = 4
  end
  object edtPassword: TEdit
    Left = 188
    Top = 78
    Width = 229
    Height = 21
    PasswordChar = '*'
    TabOrder = 5
  end
  object edtDriver: TEdit
    Left = 432
    Top = 78
    Width = 309
    Height = 21
    TabOrder = 6
  end
  object btnCarregar: TButton
    Left = 760
    Top = 30
    Width = 161
    Height = 69
    Caption = 'Carregar tabela usuario'
    TabOrder = 7
    OnClick = btnCarregarClick
  end
  object DBGrid1: TDBGrid
    Left = 16
    Top = 120
    Width = 905
    Height = 425
    DataSource = DataSource1
    TabOrder = 8
    TitleFont.Charset = DEFAULT_CHARSET
    TitleFont.Color = clWindowText
    TitleFont.Height = -11
    TitleFont.Name = 'Tahoma'
    TitleFont.Style = []
  end
  object FDConnection1: TFDConnection
    LoginPrompt = False
    Left = 840
    Top = 136
  end
  object FDQuery1: TFDQuery
    Connection = FDConnection1
    Left = 840
    Top = 192
  end
  object DataSource1: TDataSource
    DataSet = FDQuery1
    Left = 840
    Top = 248
  end
  object FDPhysMySQLDriverLink1: TFDPhysMySQLDriverLink
    Left = 736
    Top = 328
  end
end
