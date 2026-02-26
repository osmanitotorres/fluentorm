object Form1: TForm1
  Left = 0
  Top = 0
  Caption = 'Sample 01'
  ClientHeight = 484
  ClientWidth = 783
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'Tahoma'
  Font.Style = []
  OldCreateOrder = False
  PixelsPerInch = 96
  TextHeight = 13
  object Memo1: TMemo
    Left = 0
    Top = 96
    Width = 783
    Height = 388
    Align = alBottom
    Anchors = [akLeft, akTop, akRight, akBottom]
    ScrollBars = ssVertical
    TabOrder = 0
  end
  object BitBtn1: TBitBtn
    Left = 16
    Top = 16
    Width = 105
    Height = 25
    Caption = 'Simple Select'
    TabOrder = 1
    OnClick = BitBtn1Click
  end
  object BitBtn2: TBitBtn
    Left = 127
    Top = 16
    Width = 98
    Height = 25
    Caption = 'Inner Join'
    TabOrder = 2
    OnClick = BitBtn2Click
  end
  object BitBtn3: TBitBtn
    Left = 231
    Top = 16
    Width = 98
    Height = 25
    Caption = 'In not'
    TabOrder = 3
    OnClick = BitBtn3Click
  end
  object BitBtn4: TBitBtn
    Left = 344
    Top = 16
    Width = 105
    Height = 25
    Caption = 'ORM Insert'
    TabOrder = 4
    OnClick = BitBtn4Click
  end
  object BitBtn5: TBitBtn
    Left = 455
    Top = 16
    Width = 90
    Height = 25
    Caption = 'ORM Insert 2'
    TabOrder = 5
    OnClick = BitBtn5Click
  end
  object BitBtn6: TBitBtn
    Left = 552
    Top = 16
    Width = 97
    Height = 25
    Caption = 'ORM Delete'
    TabOrder = 6
    OnClick = BitBtn6Click
  end
  object BitBtn7: TBitBtn
    Left = 656
    Top = 16
    Width = 75
    Height = 25
    Caption = 'Count'
    TabOrder = 7
    OnClick = BitBtn7Click
  end
  object BitBtn8: TBitBtn
    Left = 16
    Top = 64
    Width = 105
    Height = 25
    Caption = 'RTTI Type'
    TabOrder = 8
    OnClick = BitBtn8Click
  end
end
