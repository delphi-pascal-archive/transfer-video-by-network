UNIT UdxMediaPlayer;

{******************************************************************************}
{** ��������������� ����������� ������� ����������� DirectShow               **}
{** �����: ������ ������ �����������                                         **}
{******************************************************************************}

{**} INTERFACE {***************************************************************}

{**} USES {********************************************************************}
  Windows, SysUtils, Graphics, ComObj, ActiveX, DirectShow9, Dialogs,
    Messages, Variants, Classes,  Controls, Forms,
 StdCtrls,  ExtCtrls, ComCtrls, ScktComp;
{**} TYPE {********************************************************************}
  TdxMediaPlayer = class
  PRIVATE
    FGraphBuilder:  IGraphBuilder;
    FMediaControl:  IMediaControl;
    FVideoWindow:   IVideoWindow;
    FBaseFilter:    IBaseFilter;
    FSampleGrabber: ISampleGrabber;
    FMediaSeeking:  IMediaSeeking;
    FBasicAudio:    IBasicAudio;
    FMediaEvent:    IMediaEventEx;

    FFileName:      WideString;
    FPlaying:       boolean;
    FHandle:        THandle;
    FFrameCount:    int64;

    FIsTimeFormat:  boolean;

    function CreateGraph: HResult;
    procedure ResetGraph;

  PUBLIC
    property FrameCount: int64 read FFrameCount;

    constructor Create(AHandle: THandle);
    destructor Destroy; override;

    function Initialize(AFileName: WideString): HResult;

    function  Play: HResult;
    procedure Stop;
    procedure Pause;

    function  StepPrev: HResult;
    function  StepNext: HResult;

    function  Faster: HResult;
    function  Slower: HResult;

    function GetVolume(out Value: Longint): HResult;
    function SetVolume(Value: Longint): HResult;

    function GetBalance(out Value: Longint): HResult;
    function SetBalance(Value: Longint): HResult;

    function SetWindowPosition(const R: TRect): HResult;
    
    function GetPlayingPosition(out P: int64): HResult;
    function SetPlayingPosition(P: int64): HResult;

    function CaptureBitmap(out ms:Tmemorystream): HResult;

    function RegisterEventMessage(AHandle: THandle; Msg: Cardinal): HResult;
    function GetEvent(out lEventCode: Longint; out lParam1, lParam2: Longint;
        msTimeout: DWORD): HResult;
  END;

{**} IMPLEMENTATION {**********************************************************}

{**} CONST {*******************************************************************}
  strVideoLoaded    = '!!! ����� ��������� !!!';
  strVideoNotLoaded = '!!! ����� �� ��������� !!!';

  frameDuration     = 500000;

{**} { TdxMediaPlayer } {*****************************************************}

{******************************************************************************}
{** ����������� ������                                                       **}
{******************************************************************************}
constructor TdxMediaPlayer.Create(AHandle: THandle);
begin
  // ���������� ��������� �� ���� ������ �����
  FHandle := AHandle;

  // ������� ����
  ResetGraph;
end;

{******************************************************************************}
{** ���������� ������                                                        **}
{******************************************************************************}
destructor TdxMediaPlayer.Destroy;
begin
  // ������� ����
  ResetGraph;
end;

{******************************************************************************}
{** �������������                                                            **}
{******************************************************************************}
function TdxMediaPlayer.Initialize(AFileName: WideString): HResult;
begin
  // ������� ����
  ResetGraph;

  // ���������� ���� � �����
  FFileName := AFileName;

  // ������ ����
  CreateGraph;          

  Result := S_OK;
end;

{******************************************************************************}
{** ���������� �����                                                         **}
{******************************************************************************}
function TdxMediaPlayer.CreateGraph: HResult;
var
  MediaType: TAMMediaType;
