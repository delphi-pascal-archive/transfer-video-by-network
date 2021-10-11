UNIT UdxSoundCapture;

{******************************************************************************}
{**  ������ �����                                                            **}
{**  �����: ������ ������ �����������                                        **}
{******************************************************************************}

{**} INTERFACE {***************************************************************}

{**} USES {********************************************************************}
  Windows, Classes, SysUtils, MMSystem, DirectSound, Dialogs;

{**} TYPE {********************************************************************}
  TdxSoundCapture = class
  PRIVATE
    FDirectSoundCapture: IDirectSoundCapture8;
    FHandle: THandle;
    
  PUBLIC
    constructor Create(AHandle: THandle);
    destructor Destroy; override;

    function Initialize: HRESULT;

    function StartCapture(WAVFile: string; CaptureTime: DWORD; Channels: WORD = 2;
      SamplesPerSec: DWORD = 11025; BitsPerSample: WORD = 16): HRESULT;
  END;

{**} IMPLEMENTATION {**********************************************************}

{** TdxSoundCapture ***********************************************************}

{******************************************************************************}
{**  ����������� ������                                                      **}
{******************************************************************************}
constructor TdxSoundCapture.Create(AHandle: THandle);
begin
  // ���������� ��������� �� ������� �����
  FHandle := AHandle;

  // �������� ������ �� ������ DirectSoundCapture
  FDirectSoundCapture := NIL;
end;

{******************************************************************************}
{**  ���������� ������                                                       **}
{******************************************************************************}
destructor TdxSoundCapture.Destroy;
begin
  // �������� ������ �� ������ DirectSoundCapture
  FDirectSoundCapture := NIL;
end;

{******************************************************************************}
{**  �������������                                                           **}
{******************************************************************************}
function TdxSoundCapture.Initialize: HRESULT;
begin
  // �������������� ���������� ������� �����
  result := DirectSoundCaptureCreate8(NIL, FDirectSoundCapture, NIL);
end;

{******************************************************************************}
{**  ������ �����                                                            **}
{******************************************************************************}
function TdxSoundCapture.StartCapture(WAVFile: string; CaptureTime: DWORD;
  Channels: WORD; SamplesPerSec: DWORD; BitsPerSample: WORD): HRESULT;
type
  // ���������, ����������� ��������� WAV-�����
  TWAVHeader = packed record
    wav_riff_id:   array[0..3] of char;
    wav_riff_len:  DWORD;

    wav_chuck_id:  array[0..3] of char;
    wav_fmt:       array[0..3] of char;
    wav_chuck_len: DWORD;

    wav_type:      WORD;
    wav_channels:  WORD;
    wav_freq:      DWORD;
    wav_bytes:     DWORD;
    wav_align:     WORD;
    wav_bits:      WORD;
     
    wav_data_id:   array[0..3] of char;
    wav_data_len:  DWORD;
  end;

var
  FCaptureBuffer: IDirectSoundCaptureBuffer;
  FCaptureNotify: IDirectSoundNotify8;
  dsbd:           TDSCBufferDesc;
  wfx:            TWaveFormatEx;
  wh:             TWAVHeader;
  pn:             TDSBPositionNotify;
  AudioPtr:       Pointer;
  AudioBytes:     DWORD;
  Data:           PByte;
  WAVReader:      TFileStream;

begin
  // ��������� ���������, ����������� WAV-������
  ZeroMemory(@wfx, sizeof(wfx));
  wfx.wFormatTag      := WAVE_FORMAT_PCM;
  wfx.nChannels       := Channels;
  wfx.nSamplesPerSec  := SamplesPerSec;
  wfx.wBitsPerSample  := BitsPerSample;
  wfx.nBlockAlign     := wfx.wBitsPerSample div 8 * wfx.nChannels;
  wfx.nAvgBytesPerSec := wfx.nSamplesPerSec * wfx.nBlockAlign;

  // ��������� ���������, ����������� ����� �������
  ZeroMemory(@dsbd, sizeof(dsbd));
  dsbd.dwSize        := sizeof(dsbd);
  dsbd.lpwfxFormat   := @wfx;
  dsbd.dwBufferBytes := dsbd.lpwfxFormat.nAvgBytesPerSec * CaptureTime;

  // ������� ����� �������
  result := FDirectSoundCapture.CreateCaptureBuffer(dsbd, FCaptureBuffer, NIL);
  if FAILED(result) then EXIT;

  // �������� ��������� ����������� ��� ������ �������
  result := FCaptureBuffer.QueryInterface(IID_IDirectSoundNotify8, FCaptureNotify);
  if FAILED(result) then EXIT;

  // ������� ������� ��� �������� ��������� ������
  pn.dwOffset := DSBPN_OFFSETSTOP;
  pn.hEventNotify := CreateEvent(NIL, FALSE, FALSE, NIL);

  // ������������� ������� ����������� (��� ������ ����� ���������� ������
  // �������, ����� ��������� ��������� � ��� �������)
  FCaptureNotify.SetNotificationPositions(1, @pn);
  FCaptureNotify := NIL;

  // �������� ������ �����
  FCaptureBuffer.Start(0);

  // ���������� ��������� �������
  WaitForSingleObject(pn.hEventNotify, INFINITE);

  // ������� �������
  CloseHandle(pn.hEventNotify);

  // ��������� ����� � �������� ��������� �� ��������������� ���� ������
  FCaptureBuffer.Lock(0, 0, @AudioPtr, @AudioBytes, NIL, NIL, DSCBLOCK_ENTIREBUFFER);

  // ��������� ��������� WAV-�����
  wh.wav_align     := wfx.nBlockAlign;
  wh.wav_bits      := wfx.wBitsPerSample;
  wh.wav_bytes     := wfx.nAvgBytesPerSec;
  wh.wav_channels  := wfx.nChannels;
  wh.wav_chuck_id  := 'WAVE';
  wh.wav_chuck_len := 16;
  wh.wav_data_id   := 'data';
  wh.wav_data_len  := AudioBytes;
  wh.wav_fmt       := 'fmt ';
  wh.wav_freq      := wfx.nSamplesPerSec;
  wh.wav_riff_id   := 'RIFF';
  wh.wav_riff_len  := wh.wav_data_len + sizeof(wh);
  wh.wav_type      := wfx.wFormatTag;

  // �������� ������ ��� �����-������
  Data := GetMemory(AudioBytes);
  try
    // �������� ������ �� ������ �������
    CopyMemory(Data, AudioPtr, AudioBytes);
    
    // ������������� ������
    FCaptureBuffer.Unlock(AudioPtr, AudioBytes, NIL, 0);

    // ������� WAV-����
    WAVReader := TFileStream.Create(WAVFile, fmCreate);
    try
      // ���������� � ���� ���������
      WAVReader.WriteBuffer(wh, sizeof(wh));

      // ���������� � ���� �����-������
      WAVReader.WriteBuffer(Data^, AudioBytes);
    finally

      // ��������� ������ � WAV-������
      FreeAndNil(WAVReader);
    end;
  finally
    // �������� ����� �������
    FCaptureBuffer := NIL;

    // ����������� ������, ���������� ��� �����-������
    FreeMemory(Data)
  end;

  result := S_OK;
end;

END.
