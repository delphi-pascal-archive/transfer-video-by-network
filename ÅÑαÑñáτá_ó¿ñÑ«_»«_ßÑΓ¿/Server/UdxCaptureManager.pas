UNIT UdxCaptureManager;

{******************************************************************************}
{** ������ ����� � ����� ����������� DirectShow                              **}
{** �����: ������ ������ �����������                                         **}
{******************************************************************************}

{**} INTERFACE {***************************************************************}

{**} USES {********************************************************************}
  Windows, Classes, Graphics, SysUtils, ActiveX, DirectShow9, Dialogs;

{**} TYPE {********************************************************************}
  TdxCaptureManager = class
  PRIVATE
    FGraphBuilder:        IGraphBuilder;
    FCaptureGraphBuilder: ICaptureGraphBuilder2;
    FMux:                 IBaseFilter;
    FSink:                IFileSinkFilter;
    FMediaControl:        IMediaControl;
    FVideoWindow:         IVideoWindow;

    FVideoCaptureFilter:  IBaseFilter;
    FAudioCaptureFilter:  IBaseFilter;
    FVideoCompressFilter: IBaseFilter;
    FAudioCompressFilter: IBaseFilter;

    FCaptureFileName:     WideString;
    FCapturing:           boolean;
    FVideoHandle:         THandle;
    FPreview:             boolean;
    FVideoRect:           TRect;

    FVideoCaptureDeviceName:  WideString;
    FAudioCaptureDeviceName:  WideString;
    FVideoCompressDeviceName: WideString;
    FAudioCompressDeviceName: WideString;

    procedure SetPreview(Value: boolean);

    function EnumerateDevices(const clsidDeviceClass: TGUID; DevName: WideString;
      DevList: TStrings; GetFirst: boolean = FALSE): IBaseFilter;

    procedure SetVideoCaptureDeviceName(Value: WideString);
    procedure SetAudioCaptureDeviceName(Value: WideString);
    procedure SetVideoCompressDeviceName(Value: WideString);
    procedure SetAudioCompressDeviceName(Value: WideString);

    function DisplayPropertyFrame(Filter: IBaseFilter; Handle: THandle): HResult;
    
  PUBLIC
    property CaptureFileName: WideString read FCaptureFileName write FCaptureFileName;

    property Preview: boolean read FPreview write SetPreview;

    property VideoCaptureDeviceName: WideString read FVideoCaptureDeviceName write SetVideoCaptureDeviceName;
    property AudioCaptureDeviceName: WideString read FAudioCaptureDeviceName write SetAudioCaptureDeviceName;
    property VideoCompressDeviceName: WideString read FVideoCompressDeviceName write SetVideoCompressDeviceName;
    property AudioCompressDeviceName: WideString read FAudioCompressDeviceName write SetAudioCompressDeviceName;

    constructor Create(AHandle: THandle; ARect: TRect; APreview: boolean = TRUE);
    destructor Destroy; override;

    procedure ResetGraph;
    function ConstructGraph: HResult;

    procedure EnumVideoCaptureDevices(List: TStrings);
    procedure EnumAudioCaptureDevices(List: TStrings);
    procedure EnumVideoCompressDevices(List: TStrings);
    procedure EnumAudioCompressDevices(List: TStrings);

    function StartCapture: HResult;
    procedure StopCapture;

    function DisplayVideoCapturePinPropertyPage(Handle: THandle): HResult;
    
    function DisplayVideoCaptureDeviceProperty(Handle: THandle): HResult;
    function DisplayAudioCaptureDeviceProperty(Handle: THandle): HResult;
    function DisplayVideoCompressDeviceProperty(Handle: THandle): HResult;
    function DisplayAudioCompressDeviceProperty(Handle: THandle): HResult;
  END;

{**} IMPLEMENTATION {**********************************************************}

{**} { TdxCaptureManager } {**************************************************}
   
{******************************************************************************}
{** ����������� ������                                                       **}
{******************************************************************************}
constructor TdxCaptureManager.Create(AHandle: THandle; ARect: TRect;
  APreview: boolean);
begin
  // ���������� ���������� ���� ���������������� ���������
  FVideoHandle := AHandle;

  // ������ ��������� ���������������� ���������
  FPreview := APreview;

  // ������� ���� ������ �� ������ 
  FVideoRect := ARect;

  // �������� ��� AVI-�����
  FCaptureFileName := '';

  // �������� ���� �������
  FCapturing := FALSE;
end;

{******************************************************************************}
{** ���������� ������                                                        **}
{******************************************************************************}
destructor TdxCaptureManager.Destroy;
begin
  // ����������� ���������� ������
  ResetGraph;