begin
  // ��������� �� ���������
  Result := E_FAIL;

  // ���� �� ����� ���� � �����, �� ��������� ������
  if Trim(FFileName) = '' then EXIT;

  // ������� ������ ��� ���������� ����� ��������
  Result := CoCreateInstance(CLSID_FilterGraph, NIL, CLSCTX_INPROC_SERVER,
    IID_IGraphBuilder, FGraphBuilder);
  if FAILED(Result) then EXIT;

  // ������� ������
  Result := CoCreateInstance(CLSID_SampleGrabber, NIL, CLSCTX_INPROC_SERVER,
    IID_IBaseFilter, FBaseFilter);
  if FAILED(Result) then EXIT;

  // �������� ��������� ������� ���������
  FBaseFilter.QueryInterface(IID_ISampleGrabber, FSampleGrabber);

  // ��������� ������ � ����
  Result := FGraphBuilder.AddFilter(FBaseFilter, 'GRABBER');
  if FAILED(Result) then EXIT;

  if FSampleGrabber <> NIL then
  begin
    // ������������� ������ ������ ��� ������� ���������
    ZeroMemory(@MediaType, sizeof(TAMMediaType));

    with MediaType do
    begin
      majortype  := MEDIATYPE_Video;
      subtype    := MEDIASUBTYPE_RGB24;
      formattype := FORMAT_VideoInfo;
    end;

    Result := FSampleGrabber.SetMediaType(MediaType);
    if FAILED(Result) then EXIT;

    // ������ ����� �������� � ����� � ��� ����, � ������� ���
    // �������� ����� ������
    FSampleGrabber.SetBufferSamples(TRUE);

    // ���� �� ����� ���������� ��� ��������� �����
    FSampleGrabber.SetOneShot(FALSE);
  end;

  // ����������� ��������� ���������� ������ ��������
  FGraphBuilder.QueryInterface(IID_IMediaControl, FMediaControl);

  // ����������� ��������� ���������� ����� ������ �����
  FGraphBuilder.QueryInterface(IID_IVideoWindow,  FVideoWindow);

  // ����������� ��������� ���������� ����������������� ����� ������
  FGraphBuilder.QueryInterface(IID_IMediaSeeking, FMediaSeeking);

  // ����������� ��������� ���������� �������� �������
  FGraphBuilder.QueryInterface(IID_IBasicAudio,   FBasicAudio);

  // ������ ���� �������� ��� ������ �����
  Result := FGraphBuilder.RenderFile(PWideChar(FFileName), nil);
  if FAILED(Result) then EXIT;

  // �������� �������������� ��������
  if (FMediaSeeking.IsFormatSupported(TIME_FORMAT_FRAME) = S_OK) then
  begin
    // ������������� ���������� ������
    FMediaSeeking.SetTimeFormat(TIME_FORMAT_FRAME);

    // �������� ����� ������
    FMediaSeeking.GetDuration(FFrameCount);

    // ������� ��������� �� ���� � �����
    SetWindowText(FHandle, PAnsiChar(strVideoLoaded));
    // ��������� ���� �����
    InvalidateRect(FHandle, NIL, FALSE);

    // ������������� ������������ ���� ��� ������ �����������
    FVideoWindow.put_Owner(FHandle);
    // ������������� ����� ����� ����
    FVideoWindow.put_WindowStyle(WS_CHILD or WS_CLIPSIBLINGS);

    FIsTimeFormat := FALSE;
  end else if (FMediaSeeking.IsFormatSupported(TIME_FORMAT_MEDIA_TIME) = S_OK) then
  begin
    // ������������� ��������� ��������� ������ (100 ��)
    FMediaSeeking.SetTimeFormat(TIME_FORMAT_MEDIA_TIME);

    // �������� ����� ����������
    FMediaSeeking.GetDuration(FFrameCount);
    // ��������� �� ���������� ��� ����� ������� ������
    FFrameCount := FFrameCount div frameDuration;

    FIsTimeFormat := TRUE;
  end;
end;

