UNIT FormMain;

{******************************************************************************}
{**  ������������ ������ TdsMehdiaPlayer                                     **}
{**  �����: ������ ������ �����������                                        **}
{******************************************************************************}

{**} INTERFACE {***************************************************************}

{**} USES {********************************************************************}
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, StdCtrls, DirectShow9, ComObj, ActiveX, ExtCtrls, ComCtrls,
  UdxMediaPlayer, ScktComp;

{**} CONST {*******************************************************************}
  WM_MEDIA_NOTIFY = WM_USER + 1000;  

{**} TYPE {********************************************************************}
  TMainForm = class(TForm)
    panelVideo: TPanel;
    buttonCapture: TButton;
    trackBarProgress: TTrackBar;
    buttonPlay: TButton;
    buttonPause: TButton;
    buttonPrev: TButton;
    buttonNext: TButton;
    timerRefresh: TTimer;
    buttonOpen: TButton;
    openDialogVideo: TOpenDialog;
    buttonFast: TButton;
    buttonSlow: TButton;
    trackBarVolume: TTrackBar;
    buttonStop: TButton;
    labelVolume: TLabel;
    labelBalance: TLabel;
    trackBarBalance: TTrackBar;
    Button1: TButton;
    ServerSocket1: TServerSocket;
    Timer1: TTimer;
    procedure FormResize(Sender: TObject);
    procedure buttonCaptureClick(Sender: TObject);
    procedure buttonPlayClick(Sender: TObject);
    procedure buttonPauseClick(Sender: TObject);
    procedure buttonNextClick(Sender: TObject);
    procedure buttonPrevClick(Sender: TObject);
    procedure trackBarProgressChange(Sender: TObject);
    procedure timerRefreshTimer(Sender: TObject);
    procedure buttonOpenClick(Sender: TObject);
    procedure FormMouseDown(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure buttonFastClick(Sender: TObject);
    procedure buttonSlowClick(Sender: TObject);
    procedure trackBarVolumeChange(Sender: TObject);
    procedure buttonStopClick(Sender: TObject);
    procedure trackBarBalanceChange(Sender: TObject);
    procedure ServerSocket1ClientConnect(Sender: TObject;
      Socket: TCustomWinSocket);
    procedure Timer1Timer(Sender: TObject);
    procedure Button1Click(Sender: TObject);
    procedure ServerSocket1ClientDisconnect(Sender: TObject;
      Socket: TCustomWinSocket);


  PRIVATE
    FPositioning: boolean;
    procedure MediaNotify(var Msg: Tmessage); message WM_MEDIA_NOTIFY;
  PUBLIC
  END;

{**} VAR {*********************************************************************}
  MainForm: TMainForm;
  MediaPlayer: TdxMediaPlayer;
  Counter: integer = 1;
  conect:BOOLEAN;
{**} IMPLEMENTATION {**********************************************************} 

{$R *.dfm}

{******************************************************************************}
{** ������ ������� ���� ��������������� ����� � ������������ � �����������   **}
{******************************************************************************}
procedure TMainForm.FormResize(Sender: TObject);
begin
  MediaPlayer.SetWindowPosition(Rect(0, 0, panelVideo.ClientRect.Right,
    panelVideo.ClientRect.Bottom));
end;

{******************************************************************************}
{** �������� ���� �� ����������� � ��������� �� �����                        **}
{******************************************************************************}
procedure TMainForm.buttonCaptureClick(Sender: TObject);

begin
Timer1.Enabled:=true;
end;

{******************************************************************************}
{** ��������������� ����������� ������                                       **}
{******************************************************************************}
procedure TMainForm.buttonPlayClick(Sender: TObject);
begin
  MediaPlayer.Play;
end;

{******************************************************************************}
{** ��������� ���������������                                                **}
{******************************************************************************}
procedure TMainForm.buttonStopClick(Sender: TObject);
begin
  MediaPlayer.Stop;
end;

{******************************************************************************}
{** ���������������� ��������������� ������                                  **}
{******************************************************************************}
procedure TMainForm.buttonPauseClick(Sender: TObject);
begin
  MediaPlayer.Pause
end;

{******************************************************************************}
{** ��������� ������                                                         **}
{******************************************************************************}
procedure TMainForm.buttonNextClick(Sender: TObject);
begin
  MediaPlayer.StepNext;
end;

{******************************************************************************}
{** ��������� �����                                                          **}
{******************************************************************************}
procedure TMainForm.buttonPrevClick(Sender: TObject);
begin
  MediaPlayer.StepPrev;
end;

{******************************************************************************}
{** ��������� ����� ������� ���������������                                  **}
{******************************************************************************}
procedure TMainForm.trackBarProgressChange(Sender: TObject);
begin
  if FPositioning then EXIT;

  FPositioning := TRUE;
  try
    MediaPlayer.SetPlayingPosition(trackBarProgress.Position * 100);
  finally
    FPositioning := FALSE;
  end;
end;

{******************************************************************************}
{** ���������� ������� ������� ���������������                               **}
{******************************************************************************}
procedure TMainForm.timerRefreshTimer(Sender: TObject);
var
  P: int64;
begin
  if FPositioning then EXIT;

  FPositioning := TRUE;
  try
    if SUCCEEDED(MediaPlayer.GetPlayingPosition(P)) then
       trackBarProgress.Position := P div 100;
  finally
    FPositioning := FALSE;
  end;
end;

{******************************************************************************}
{** �������� ������ ����������� �����                                        **}
{******************************************************************************}
procedure TMainForm.buttonOpenClick(Sender: TObject);
var
  Volume: longint;
begin
  if openDialogVideo.Execute then
  begin
    if SUCCEEDED(MediaPlayer.Initialize(WideString(openDialogVideo.FileName))) then
    begin
      Caption := 'Small Media Player: ' + openDialogVideo.FileName;

      trackBarProgress.Max := MediaPlayer.FrameCount div 100;

      MediaPlayer.RegisterEventMessage(Handle, WM_MEDIA_NOTIFY);
      
      MediaPlayer.SetWindowPosition(Rect(0, 0, panelVideo.ClientRect.Right,
        panelVideo.ClientRect.Bottom));
        
      if SUCCEEDED(MediaPlayer.GetVolume(Volume)) then
        trackBarVolume.Position := 10 - Volume div 100;
    end;
  end;
end;

{******************************************************************************}
{** ������������� ����� ������                                               **}
{******************************************************************************}
procedure TMainForm.FormMouseDown(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
begin
  ReleaseCapture;
  SendMessage(Handle, WM_NCLBUTTONDOWN, HTCAPTION, 0);
end;

{******************************************************************************}
{** �������� � ������������� ������� MediaPlayer                             **}
{******************************************************************************}
procedure TMainForm.FormCreate(Sender: TObject);
begin
  Timer1.Enabled:=false;
  serversocket1.Open;
  MediaPlayer := TdxMediaPlayer.Create(panelVideo.Handle);
end;

{******************************************************************************}
{** �������� ������� MediaPlayer                                             **}
{******************************************************************************}
procedure TMainForm.FormDestroy(Sender: TObject);
begin
  FreeAndNil(MediaPlayer);
end;

{******************************************************************************}
{** �������� ���������������                                                 **}
{******************************************************************************}
procedure TMainForm.buttonFastClick(Sender: TObject);
begin
  MediaPlayer.Faster;
end;

{******************************************************************************}
{** ��������� ���������������                                                **}
{******************************************************************************}
procedure TMainForm.buttonSlowClick(Sender: TObject);
begin
  MediaPlayer.Slower;
end;

{******************************************************************************}
{** �������� ��������� ��������                                              **}
{******************************************************************************}
procedure TMainForm.trackBarVolumeChange(Sender: TObject);
begin
  MediaPlayer.SetVolume(trackBarVolume.Position * 100);
end;

{******************************************************************************}
{** ������������ ��������� �� ������� MediaPlayer                            **}
{******************************************************************************}
procedure TMainForm.MediaNotify(var Msg: Tmessage);
var
  EventCode: Integer;
  Param1, Param2: Integer;
begin
  while MediaPlayer.GetEvent(EventCode, Param1, Param2, 0) = S_OK do
  begin
    if EventCode = EC_Complete then
    begin
      MediaPlayer.Stop;
      MediaPlayer.SetPlayingPosition(0);
    end;
  end;
end;

{******************************************************************************}
{** �������� ������                                                          **}
{******************************************************************************}
procedure TMainForm.trackBarBalanceChange(Sender: TObject);
begin
  MediaPlayer.SetBalance(trackBarBalance.Position);
end;

procedure TMainForm.ServerSocket1ClientConnect(Sender: TObject;
  Socket: TCustomWinSocket);
begin
MainForm.Caption:='Connected';
Conect:=true;
end;

procedure TMainForm.Timer1Timer(Sender: TObject);
var
mS:Tmemorystream;
Size: integer;
P: ^Byte;
begin

 IF CONECT=TRUE THEN
 BEGIN
 MS := TMemoryStream.Create; // ������ ����� ��� �����

 MediaPlayer.CaptureBitmap(mS);

 ServerSocket1.Socket.Connections[0].SendText('file#'+'ok'+'#'+IntToStr(MS.Size)+'#');
MS.Position := 0; // ��������� ������� � ������ �����
P := MS.Memory; // ��������� � ���������� "P" ����
Size := ServerSocket1.Socket.Connections[0].SendBuf(P^, MS.Size); // �������� ����

end;




end;

procedure TMainForm.Button1Click(Sender: TObject);
begin
Timer1.Enabled:=false;
end;

procedure TMainForm.ServerSocket1ClientDisconnect(Sender: TObject;
  Socket: TCustomWinSocket);
begin
conect:=false;
end;

END.
