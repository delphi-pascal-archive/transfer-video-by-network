UNIT UdxMusicManager;

{******************************************************************************}
{**  ������ � ������� ������� MIDI � WAV ����������� DirectMusic             **}
{**  �����: ������ ������ �����������                                        **}
{******************************************************************************}

{**} INTERFACE {***************************************************************}

{**} USES {********************************************************************}
  Windows, Classes, SysUtils, MMSystem, DirectMusic, ComObj, ActiveX;

{**} TYPE {********************************************************************}
  TdxMusicSegment = class;

  TdxMusicManager = class
  PRIVATE
    FPerformance: IDirectMusicPerformance8;
    FLoader: IDirectMusicLoader8;

    FSegmentList: TList;

    FHandle: THandle; 

  PUBLIC
    constructor Create(Handle: THandle);
    destructor Destroy; override;

    function Initialize: HResult;

    function CreateSegment(FileName: WideString): TdxMusicSegment;
    function DeleteSegment(Index: integer): HResult; overload;
    function DeleteSegment(Segment: TdxMusicSegment): HResult; overload;
    function GetSegment(Index: integer): TdxMusicSegment;
    function SegmentCount: integer;
  END;

  TdxMusicSegment = class
  PRIVATE
    FPerformance: IDirectMusicPerformance8;
    FLoader: IDirectMusicLoader8;
    FSegment: IDirectMusicSegment8;

  PUBLIC
    constructor Create(APerformance: IDirectMusicPerformance8;
      ALoader: IDirectMusicLoader8; ASegment: IDirectMusicSegment8);
    destructor Destroy; override;

    function SetRepeats(dwRepeats: DWORD = DMUS_SEG_REPEAT_INFINITE): HResult;

    function Play(IsPrimary: boolean = FALSE): HResult;
    function Stop: HResult;

    function IsPlaying: boolean;
  END;

{**} IMPLEMENTATION {**********************************************************}

{**} { TdxMusicManager } {*****************************************************}

{******************************************************************************}
{**  ����������� ������                                                      **}
{******************************************************************************}
constructor TdxMusicManager.Create(Handle: THandle);
begin
  // ������������� ���������� COM
  CoInitializeEx(NIL, COINIT_MULTITHREADED);

  // ��������� ������ �� �������� ��������������� � ���������
  FPerformance := NIL;
  FLoader := NIL;

  // ���������� ��������� �� ������� �����
  FHandle := Handle;

  // ������� ��������� ��������� ���������������
  FSegmentList := TList.Create;
end;

{******************************************************************************}
{**  ������� ������� ���������������                                         **}
{******************************************************************************}
function TdxMusicManager.CreateSegment(FileName: WideString): TdxMusicSegment;
var
  FSegment: IDirectMusicSegment8;
begin
  // �������� ������ �� �������
  FSegment := NIL;

  // ��������� �� ���������
  Result := NIL;
  
  // �������� ������� ��������� ��������������� � ����������
  if (FPerformance = NIL) or (FLoader = NIL) then EXIT;

  // ��������� ����� ������ � �������� ��������� �� �������
  if FAILED(FLoader.LoadObjectFromFile(CLSID_DirectMusicSegment,
    IID_IDirectMusicSegment8, PWideChar(FileName),
    FSegment)) then EXIT;

  // ��������� ������ � ��������
  if FAILED(FSegment.Download(FPerformance)) then EXIT;

  // ������� ������, ��������������� ������� ���������������
  Result := TdxMusicSegment.Create(FPerformance, FLoader, FSegment);

  // ��������� ������ � ���������
  if Result <> NIL then
     FSegmentList.Add(Result);
end;

{******************************************************************************}
{**  ������� ������� ��������������� �� �������                              **}
{******************************************************************************}
function TdxMusicManager.DeleteSegment(Index: integer): HResult;
begin
  // ��������� �� ���������
  Result := E_FAIL;

  // ���� ������ ��������, �� ��������� ������
  if (Index < 0) or (Index >= FSegmentList.Count) then EXIT;

  // ������������� ��������������� �������
  TdxMusicSegment(FSegmentList.Items[Index]).Stop;

  // ����������� ������, ���������� ��� �������
  TdxMusicSegment(FSegmentList.Items[Index]).Free;
  FSegmentList.Items[Index] := NIL;

  // ������� ������ �� ������� �� ����������
  FSegmentList.Delete(Index);

  Result := S_OK;
end;

{******************************************************************************}
{**  ������� ������� ��������������� �� ������                               **}
{******************************************************************************}
function TdxMusicManager.DeleteSegment(Segment: TdxMusicSegment): HResult;
begin
  // ��������� �� ��������� 
  Result := E_FAIL;

  // �������� ��������
  if (Segment = NIL) or (FSegmentList.IndexOf(Segment) < 0) then EXIT;

  // ������������� ��������������� �������
  Segment.Stop;

  // ������� ������ �� ������� �� ����������
  FSegmentList.Remove(Segment);

  // ����������� ������, ���������� ��� �������
  FreeAndNil(Segment);
end;

{******************************************************************************}
{**  ���������� ������                                                       **}
{******************************************************************************}
destructor TdxMusicManager.Destroy;
var
  I: integer;