{******************************************************************************}
{** ������ ����� - ����������� ������ � �������� ��������                    **}
{******************************************************************************}
procedure TdxMediaPlayer.ResetGraph;
begin
  FBasicAudio    := NIL;
  FMediaEvent    := NIL;

  FPlaying       := FALSE;
  FFileName      := '';

  FMediaSeeking  := NIL;
  FSampleGrabber := NIL;
  FBaseFilter    := NIL;

  if FVideoWindow <> NIL then
  begin
    FVideoWindow.put_Visible(FALSE);
    FVideoWindow.put_Owner(0);
    FVideoWindow := NIL;
  end;

  FMediaControl  := NIL;
  FGraphBuilder  := NIL;

  SetWindowText(FHandle, PAnsiChar(strVideoNotLoaded));
  InvalidateRect(FHandle, NIL, FALSE);
end;

{******************************************************************************}
{** ������ ����� �� ���������������                                          **}
{******************************************************************************}
function TdxMediaPlayer.Play: HResult;
begin
  // ��������� �� ���������
  Result := E_FAIL;

  // ����  ����������� ��������� ����������, �� ��������� ������
  if FMediaControl = NIL then EXIT;

  // ��������� ����
  Result := FMediaControl.Run;
  
  FPlaying := SUCCEEDED(Result);
end;

{******************************************************************************}
{** ��������� ��������������� � ��������� ������� �� ������                  **}
{******************************************************************************}
procedure TdxMediaPlayer.Stop;
begin
  // �������� ������� ���������� ���������� � ��������� �����
  if (FMediaControl = NIL) or not (FPlaying) then EXIT;

  // ������������� ����
  FMediaControl.Stop;

  // ������������� ������� �� ������
  SetPlayingPosition(0);

  FPlaying := FALSE;
end;

{******************************************************************************}
{** ���������������� ��������������� ������                                  **}
{******************************************************************************}
procedure TdxMediaPlayer.Pause;
begin
  // ����  ����������� ��������� ����������, �� ��������� ������
  if FMediaControl = NIL then EXIT;

  // ��������� ���� � ��������� "�����"
  FMediaControl.Pause;
  
  FPlaying := FALSE;
end;

{******************************************************************************}
{** ��� �����                                                                **}
{******************************************************************************}
function TdxMediaPlayer.StepPrev: HResult;
var
  P, S: int64;
begin
  // ��������� �� ���������
  Result := E_FAIL;

  // ����  ����������� ��������� ����������������, �� ��������� ������
  if FMediaSeeking = NIL then EXIT;

  // ������������� ������� �� ��� �����
  FMediaSeeking.GetPositions(P, S);
  dec(P);
  FMediaSeeking.SetPositions(P, AM_SEEKING_AbsolutePositioning, S, AM_SEEKING_NoPositioning);
end;

{******************************************************************************}
{** ��� ������                                                               **}
{******************************************************************************}
function TdxMediaPlayer.StepNext: HResult;
var
  P, S: int64;
begin
  // ��������� �� ���������
  Result := E_FAIL;

  // ����  ����������� ��������� ����������������, �� ��������� ������
  if FMediaSeeking = NIL then EXIT;

  // ������������� ������� �� ��� ������
  FMediaSeeking.GetPositions(P, S);
  inc(P);
  FMediaSeeking.SetPositions(P, AM_SEEKING_AbsolutePositioning, S, AM_SEEKING_NoPositioning);
end;

{******************************************************************************}
{** ����������� �������� ���������������                                     **}
{******************************************************************************}
function TdxMediaPlayer.Faster: HResult;
var
  Rate: double;
begin
  // ��������� �� ���������
  Result := E_FAIL;

  // ����  ����������� ��������� ����������������, �� ��������� ������
  if FMediaSeeking = NIL then EXIT;

  // �������� ������� �������� ��������������� ...
  if SUCCEEDED(FMediaSeeking.GetRate(Rate)) then
  begin
    // ... � ����������� �� � ��� ����
    Result := FMediaSeeking.SetRate(Rate * 2);
  end;
end;

{******************************************************************************}
{** ��������� �������� ���������������                                       **}
{******************************************************************************}
function TdxMediaPlayer.Slower: HResult;
var
  Rate: double;
