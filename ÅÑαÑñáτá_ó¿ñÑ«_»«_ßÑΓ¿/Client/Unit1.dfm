object Form1: TForm1
  Left = 146
  Top = 183
  Width = 324
  Height = 344
  Caption = 'Form1'
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'MS Sans Serif'
  Font.Style = []
  OldCreateOrder = False
  OnCreate = FormCreate
  OnDestroy = FormDestroy
  PixelsPerInch = 96
  TextHeight = 13
  object Label1: TLabel
    Left = 16
    Top = 16
    Width = 74
    Height = 13
    Caption = #1056#1072#1079#1084#1077#1088' '#1092#1072#1081#1083#1072
  end
  object Label2: TLabel
    Left = 16
    Top = 32
    Width = 57
    Height = 13
    Caption = #1048#1084#1103' '#1092#1072#1081#1083#1072
  end
  object Image1: TImage
    Left = 24
    Top = 104
    Width = 233
    Height = 177
    AutoSize = True
  end
  object ProgressBar1: TProgressBar
    Left = 16
    Top = 56
    Width = 150
    Height = 17
    TabOrder = 0
  end
  object StatusBar1: TStatusBar
    Left = 0
    Top = 291
    Width = 316
    Height = 19
    Panels = <>
    SimplePanel = True
  end
  object ClientSocket1: TClientSocket
    Active = True
    Address = '127.0.0.1'
    ClientType = ctNonBlocking
    Port = 1001
    OnConnect = ClientSocket1Connect
    OnDisconnect = ClientSocket1Disconnect
    OnRead = ClientSocket1Read
    Left = 168
    Top = 8
  end
end
