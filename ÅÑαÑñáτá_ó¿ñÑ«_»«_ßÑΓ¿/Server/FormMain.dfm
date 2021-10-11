object MainForm: TMainForm
  Left = 256
  Top = 194
  Width = 556
  Height = 510
  Caption = 'Small Media Player'
  Color = clBtnFace
  Constraints.MinHeight = 210
  Constraints.MinWidth = 450
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'MS Sans Serif'
  Font.Style = []
  OldCreateOrder = False
  OnCreate = FormCreate
  OnDestroy = FormDestroy
  OnMouseDown = FormMouseDown
  OnResize = FormResize
  DesignSize = (
    548
    476)
  PixelsPerInch = 96
  TextHeight = 13
  object labelVolume: TLabel
    Left = 19
    Top = 423
    Width = 35
    Height = 13
    Anchors = [akLeft, akBottom]
    Caption = 'Volume'
  end
  object labelBalance: TLabel
    Left = 19
    Top = 447
    Width = 39
    Height = 13
    Anchors = [akLeft, akBottom]
    Caption = 'Balance'
  end
  object panelVideo: TPanel
    Left = 0
    Top = 0
    Width = 548
    Height = 290
    Align = alTop
    Anchors = [akLeft, akTop, akRight, akBottom]
    Color = clGray
    Font.Charset = DEFAULT_CHARSET
    Font.Color = clLime
    Font.Height = -11
    Font.Name = 'MS Sans Serif'
    Font.Style = []
    ParentFont = False
    TabOrder = 7
  end
  object buttonCapture: TButton
    Left = 152
    Top = 417
    Width = 89
    Height = 32
    Anchors = [akLeft, akBottom]
    Caption = #1053#1072#1095'. '#1055#1077#1088#1077#1076#1072#1095#1091
    TabOrder = 1
    OnClick = buttonCaptureClick
  end
  object trackBarProgress: TTrackBar
    Left = 8
    Top = 305
    Width = 535
    Height = 24
    Anchors = [akLeft, akRight, akBottom]
    TabOrder = 6
    TabStop = False
    TickMarks = tmBoth
    TickStyle = tsNone
    OnChange = trackBarProgressChange
  end
  object buttonPlay: TButton
    Left = 152
    Top = 337
    Width = 75
    Height = 40
    Anchors = [akLeft, akBottom]
    Caption = #1055#1088#1086#1080#1075#1088#1072#1090#1100
    TabOrder = 2
    OnClick = buttonPlayClick
  end
  object buttonPause: TButton
    Left = 232
    Top = 337
    Width = 75
    Height = 40
    Anchors = [akLeft, akBottom]
    Caption = #1087#1072#1091#1079#1072
    TabOrder = 3
    OnClick = buttonPauseClick
  end
  object buttonPrev: TButton
    Left = 112
    Top = 385
    Width = 75
    Height = 24
    Anchors = [akLeft, akBottom]
    Caption = 'Step Prev'
    TabOrder = 4
    OnClick = buttonPrevClick
  end
  object buttonNext: TButton
    Left = 192
    Top = 385
    Width = 75
    Height = 24
    Anchors = [akLeft, akBottom]
    Caption = 'Step Next'
    TabOrder = 5
    OnClick = buttonNextClick
  end
  object buttonOpen: TButton
    Left = 16
    Top = 337
    Width = 73
    Height = 32
    Anchors = [akLeft, akBottom]
    Caption = #1054#1090#1082#1088#1099#1090#1100
    Default = True
    TabOrder = 0
    OnClick = buttonOpenClick
  end
  object buttonFast: TButton
    Left = 272
    Top = 385
    Width = 73
    Height = 24
    Anchors = [akLeft, akBottom]
    Caption = 'Faster'
    TabOrder = 8
    OnClick = buttonFastClick
  end
  object buttonSlow: TButton
    Left = 328
    Top = 385
    Width = 73
    Height = 24
    Anchors = [akLeft, akBottom]
    Caption = 'Slower'
    TabOrder = 9
    OnClick = buttonSlowClick
  end
  object trackBarVolume: TTrackBar
    Left = 76
    Top = 417
    Width = 77
    Height = 24
    Anchors = [akLeft, akBottom]
    Max = 0
    Min = -100
    Frequency = 5
    Position = -100
    TabOrder = 10
    TabStop = False
    TickMarks = tmBoth
    TickStyle = tsNone
    OnChange = trackBarVolumeChange
  end
  object buttonStop: TButton
    Left = 312
    Top = 337
    Width = 75
    Height = 40
    Anchors = [akLeft, akBottom]
    Caption = #1057#1090#1086#1087
    TabOrder = 11
    OnClick = buttonStopClick
  end
  object trackBarBalance: TTrackBar
    Left = 76
    Top = 441
    Width = 77
    Height = 24
    Anchors = [akLeft, akBottom]
    Max = 10000
    Min = -10000
    Frequency = 5
    Position = -100
    TabOrder = 12
    TabStop = False
    TickMarks = tmBoth
    TickStyle = tsNone
    OnChange = trackBarBalanceChange
  end
  object Button1: TButton
    Left = 248
    Top = 416
    Width = 121
    Height = 33
    Caption = #1055#1088#1077#1082#1088#1072#1090#1080#1090#1100' '#1087#1077#1088#1077#1076#1072#1095#1091
    TabOrder = 13
    OnClick = Button1Click
  end
  object timerRefresh: TTimer
    OnTimer = timerRefreshTimer
    Left = 16
    Top = 8
  end
  object openDialogVideo: TOpenDialog
    Left = 48
    Top = 8
  end
  object ServerSocket1: TServerSocket
    Active = True
    Port = 1001
    ServerType = stNonBlocking
    OnClientConnect = ServerSocket1ClientConnect
    OnClientDisconnect = ServerSocket1ClientDisconnect
    Left = 464
    Top = 416
  end
  object Timer1: TTimer
    Interval = 50
    OnTimer = Timer1Timer
    Left = 304
    Top = 112
  end
end