begin
  // ��������� �� ���������
  Result := E_FAIL;

  // ����  ����������� ��������� ����������������, �� ��������� ������
  if FMediaSeeking = NIL then EXIT;

  // �������� ������� �������� ��������������� ...
  if SUCCEEDED(FMediaSeeking.GetRate(Rate)) then
  begin
    // ... � ��������� �� � ��� ����
    Result := FMediaSeeking.SetRate(Rate / 2);
  end;
end; 

{******************************************************************************}
{** �������� ���������                                                       **}
{******************************************************************************}
function TdxMediaPlayer.GetVolume(out Value: Integer): HResult;
begin
  // ��������� �� ���������
  Result := E_FAIL;

  // ����  ����������� ��������� ���������� ������, �� ��������� ������
  if FBasicAudio = NIL then EXIT;

  // �������� ���������
  Result := FBasicAudio.get_Volume(Value);
end;

{******************************************************************************}
{** ������������� ���������                                                  **}
{******************************************************************************}
function TdxMediaPlayer.SetVolume(Value: Integer): HResult;
begin
  // ��������� �� ���������
  Result := E_FAIL;

  // ����  ����������� ��������� ���������� ������, �� ��������� ������
  if FBasicAudio = NIL then EXIT;

  // ������������� ���������
  Result := FBasicAudio.put_Volume(Value);
end;

{******************************************************************************}
{** �������� ������� ������� �����                                           **}
{******************************************************************************}
function TdxMediaPlayer.GetBalance(out Value: Integer): HResult;
begin
  // ��������� �� ���������
  Result := E_FAIL;

  // ����  ����������� ��������� ���������� ������, �� ��������� ������
  if FBasicAudio = NIL then EXIT;

  // �������� ������� ������� �����
  Result := FBasicAudio.get_Balance(Value);
end;

{******************************************************************************}
{** ������������� ������� ������� �����                                      **}
{******************************************************************************}
function TdxMediaPlayer.SetBalance(Value: Integer): HResult;
begin
  // ��������� �� ���������
  Result := E_FAIL;

  // ����  ����������� ��������� ���������� ������, �� ��������� ������
  if FBasicAudio = NIL then EXIT;

  // ������������� ������� ������� �����
  Result := FBasicAudio.put_Balance(Value);
end;

{******************************************************************************}
{** ������ ������� ���� ��������������� �����                                **}
{******************************************************************************}
function TdxMediaPlayer.SetWindowPosition(const R: TRect): HResult;
begin
  // ��������� �� ���������
  Result := E_FAIL;

  // ���� ����������� ��������� ���������� ����� �����, �� ��������� ������
  if (FVideoWindow = NIL) or (FIsTimeFormat) then EXIT;

  // ������ ������� ���� ��������������� �����
  Result := FVideoWindow.SetWindowPosition(R.Left, R.Top,
    R.Right - R.Left, R.Bottom - R.Top);
end;

{******************************************************************************}
{** �������� ������� ������� ���������������                                 **}
{******************************************************************************}
function TdxMediaPlayer.GetPlayingPosition(out P: int64): HResult;
begin
  // ��������� �� ���������
  Result := E_FAIL;

  // ����  ����������� ��������� ����������������, �� ��������� ������
  if FMediaSeeking = NIL then EXIT;

  // �������� ������� ������� ���������������
  Result := FMediaSeeking.GetCurrentPosition(P);

  // ���������� ��������� ������
  if FIsTimeFormat then P := P div frameDuration;
end;

{******************************************************************************}
{** ������������� ������� ���������������                                    **}
{******************************************************************************}
function TdxMediaPlayer.SetPlayingPosition(P: int64): HResult;
var
  PS, S: int64;
begin
  // ��������� �� ���������
  Result := E_FAIL;

  // ����  ����������� ��������� ����������������, �� ��������� ������
  if FMediaSeeking = NIL then EXIT;

  // �������� ������� ������� ���������������
  FMediaSeeking.GetPositions(PS, S);

  // ���������� ��������� ������
  if FIsTimeFormat then P := P * frameDuration;

  // ������������� ������� ���������������
  Result := FMediaSeeking.SetPositions(P, AM_SEEKING_AbsolutePositioning, S, AM_SEEKING_NoPositioning);