end;

{******************************************************************************}
{** ���������� ����� ��������                                                **}
{******************************************************************************}
function TdxCaptureManager.ConstructGraph: HResult;
var
  pConfigMux: IConfigAviMux;
begin
  // ������ ����
  ResetGraph;

  // ������� ������ ��� ���������� ����� ��������
  Result := CoCreateInstance(CLSID_FilterGraph, NIL, CLSCTX_INPROC_SERVER,
    IID_IGraphBuilder, FGraphBuilder);
  if FAILED(Result) then EXIT;

  // ������� ������ ��� ���������� ����� �������
  Result := CoCreateInstance(CLSID_CaptureGraphBuilder2, NIL,
      CLSCTX_INPROC_SERVER, IID_ICaptureGraphBuilder2, FCaptureGraphBuilder);
  if FAILED(Result) then EXIT;

  // ������ ���� �������� ��� ������������� � ���������� ����� �������
  Result := FCaptureGraphBuilder.SetFiltergraph(FGraphBuilder);
  if FAILED(Result) then EXIT;

  // ��������� ��������� ������� �����
  FVideoCaptureFilter := EnumerateDevices(CLSID_VideoInputDeviceCategory,
    VideoCaptureDeviceName, NIL, TRUE);

  // ��������� ��������� ������� �����
  FAudioCaptureFilter := EnumerateDevices(CLSID_AudioInputDeviceCategory,
    AudioCaptureDeviceName, NIL, TRUE);

  // ��������� ��������� ������ �����
  if VideoCompressDeviceName <> '' then
  begin
    FVideoCompressFilter := EnumerateDevices(CLSID_VideoCompressorCategory,
      VideoCompressDeviceName, NIL, TRUE);
  end;

  // ��������� ��������� ������ �����
  if AudioCompressDeviceName <> '' then
  begin
    FAudioCompressFilter := EnumerateDevices(CLSID_AudioCompressorCategory,
      AudioCompressDeviceName, NIL, TRUE);
  end;

  // ��������� ������ ������� ����� � ����
  if FVideoCaptureFilter <> NIL then
  begin
    FGraphBuilder.AddFilter(FVideoCaptureFilter, 'VideoCaptureFilter');
  end;

  // ��������� ������ ������� ����� � ����
  if FAudioCaptureFilter <> NIL then
  begin
    FGraphBuilder.AddFilter(FAudioCaptureFilter, 'AudioCaptureFilter');
  end;

  // ��������� ������ ������ ����� � ����
  if FVideoCompressFilter <> NIL then
  begin
    FGraphBuilder.AddFilter(FVideoCompressFilter, 'VideoCompressFilter');
  end;

  // ��������� ������ ������ ����� � ����
  if FAudioCompressFilter <> NIL then
  begin
    FGraphBuilder.AddFilter(FAudioCompressFilter, 'AudioCompressFilter');
  end;

  // ���� ����� ����� ���������������� ���������, �� ...
  if FPreview then
  begin
    // ... ������� ����������
    if FVideoCaptureFilter <> NIL then
    begin

      Result := FCaptureGraphBuilder.RenderStream(@PIN_CATEGORY_PREVIEW, @MEDIATYPE_Video,
        FVideoCaptureFilter, NIL, NIL);
      if FAILED(Result) then EXIT;

      if FVideoHandle > 0 then
      begin
        // ����������� ��������� ���������� ����� ������ �����������
        FGraphBuilder.QueryInterface(IID_IVideoWindow, FVideoWindow);

        if FVideoWindow <> NIL then
        begin
          // ������������� ����� ����� ����
          FVideoWindow.put_WindowStyle(WS_CHILD or WS_CLIPSIBLINGS);

          // ������������� ������������ ���� ��� ������ ����������� 
          FVideoWindow.put_Owner(FVideoHandle);

          // ������������� ��������� ����
          FVideoWindow.SetWindowPosition(
            FVideoRect.Left,
            FVideoRect.Top,
            FVideoRect.Right - FVideoRect.Left,
            FVideoRect.Bottom - FVideoRect.Top);

          // ���������� ���� ������ �����������
          FVideoWindow.put_Visible(TRUE);
        end;
      end;

    end;

    // ... ������� ����
    if FAudioCaptureFilter <> NIL then
    begin
      Result := FCaptureGraphBuilder.RenderStream(@PIN_CATEGORY_PREVIEW, @MEDIATYPE_Audio,
        FAudioCaptureFilter, NIL, NIL);
      if FAILED(Result) then EXIT;
    end;
  end;

  // ���� ����� ����� �������, �� ...
  if FCapturing then
  begin
    // ������� ���� ��� ������ ������ �� �����
    Result := FCaptureGraphBuilder.SetOutputFileName(MEDIASUBTYPE_Avi,
      PWideChar(FCaptureFileName), FMux, FSink);
    if FAILED(Result) then EXIT;

    // ������������� ����� ������� �����������
    if FVideoCaptureFilter <> NIL then
    begin
      Result := FCaptureGraphBuilder.RenderStream(@PIN_CATEGORY_CAPTURE, @MEDIATYPE_Video,
        FVideoCaptureFilter, FVideoCompressFilter, FMux);
       
      if FAILED(Result) then EXIT;
    end;

    // ������������� ����� ������� �����
    if FAudioCaptureFilter <> NIL then
    begin
      Result := FCaptureGraphBuilder.RenderStream(@PIN_CATEGORY_CAPTURE, @MEDIATYPE_Audio,
       FAudioCaptureFilter, FAudioCompressFilter, FMux);
      if FAILED(Result) then EXIT;

      // ��� ������� ����� �� ������ ������������� �������� ����� �
      // �������� ��������� ��� ������������� � ������� �������� � �����
      if FVideoCaptureFilter <> NIL then
      begin
        pConfigMux := NIL;
        Result := FMux.QueryInterface(IID_IConfigAviMux, pConfigMux);
        if (SUCCEEDED(Result)) then
        begin
          pConfigMux.SetMasterStream(1);
          pConfigMux := NIL;
        end;
      end;
    end;
  end;

  // ����������� ��������� ���������� ������
  Result := FGraphBuilder.QueryInterface(IID_IMediaControl, FMediaControl);
  if FAILED(Result) then EXIT;

  // ��������� ����
  Result := FMediaControl.Run();
