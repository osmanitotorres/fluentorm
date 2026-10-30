object frmClientes: TfrmClientes
  Left = 0
  Top = 0
  Caption = 'FluentORM - Cadastro de Clientes (MySQL)'
  ClientHeight = 640
  ClientWidth = 1000
  Color = clBtnFace
  Constraints.MinHeight = 500
  Constraints.MinWidth = 900
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = 'Segoe UI'
  Font.Style = []
  Position = poScreenCenter
  OnCreate = FormCreate
  OnDestroy = FormDestroy
  TextHeight = 15
  object pnlConexao: TPanel
    Left = 0
    Top = 0
    Width = 1000
    Height = 64
    Align = alTop
    BevelOuter = bvNone
    TabOrder = 0
    object lblServer: TLabel
      Left = 8
      Top = 8
      Width = 43
      Height = 15
      Caption = 'Servidor'
    end
    object lblPort: TLabel
      Left = 144
      Top = 8
      Width = 28
      Height = 15
      Caption = 'Porta'
    end
    object lblDatabase: TLabel
      Left = 208
      Top = 8
      Width = 33
      Height = 15
      Caption = 'Banco'
    end
    object lblUser: TLabel
      Left = 352
      Top = 8
      Width = 40
      Height = 15
      Caption = 'Usuario'
    end
    object lblPassword: TLabel
      Left = 472
      Top = 8
      Width = 32
      Height = 15
      Caption = 'Senha'
    end
    object edtServer: TEdit
      Left = 8
      Top = 26
      Width = 128
      Height = 23
      TabOrder = 0
      Text = 'localhost'
    end
    object edtPort: TEdit
      Left = 144
      Top = 26
      Width = 56
      Height = 23
      NumbersOnly = True
      TabOrder = 1
      Text = '3306'
    end
    object edtDatabase: TEdit
      Left = 208
      Top = 26
      Width = 136
      Height = 23
      TabOrder = 2
      Text = 'fluentorm_demo'
    end
    object edtUser: TEdit
      Left = 352
      Top = 26
      Width = 112
      Height = 23
      TabOrder = 3
      Text = 'osmanito'
    end
    object edtPassword: TEdit
      Left = 472
      Top = 26
      Width = 112
      Height = 23
      PasswordChar = '*'
      TabOrder = 4
    end
    object btnConectar: TButton
      Left = 596
      Top = 24
      Width = 100
      Height = 27
      Caption = 'Conectar'
      TabOrder = 5
      OnClick = btnConectarClick
    end
    object btnCriarEstrutura: TButton
      Left = 702
      Top = 24
      Width = 136
      Height = 27
      Caption = 'Criar banco/tabela'
      TabOrder = 6
      OnClick = btnCriarEstruturaClick
    end
    object btnGerarDados: TButton
      Left = 844
      Top = 24
      Width = 136
      Height = 27
      Caption = 'Gerar 25 clientes'
      TabOrder = 7
      OnClick = btnGerarDadosClick
    end
  end
  object pgcPrincipal: TPageControl
    Left = 0
    Top = 64
    Width = 1000
    Height = 557
    ActivePage = tsLista
    Align = alClient
    TabOrder = 1
    object tsLista: TTabSheet
      Caption = 'Clientes'
      object pnlFiltro: TPanel
        Left = 0
        Top = 0
        Width = 992
        Height = 44
        Align = alTop
        BevelOuter = bvNone
        TabOrder = 0
        object edtFiltro: TEdit
          Left = 8
          Top = 10
          Width = 280
          Height = 23
          TabOrder = 0
          TextHint = 'Pesquisar por nome, e-mail ou CPF (Enter)'
          OnKeyPress = edtFiltroKeyPress
        end
        object chkSomenteAtivos: TCheckBox
          Left = 300
          Top = 13
          Width = 110
          Height = 17
          Caption = 'Somente ativos'
          TabOrder = 1
          OnClick = btnPesquisarClick
        end
        object btnPesquisar: TButton
          Left = 416
          Top = 8
          Width = 90
          Height = 27
          Caption = 'Pesquisar'
          TabOrder = 2
          OnClick = btnPesquisarClick
        end
        object btnNovo: TButton
          Left = 560
          Top = 8
          Width = 90
          Height = 27
          Caption = 'Novo'
          TabOrder = 3
          OnClick = btnNovoClick
        end
        object btnEditar: TButton
          Left = 656
          Top = 8
          Width = 90
          Height = 27
          Caption = 'Editar'
          TabOrder = 4
          OnClick = btnEditarClick
        end
        object btnExcluir: TButton
          Left = 752
          Top = 8
          Width = 90
          Height = 27
          Caption = 'Excluir'
          TabOrder = 5
          OnClick = btnExcluirClick
        end
      end
      object grdClientes: TDBGrid
        Left = 0
        Top = 44
        Width = 992
        Height = 439
        Align = alClient
        DataSource = dsClientes
        Options = [dgTitles, dgIndicator, dgColumnResize, dgColLines, dgRowLines, dgTabs, dgRowSelect, dgAlwaysShowSelection, dgConfirmDelete, dgCancelOnExit, dgTitleClick, dgTitleHotTrack]
        ReadOnly = True
        TabOrder = 1
        TitleFont.Charset = DEFAULT_CHARSET
        TitleFont.Color = clWindowText
        TitleFont.Height = -12
        TitleFont.Name = 'Segoe UI'
        TitleFont.Style = []
        OnDblClick = grdClientesDblClick
      end
      object pnlPaginacao: TPanel
        Left = 0
        Top = 483
        Width = 992
        Height = 44
        Align = alBottom
        BevelOuter = bvNone
        TabOrder = 2
        object lblPagina: TLabel
          Left = 120
          Top = 14
          Width = 3
          Height = 15
        end
        object btnAnterior: TButton
          Left = 8
          Top = 8
          Width = 100
          Height = 27
          Caption = '< Anterior'
          TabOrder = 0
          OnClick = btnAnteriorClick
        end
        object btnProxima: TButton
          Left = 400
          Top = 8
          Width = 100
          Height = 27
          Caption = 'Proxima >'
          TabOrder = 1
          OnClick = btnProximaClick
        end
      end
    end
    object tsEdicao: TTabSheet
      Caption = 'Cliente'
      ImageIndex = 1
      object lblId: TLabel
        Left = 16
        Top = 16
        Width = 10
        Height = 15
        Caption = 'Id'
      end
      object lblNome: TLabel
        Left = 16
        Top = 64
        Width = 33
        Height = 15
        Caption = 'Nome'
      end
      object lblEmail: TLabel
        Left = 16
        Top = 112
        Width = 34
        Height = 15
        Caption = 'E-mail'
      end
      object lblCpf: TLabel
        Left = 16
        Top = 160
        Width = 21
        Height = 15
        Caption = 'CPF'
      end
      object lblTelefone: TLabel
        Left = 200
        Top = 160
        Width = 44
        Height = 15
        Caption = 'Telefone'
      end
      object lblNascimento: TLabel
        Left = 16
        Top = 208
        Width = 192
        Height = 15
        Caption = 'Nascimento (desmarque = nao informado)'
      end
      object lblLimite: TLabel
        Left = 272
        Top = 208
        Width = 92
        Height = 15
        Caption = 'Limite de credito'
      end
      object lblObservacao: TLabel
        Left = 16
        Top = 288
        Width = 62
        Height = 15
        Caption = 'Observacao'
      end
      object lblAuditoria: TLabel
        Left = 16
        Top = 416
        Width = 3
        Height = 15
        Font.Charset = DEFAULT_CHARSET
        Font.Color = clGrayText
        Font.Height = -12
        Font.Name = 'Segoe UI'
        Font.Style = []
        ParentFont = False
      end
      object edtId: TEdit
        Left = 16
        Top = 34
        Width = 100
        Height = 23
        TabStop = False
        Color = clBtnFace
        ReadOnly = True
        TabOrder = 0
      end
      object edtNome: TEdit
        Left = 16
        Top = 82
        Width = 440
        Height = 23
        MaxLength = 100
        TabOrder = 1
      end
      object edtEmail: TEdit
        Left = 16
        Top = 130
        Width = 440
        Height = 23
        MaxLength = 120
        TabOrder = 2
      end
      object edtCpf: TEdit
        Left = 16
        Top = 178
        Width = 176
        Height = 23
        MaxLength = 14
        TabOrder = 3
      end
      object edtTelefone: TEdit
        Left = 200
        Top = 178
        Width = 256
        Height = 23
        MaxLength = 20
        TabOrder = 4
      end
      object dtpNascimento: TDateTimePicker
        Left = 16
        Top = 226
        Width = 240
        Height = 23
        Date = 45658.000000000000000000
        Time = 0.500000000000000000
        ShowCheckbox = True
        TabOrder = 5
      end
      object edtLimite: TEdit
        Left = 272
        Top = 226
        Width = 184
        Height = 23
        Alignment = taRightJustify
        TabOrder = 6
      end
      object chkAtivo: TCheckBox
        Left = 16
        Top = 260
        Width = 97
        Height = 17
        Caption = 'Ativo'
        Checked = True
        State = cbChecked
        TabOrder = 7
      end
      object memObservacao: TMemo
        Left = 16
        Top = 306
        Width = 440
        Height = 100
        ScrollBars = ssVertical
        TabOrder = 8
      end
      object btnSalvar: TButton
        Left = 16
        Top = 448
        Width = 100
        Height = 30
        Caption = 'Salvar'
        TabOrder = 9
        OnClick = btnSalvarClick
      end
      object btnCancelar: TButton
        Left = 124
        Top = 448
        Width = 100
        Height = 30
        Cancel = True
        Caption = 'Cancelar'
        TabOrder = 10
        OnClick = btnCancelarClick
      end
    end
    object tsSQL: TTabSheet
      Caption = 'Log de SQL'
      ImageIndex = 2
      object pnlLog: TPanel
        Left = 0
        Top = 0
        Width = 992
        Height = 40
        Align = alTop
        BevelOuter = bvNone
        TabOrder = 0
        object btnLimparLog: TButton
          Left = 8
          Top = 6
          Width = 100
          Height = 27
          Caption = 'Limpar log'
          TabOrder = 0
          OnClick = btnLimparLogClick
        end
      end
      object memSQL: TMemo
        Left = 0
        Top = 40
        Width = 992
        Height = 487
        Align = alClient
        Font.Charset = DEFAULT_CHARSET
        Font.Color = clWindowText
        Font.Height = -12
        Font.Name = 'Consolas'
        Font.Style = []
        ParentFont = False
        ReadOnly = True
        ScrollBars = ssBoth
        TabOrder = 1
        WordWrap = False
      end
    end
  end
  object stbStatus: TStatusBar
    Left = 0
    Top = 621
    Width = 1000
    Height = 19
    Panels = <>
    SimplePanel = True
  end
  object dsClientes: TDataSource
    Left = 904
    Top = 160
  end
end
