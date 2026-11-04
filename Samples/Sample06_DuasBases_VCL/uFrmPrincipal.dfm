object frmPrincipal: TfrmPrincipal
  Left = 0
  Top = 0
  Caption = 'FluentORM - Duas bases ao mesmo tempo (MySQL / PostgreSQL)'
  ClientHeight = 720
  ClientWidth = 1340
  Color = clBtnFace
  Constraints.MinHeight = 560
  Constraints.MinWidth = 900
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = 'Segoe UI'
  Font.Style = []
  Position = poScreenCenter
  WindowState = wsMaximized
  OnCreate = FormCreate
  OnDestroy = FormDestroy
  OnResize = FormResize
  TextHeight = 15
  object pnlTopo: TPanel
    Left = 0
    Top = 0
    Width = 1340
    Height = 34
    Align = alTop
    BevelOuter = bvNone
    TabOrder = 0
    object lblInfo: TLabel
      Left = 8
      Top = 9
      Width = 700
      Height = 15
      Caption = 
        'Cada lado e uma conexao independente. Escolha MySQL ou PostgreSQL ' +
        'em cada base, conecte as duas e use os botoes do meio para copiar ' +
        'clientes entre elas.'
    end
  end
  object pnlA: TPanel
    Left = 0
    Top = 34
    Width = 600
    Height = 494
    Align = alLeft
    BevelOuter = bvNone
    TabOrder = 1
  end
  object pnlMeio: TPanel
    Left = 600
    Top = 34
    Width = 140
    Height = 494
    Align = alLeft
    BevelOuter = bvNone
    TabOrder = 2
    object btnCopiarAB: TButton
      Left = 10
      Top = 150
      Width = 120
      Height = 30
      Hint = 'Copia o cliente selecionado na Base A para a Base B'
      Caption = 'Copiar A >> B'
      ParentShowHint = False
      ShowHint = True
      TabOrder = 0
      OnClick = btnCopiarABClick
    end
    object btnCopiarBA: TButton
      Left = 10
      Top = 186
      Width = 120
      Height = 30
      Hint = 'Copia o cliente selecionado na Base B para a Base A'
      Caption = 'Copiar A << B'
      ParentShowHint = False
      ShowHint = True
      TabOrder = 1
      OnClick = btnCopiarBAClick
    end
    object btnCopiarTodosAB: TButton
      Left = 10
      Top = 240
      Width = 120
      Height = 30
      Hint = 'Copia todos os clientes da Base A para a Base B (uma transacao)'
      Caption = 'Todos A >> B'
      ParentShowHint = False
      ShowHint = True
      TabOrder = 2
      OnClick = btnCopiarTodosABClick
    end
    object btnCopiarTodosBA: TButton
      Left = 10
      Top = 276
      Width = 120
      Height = 30
      Hint = 'Copia todos os clientes da Base B para a Base A (uma transacao)'
      Caption = 'Todos A << B'
      ParentShowHint = False
      ShowHint = True
      TabOrder = 3
      OnClick = btnCopiarTodosBAClick
    end
    object btnComparar: TButton
      Left = 10
      Top = 330
      Width = 120
      Height = 30
      Hint = 'Conta os clientes nas duas bases'
      Caption = 'Comparar'
      ParentShowHint = False
      ShowHint = True
      TabOrder = 4
      OnClick = btnCompararClick
    end
    object btnLimparLog: TButton
      Left = 10
      Top = 384
      Width = 120
      Height = 30
      Caption = 'Limpar log'
      TabOrder = 5
      OnClick = btnLimparLogClick
    end
  end
  object pnlB: TPanel
    Left = 740
    Top = 34
    Width = 600
    Height = 494
    Align = alClient
    BevelOuter = bvNone
    TabOrder = 3
  end
  object splLog: TSplitter
    Left = 0
    Top = 528
    Width = 1340
    Height = 5
    Cursor = crVSplit
    Align = alBottom
  end
  object memLog: TMemo
    Left = 0
    Top = 533
    Width = 1340
    Height = 168
    Align = alBottom
    Font.Charset = DEFAULT_CHARSET
    Font.Color = clWindowText
    Font.Height = -12
    Font.Name = 'Consolas'
    Font.Style = []
    ParentFont = False
    ReadOnly = True
    ScrollBars = ssBoth
    TabOrder = 4
    WordWrap = False
  end
  object stbStatus: TStatusBar
    Left = 0
    Top = 701
    Width = 1340
    Height = 19
    Panels = <>
    SimplePanel = True
  end
end