end;

{******************************************************************************}
{** ������������ ��������� ������������� ������                              **}
{******************************************************************************}
function TdxCaptureManager.EnumerateDevices(const clsidDeviceClass: TGUID;
  DevName: WideString; DevList: TStrings; GetFirst: boolean): IBaseFilter;
var
  DeviceName:   OleVariant;
  PropertyName: IPropertyBag;
  pDevEnum:     ICreateDevEnum;
  pEnum:        IEnumMoniker;
  pFilter:      IBaseFilter;
  pMoniker:     IMoniker;
  hr:           HResult;
begin
  // �������� ������
  pMoniker     := NIL;
  pFilter      := NIL;
  PropertyName := NIL;
  pDevEnum     := NIL;
  pEnum        := NIL;

  // ��������� �� ���������
  Result       := NIL;

  // ������� ������ ��� ������������ ���������
  hr := CoCreateInstance(CLSID_SystemDeviceEnum, NIL, CLSCTX_INPROC_SERVER,
    IID_ICreateDevEnum, pDevEnum);
  if FAILED(hr) then EXIT;

  // ������� ������������� ��� ��������� ��������� ���������
  hr := pDevEnum.CreateClassEnumerator(clsidDeviceClass, pEnum, 0);
  if (hr <> S_OK) then EXIT;

  // ���� �� �����������
  while (S_OK = pEnum.Next(1, pMoniker, NIL)) do
  begin
    // ���� ��� ����� ������ ���������, �� ...
    if not GetFirst then
    begin
      // ... �������� ��������� ���������, ������� �������� ������,
      // ���������������� ���������
      hr := pMoniker.BindToStorage(NIL, NIL, IPropertyBag, PropertyName);
      if FAILED(hr) then Continue;

      // ������ �������� ��������
      hr := PropertyName.Read('FriendlyName', DeviceName, NIL);
      if FAILED(hr) then Continue;

      // ��������� �������� ���������� � ��� ������
      if DevList <> NIL then DevList.Add(DeviceName);
    end

    // ���� ��� ����� �������� ������ ����������, �� ...
    else begin

      // ���� ������� ��� ����������, �� ...
      if DevName <> '' then
      begin
        // ... �������� ��������� ���������, ������� �������� ������,
        // ���������������� ���������
        hr := pMoniker.BindToStorage(NIL, NIL, IPropertyBag, PropertyName);
        if FAILED(hr) then Continue;

        // ������ �������� ��������
        hr := PropertyName.Read('FriendlyName', DeviceName, NIL);
        if FAILED(hr) then Continue;

        // ���������� �����, ���� �� ��������� ����� ���������
        if (DeviceName <> DevName) then Continue;
      end;

      // ��������� ������� ����������� � ��������, ������� ��
      // ��������������, � �������� ������ ��� ���������
      hr := pMoniker.BindToObject(NIL, NIL, IID_IBaseFilter, pFilter);
      if SUCCEEDED(hr) then
      begin
        // ��������� - ���������� ���������
        Result := pFilter;

        // ����������� ������
        pEnum := NIL;
        pDevEnum := NIL;
        pMoniker := NIL;
        PropertyName := NIL;

        // ������� �� ��������� ��������
        EXIT;
      end;
    end;
  end;

  // ����������� ������
  pEnum        := NIL;
  pDevEnum     := NIL;
  PropertyName := NIL;
  pFilter      := NIL;
  pMoniker     := NIL;