end;

{******************************************************************************}
{** �������� ���� �� ����������� � ��������� �� �����                        **}
{******************************************************************************}
function TdxMediaPlayer.CaptureBitmap(out ms:Tmemorystream): HResult;
var
  bSize: integer;
  pVideoHeader: TVideoInfoHeader;
  MediaType: TAMMediaType;
  BitmapInfo: TBitmapInfo;
  Bitmap: TBitmap;
  Buffer: Pointer;
  tmp: array of byte;

begin
  // ��������� �� ���������
  Result := E_FAIL;

  // ����  ����������� ��������� ������� ��������� �����������,
  // �� ��������� ������
  if FSampleGrabber = NIL then EXIT;

  // �������� ������ �����
  Result := FSampleGrabber.GetCurrentBuffer(bSize, NIL);
  if (bSize <= 0) or FAILED(Result) then EXIT;

  // ������� �����������
  bitmap := TBitmap.Create;
  try
    // �������� ��� ����� ������ �� ����� � ������� ���������
    ZeroMemory(@MediaType, sizeof(TAMMediaType));
    Result := FSampleGrabber.GetConnectedMediaType(MediaType);
    if FAILED(Result) then EXIT;

    // �������� ��������� �����������
    pVideoHeader := TVideoInfoHeader(MediaType.pbFormat^);
    ZeroMemory(@BitmapInfo, sizeof(TBitmapInfo));
    CopyMemory(@BitmapInfo.bmiHeader, @pVideoHeader.bmiHeader, sizeof(TBITMAPINFOHEADER));
    
    Buffer := NIL;

    // ������� ��������� �����������
    bitmap.Handle := CreateDIBSection(0, BitmapInfo, DIB_RGB_COLORS, Buffer, 0, 0);

    // �������� ������ �� ��������� �������
    SetLength(tmp, bSize);

    try
      // ������ ����������� �� ����� ������ �� ��������� �����
      FSampleGrabber.GetCurrentBuffer(bSize, @tmp[0]);
      
      // �������� ������ �� ���������� ������ � ���� �����������
      CopyMemory(Buffer, @tmp[0], MediaType.lSampleSize);

      MS := TMemoryStream.Create; // ������ ����� ��� �����

      // ��������� ����������� � ����
      Bitmap.SaveToStream(ms);
       ms.SaveToFile('c:\111.bmp');

    except

      // � ������ ���� ���������� ��������� ���������
      Result := E_FAIL;
    end;
  finally
  
    // ����������� ������
    SetLength(tmp, 0);
    FreeAndNil(Bitmap);
  end;
end;

{******************************************************************************}
{** ����������� ���� ��� ��������� ���������                                 **}
{******************************************************************************}
function TdxMediaPlayer.RegisterEventMessage(AHandle: THandle;
  Msg: Cardinal): HResult;
begin
  // ��������� ���������� ���������� �����������
  Result := FGraphBuilder.QueryInterface(IID_IMediaEventEx, FMediaEvent);

  // ��������� ���� ��������� ���������
  if SUCCEEDED(Result) then
    Result := FMediaEvent.SetNotifyWindow(AHandle, Msg, 0);
end;

{******************************************************************************}
{** ����������� ���� ��� ��������� ���������                                 **}
{******************************************************************************}
function TdxMediaPlayer.GetEvent(out lEventCode, lParam1,
  lParam2: Integer; msTimeout: DWORD): HResult;
begin
  // ��������� �� ���������
  Result := E_FAIL;
  
  // ���� ����������� ��������� ���������� �����������, �� ��������� ������
  if FMediaEvent = NIL then EXIT;

  // ��������� ��������� �� �������
  if SUCCEEDED(FMediaEvent.GetEvent(lEventCode, lParam1, lParam2, msTimeout)) then
  begin
    // ����������� �������, ��������� � ��������
    Result := FMediaEvent.FreeEventParams(lEventCode, lParam1, lParam2);
  end;
end;

END.