begin
  // ������������� ������ ��������� ���������������
  if FPerformance <> NIL then
     FPerformance.Stop(NIL, NIL, 0, 0);

  // ������� ��������� ���������
  if FSegmentList <> NIL then
  begin
    for I := 0 to FSegmentList.Count - 1 do
    begin
      TdxMusicSegment(FSegmentList.Items[I]).Stop;
      TdxMusicSegment(FSegmentList.Items[I]).Free;
      FSegmentList.Items[I] := NIL;
    end;

    FreeAndNil(FSegmentList);
  end;

  // ��������� ������ �� ��������� � �������� ���������������
  FLoader := NIL;
  FPerformance := NIL;

  // ���������� ������ � COM
  CoUninitialize;
end;

{******************************************************************************}
{**  ��������� �������� �� �������                                           **}
{******************************************************************************}
function TdxMusicManager.GetSegment(Index: integer): TdxMusicSegment;
begin
  // ��������� �� ���������
  Result := NIL;

  // ���� ������ ��������, �� ��������� ������
  if (Index < 0) or (Index >= FSegmentList.Count) then EXIT;

  // �������� ������ �� ������� �� ����������
  Result := FSegmentList.Items[Index];
end;

{******************************************************************************}
{**  ������������� ������������ ���������                                    **}
{******************************************************************************}
function TdxMusicManager.Initialize: HResult;
begin
  // ������� ���������
  Result := CoCreateInstance(CLSID_DirectMusicLoader, NIL, CLSCTX_INPROC,
    IID_IDirectMusicLoader8, FLoader);
  if FAILED(Result) then EXIT;

  // ������� �������� ���������������
  Result := CoCreateInstance(CLSID_DirectMusicPerformance, NIL, CLSCTX_INPROC,
    IID_IDirectMusicPerformance8, FPerformance);
  if FAILED(Result) then EXIT;

  // �������������� �������� ���������������
  Result := FPerformance.InitAudio(NIL, NIL, FHandle, DMUS_APATH_DYNAMIC_STEREO,
    128, DMUS_AUDIOF_ALL, NIL);
end;

{******************************************************************************}
{**  ��������� ����� ���������                                               **}
{******************************************************************************}
function TdxMusicManager.SegmentCount: integer;
begin
  Result := FSegmentList.Count;
end;

{**} { TdxMusicSegment } {*****************************************************}

{******************************************************************************}
{**  ����������� ������                                                      **}
{******************************************************************************}
constructor TdxMusicSegment.Create(APerformance: IDirectMusicPerformance8;
  ALoader: IDirectMusicLoader8; ASegment: IDirectMusicSegment8);
begin
  // ���������� �������� ���������������
  FPerformance := APerformance;

  // ���������� ���������
  FLoader := ALoader;

  // ���������� ������� ��������������� 
  FSegment := ASegment;
end;

{******************************************************************************}
{**  ���������� ������                                                       **}
{******************************************************************************}
destructor TdxMusicSegment.Destroy;
begin
  // ��������� ������� ��������
  if FSegment <> NIL then
  begin
    // ��������� ������ �� ��������
    FSegment.Unload(FPerformance);

    // �������� ������� ���������������
    FSegment := NIL;
  end;
end;

{******************************************************************************}
{**  ��������� ��������������� ��������                                      **}
{******************************************************************************}
function TdxMusicSegment.IsPlaying: boolean;
begin
  Result := (FPerformance.IsPlaying(FSegment, NIL) = S_OK);
end;

{******************************************************************************}
{**  ������������� �������                                                   **}
{******************************************************************************}
function TdxMusicSegment.Play(IsPrimary: boolean): HResult;
begin
  // ��������� �� ���������
  Result := E_FAIL;
  
  // �������� ������� ��������� ���������������
  if FPerformance = NIL then EXIT;

  if IsPrimary then
    // ������������� �������� �������
    Result := FPerformance.PlaySegmentEx(FSegment, NIL, NIL, 0,
      0, NIL, NIL, NIL)
  else
    // ������������� ��������� �������
    Result := FPerformance.PlaySegmentEx(FSegment, NIL, NIL, DMUS_SEGF_SECONDARY,
      0, NIL, NIL, NIL); 
end;

{******************************************************************************}
{**  ��������� ����� ������ ���������������                                  **}
{******************************************************************************}
function TdxMusicSegment.SetRepeats(dwRepeats: DWORD): HResult;
begin
  // ��������� �� ���������
  Result := E_FAIL;
  
  // �������� ������� ��������
  if FSegment = NIL then EXIT;

  // ������������� ����� ������ ���������������
  Result := FSegment.SetRepeats(dwRepeats);
end;

{******************************************************************************}
{**  ��������� ��������������� ��������                                      **}
{******************************************************************************}
function TdxMusicSegment.Stop: HResult;
begin
  // ��������� �� ���������
  Result := E_FAIL;
  
  // �������� ������� ��������� ���������������
  if FPerformance = NIL then EXIT;

  // ������������� ��������������� ��������
  Result := FPerformance.StopEx(FSegment, 0, 0);
end;

END.