end;

{******************************************************************************}
{** ��������� ������ ��������� ������� �����                                 **}
{******************************************************************************}
procedure TdxCaptureManager.EnumVideoCaptureDevices(List: TStrings);
begin
  EnumerateDevices(CLSID_VideoInputDeviceCategory, '', List);
end;

{******************************************************************************}
{** ��������� ������ ��������� ������� �����                                 **}
{******************************************************************************}
procedure TdxCaptureManager.EnumVideoCompressDevices(List: TStrings);
begin
  EnumerateDevices(CLSID_VideoCompressorCategory, '', List);
end;     

{******************************************************************************}
{** ��������� ������ ��������� ������� �����                                 **}
{******************************************************************************}
procedure TdxCaptureManager.EnumAudioCaptureDevices(List: TStrings);
begin
  EnumerateDevices(CLSID_AudioInputDeviceCategory, '', List);
end;

{******************************************************************************}
{** ��������� ������ ��������� ������� �����                                 **}
{******************************************************************************}
procedure TdxCaptureManager.EnumAudioCompressDevices(List: TStrings);
begin
  EnumerateDevices(CLSID_AudioCompressorCategory, '', List);
end;

{******************************************************************************}
{** ������ ����� - ����������� ������                                        **}
{******************************************************************************}
procedure TdxCaptureManager.ResetGraph;
begin
  FAudioCompressFilter := NIL;
  FVideoCompressFilter := NIL;
  FAudioCaptureFilter  := NIL;
  FVideoCaptureFilter  := NIL;
  FVideoWindow         := NIL;
  FMediaControl        := NIL;
  FSink                := NIL;
  FMux                 := NIL;
  FCaptureGraphBuilder := NIL;
  FGraphBuilder        := NIL;
end;

{******************************************************************************}
{** ��������� ����� ���������� ������ � �����                                **}
{******************************************************************************}
procedure TdxCaptureManager.SetVideoCaptureDeviceName(Value: WideString);
begin
  FVideoCaptureDeviceName := Value;
end;

{******************************************************************************}
{** ��������� ����� ���������� ������ �����                                  **}
{******************************************************************************}
procedure TdxCaptureManager.SetVideoCompressDeviceName(Value: WideString);
begin
  FVideoCompressDeviceName := Value;
end;

{******************************************************************************}
{** ��������� ����� ���������� ������ �� ������                              **}
{******************************************************************************}
procedure TdxCaptureManager.SetAudioCaptureDeviceName(Value: WideString);
begin
  FAudioCaptureDeviceName := Value;
end;

{******************************************************************************}
{** ��������� ����� ���������� ������ �����                                  **}
{******************************************************************************}
procedure TdxCaptureManager.SetAudioCompressDeviceName(Value: WideString);
begin
  FAudioCompressDeviceName := Value;
end;

{******************************************************************************}
{** ��������� ������ ���������������� ���������                              **}
{******************************************************************************}
procedure TdxCaptureManager.SetPreview(Value: boolean);
begin
  // ��������� �������� ��������
  FPreview := Value;

  // �������������� ����
  ConstructGraph;
end;

{******************************************************************************}
{** �������� ������                                                          **}
{******************************************************************************}
function TdxCaptureManager.StartCapture: HResult;
begin
  // ��������� �� ���������
  Result := E_FAIL;

  // ���� ��� ��������� � ��������� ������, �� ��������� ������
  if FCapturing then EXIT;

  // ���������� ���� ������
  FCapturing := TRUE;

  // �������������� ����
  ConstructGraph;
end;

{******************************************************************************}
{** ������������� ������� ������                                             **}
{******************************************************************************}
procedure TdxCaptureManager.StopCapture;
begin
  // ���� ������ �� ������������, �� ��������� ������
  if not FCapturing then EXIT;

  // ���������� ���� ������
  FCapturing := FALSE;

  // �������������� ����
  ConstructGraph;
end;

{******************************************************************************}
{** ����� �������� ������� �������� ������ �����                             **}
{******************************************************************************}
function TdxCaptureManager.DisplayVideoCapturePinPropertyPage(
  Handle: THandle): HResult;
