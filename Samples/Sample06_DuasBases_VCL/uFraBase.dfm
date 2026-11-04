object fraBase: TfraBase
  Left = 0
  Top = 0
  Width = 600
  Height = 480
  TabOrder = 0
  object pnlTitulo: TPanel
    Left = 0
    Top = 0
    Width = 600
    Height = 28
    Align = alTop
    Alignment = taLeftJustify
    BevelOuter = bvNone
    Caption = '  Base'
    Color = clHighlight
    Font.Charset = DEFAULT_CHARSET
    Font.Color = clHighlightText
    Font.Height = -13
    Font.Name = 'Segoe UI'
    Font.Style = [fsBold]
    ParentBackground = False
    ParentFont = False
    TabOrder = 0
  end
  object pnlConfig: TPanel
    Left = 0
    Top = 28
    Width = 600
    Height = 84
    Align = alTop
    BevelOuter = bvNone
    TabOrder = 1
    object lblBanco: TLabel
      Left = 8
      Top = 4
      Width = 33
      Height = 15
      Caption = 'Banco'
    end
    object lblServer: TLabel
      Left = 114
      Top = 4
      Width = 43
      Height = 15
      Caption = 'Servidor'
    end
    object lblPort: TLabel
      Left = 230
      Top = 4
      Width = 28
      Height = 15
      Caption = 'Porta'
    end
    object lblDatabase: TLabel
      Left = 286
      Top = 4
      Width = 64
      Height = 15
      Caption = 'Database'
    end
    object lblUser: TLabel
      Left = 402
      Top = 4
      Width = 40
      Height = 15
      Caption = 'Usuario'
    end
    object lblPassword: TLabel
      Left = 488
      Top = 4
      Width = 32
      Height = 15
      Caption = 'Senha'
    end
    object lblConexao: TLabel
      Left = 352
      Top = 56
      Width = 74
      Height = 15
      Caption = 'Desconectado'
      Font.Charset = DEFAULT_CHARSET
      Font.Color = clRed
      Font.Height = -12
      Font.Name = 'Segoe UI'
      Font.Style = [fsBold]
      ParentFont = False
    end
    object cbBanco: TComboBox
      Left = 8
      Top = 20
      Width = 100
      Height = 23
      Style = csDropDownList
      ItemIndex = 0
      TabOrder = 0
      Text = 'MySQL'
      OnChange = cbBancoChange
      Items.Strings = (
        'MySQL'
        'PostgreSQL')
    end
    object edtServer: TEdit
      Left = 114
      Top = 20
      Width = 110
      Height = 23
      TabOrder = 1
      Text = 'localhost'
    end
    object edtPort: TEdit
      Left = 230
      Top = 20
      Width = 50
      Height = 23
      NumbersOnly = True
      TabOrder = 2
    end
    object edtDatabase: TEdit
      Left = 286
      Top = 20
      Width = 110
      Height = 23
      TabOrder = 3
      Text = 'fluentorm_sample06'
    end
    object edtUser: TEdit
      Left = 402
      Top = 20
      Width = 80
      Height = 23
      TabOrder = 4
    end
    object edtPassword: TEdit
      Left = 488
      Top = 20
      Width = 80
      Height = 23
      PasswordChar = '*'
      TabOrder = 5
    end
    object btnConectar: TButton
      Left = 8
      Top = 50
      Width = 96
      Height = 27
      Caption = 'Conectar'
      TabOrder = 6
      OnClick = btnConectarClick
    end
    object btnCriarEstrutura: TButton
      Left = 110
      Top = 50
      Width = 120
      Height = 27
      Caption = 'Criar banco/tabela'
      TabOrder = 7
      OnClick = btnCriarEstruturaClick
    end
    object btnGerarDados: TButton
      Left = 236
      Top = 50
      Width = 110
      Height = 27
      Caption = 'Gerar 10 clientes'
      TabOrder = 8
      OnClick = btnGerarDadosClick
    end
  end
  object pnlFiltro: TPanel
    Left = 0
    Top = 112
    Width = 600
    Height = 38
    Align = alTop
    BevelOuter = bvNone
    TabOrder = 2
    object edtFiltro: TEdit
      Left = 8
      Top = 7
      Width = 170
      Height = 23
      TabOrder = 0
      TextHint = 'Nome, e-mail ou CPF (Enter)'
      OnKeyPress = edtFiltroKeyPress
    end
    object chkAtivos: TCheckBox
      Left = 186
      Top = 10
      Width = 100
      Height = 17
      Caption = 'Somente ativos'
      TabOrder = 1
      OnClick = btnPesquisarClick
    end
    object btnPesquisar: TButton
      Left = 290
      Top = 5
      Width = 80
      Height = 27
      Caption = 'Pesquisar'
      TabOrder = 2
      OnClick = btnPesquisarClick
    end
    object btnEditar: TButton
      Left = 376
      Top = 5
      Width = 80
      Height = 27
      Caption = 'Editar nome'
      TabOrder = 3
      OnClick = btnEditarClick
    end
    object btnExcluir: TButton
      Left = 462
      Top = 5
      Width = 80
      Height = 27
      Caption = 'Excluir'
      TabOrder = 4
      OnClick = btnExcluirClick
    end
  end
  object grdLista: TDBGrid
    Left = 0
    Top = 150
    Width = 600
    Height = 294
    Align = alClient
    DataSource = dsLista
    Options = [dgTitles, dgIndicator, dgColumnResize, dgColLines, dgRowLines, dgTabs, dgRowSelect, dgAlwaysShowSelection, dgConfirmDelete, dgCancelOnExit]
    ReadOnly = True
    TabOrder = 3
    TitleFont.Charset = DEFAULT_CHARSET
    TitleFont.Color = clWindowText
    TitleFont.Height = -12
    TitleFont.Name = 'Segoe UI'
    TitleFont.Style = []
    OnDblClick = grdListaDblClick
  end
  object pnlRodape: TPanel
    Left = 0
    Top = 444
    Width = 600
    Height = 36
    Align = alBottom
    BevelOuter = bvNone
    TabOrder = 4
    object lblPagina: TLabel
      Left = 104
      Top = 11
      Width = 3
      Height = 15
    end
    object btnAnterior: TButton
      Left = 8
      Top = 5
      Width = 90
      Height = 27
      Caption = '< Anterior'
      TabOrder = 0
      OnClick = btnAnteriorClick
    end
    object btnProxima: TButton
      Left = 330
      Top = 5
      Width = 90
      Height = 27
      Caption = 'Proxima >'
      TabOrder = 1
      OnClick = btnProximaClick
    end
  end
  object dsLista: TDataSource
    Left = 520
    Top = 200
  end
end