var
  StreamConfig: IAMStreamConfig;
  PropertyPages: ISpecifyPropertyPages;
  Pages: CAUUID;
begin
  // ��������� �� ���������
  Result := E_FAIL;

  // ���� ����������� ��������� ������ � �����, �� ��������� ������
  if FVideoCaptureFilter = NIL then EXIT;   

  // ������������� ������ �����
  FMediaControl.Stop;

  try
    // ���� ��������� ���������� �������� ������ ��������� ������
    Result := FCaptureGraphBuilder.FindInterface(@PIN_CATEGORY_CAPTURE,
      @MEDIATYPE_Video, FVideoCaptureFilter, IID_IAMStreamConfig, StreamConfig);

    // ���� ��������� ������, �� ...
    if SUCCEEDED(Result) then
    begin
      // ... �������� ����� ��������� ���������� ���������� ������� ...
      Result := StreamConfig.QueryInterface(ISpecifyPropertyPages, PropertyPages);

      // ... �, ���� �� ������, �� ...
      if SUCCEEDED(Result) then
      begin
        // ... �������� ������ ������� �������
        PropertyPages.GetPages(Pages);
        PropertyPages := NIL;

        // ���������� �������� ������� � ���� ���������� �������
        OleCreatePropertyFrame(
           Handle,
           0,
           0,                   
           PWideChar(VideoCaptureDeviceName),
           1,
           @StreamConfig,
           Pages.cElems,
           Pages.pElems,
           0,
           0,
           NIL
        );

        // ����������� ������
        StreamConfig := NIL;
        CoTaskMemFree(Pages.pElems);
      end;
    end;
    
  finally
    // ��������������� ������ �����
    FMediaControl.Run;
  end;
end;

{******************************************************************************}
{** ����� �������� ������� ��������� �������                                 **}
{******************************************************************************}
function TdxCaptureManager.DisplayPropertyFrame(Filter: IBaseFilter;
  Handle: THandle): HResult;
var
  PropertyPages: ISpecifyPropertyPages;
  Pages: CAUUID;
  FilterInfo: TFilterInfo;
  pfilterUnk: IUnknown;
begin
  // ��������� �� ���������
  Result := E_FAIL;

  // ���� ������ �� ���������, �� ��������� ������
  if Filter = NIL then EXIT;

  // �������� ����� ��������� ���������� ���������� ������� �������
  Result := Filter.QueryInterface(ISpecifyPropertyPages, PropertyPages);
                    
  if (SUCCEEDED(Result)) then
  begin
    // ��������� ����� ������� � ��������� �� ��������� IUnknown
    Filter.QueryFilterInfo(FilterInfo);
    Filter.QueryInterface(IUnknown, pfilterUnk);

    // �������� ������ ������� �������
    PropertyPages.GetPages(Pages);
    PropertyPages := NIL;

    // ���������� �������� ������� � ���� ���������� �������
    OleCreatePropertyFrame(
       Handle,                 
       0,
       0,                   
       FilterInfo.achName,     
       1,                      
       @pfilterUnk,            
       Pages.cElems,           
       Pages.pElems,           
       0,                      
       0,
       NIL                  
    );

    // ����������� ������
    pfilterUnk := NIL;
    FilterInfo.pGraph := NIL;
    
    CoTaskMemFree(Pages.pElems);
  end;
end;

{******************************************************************************}
{** ����� �������� ������� ���������� ������ � �����                         **}
{******************************************************************************}
function TdxCaptureManager.DisplayVideoCaptureDeviceProperty(
  Handle: THandle): HResult;
begin
  Result := DisplayPropertyFrame(FVideoCaptureFilter, Handle);
end;

{******************************************************************************}
{** ����� �������� ������� ���������� ������ �����                           **}
{******************************************************************************}
function TdxCaptureManager.DisplayVideoCompressDeviceProperty(
  Handle: THandle): HResult;
begin
  Result := DisplayPropertyFrame(FVideoCompressFilter, Handle);
end;

{******************************************************************************}
{** ����� �������� ������� ���������� ������ �� ������                       **}
{******************************************************************************}
function TdxCaptureManager.DisplayAudioCaptureDeviceProperty(
  Handle: THandle): HResult;
begin
  Result := DisplayPropertyFrame(FAudioCaptureFilter, Handle);
end;

{******************************************************************************}
{** ����� �������� ������� ���������� ������ �����                           **}
{******************************************************************************}
function TdxCaptureManager.DisplayAudioCompressDeviceProperty(
  Handle: THandle): HResult;
begin
  Result := DisplayPropertyFrame(FAudioCompressFilter, Handle);
end;

END.
