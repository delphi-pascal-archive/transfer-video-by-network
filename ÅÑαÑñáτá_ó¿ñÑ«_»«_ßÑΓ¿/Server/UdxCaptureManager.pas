UNIT UdxCaptureManager;

{******************************************************************************}
{** Захват аудио и видео посредством DirectShow                              **}
{** Автор: Есенин Сергей Анатольевич                                         **}
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
{** Конструктор класса                                                       **}
{******************************************************************************}
constructor TdxCaptureManager.Create(AHandle: THandle; ARect: TRect;
  APreview: boolean);
begin
  // Запоминаем дескриптор окна предварительного просмотра
  FVideoHandle := AHandle;

  // Задаем состояние предварительного просмотра
  FPreview := APreview;

  // Позиция окна вывода на экране 
  FVideoRect := ARect;

  // Обнуляем имя AVI-файла
  FCaptureFileName := '';

  // Обнуляем флаг захвата
  FCapturing := FALSE;
end;

{******************************************************************************}
{** Деструктор класса                                                        **}
{******************************************************************************}
destructor TdxCaptureManager.Destroy;
begin
  // Освобождаем выделенную память
  ResetGraph;
end;

{******************************************************************************}
{** Построение графа фильтров                                                **}
{******************************************************************************}
function TdxCaptureManager.ConstructGraph: HResult;
var
  pConfigMux: IConfigAviMux;
begin
  // Чистим граф
  ResetGraph;

  // Создаем объект для построения графа фильтров
  Result := CoCreateInstance(CLSID_FilterGraph, NIL, CLSCTX_INPROC_SERVER,
    IID_IGraphBuilder, FGraphBuilder);
  if FAILED(Result) then EXIT;

  // Создаем объект для построения графа захвата
  Result := CoCreateInstance(CLSID_CaptureGraphBuilder2, NIL,
      CLSCTX_INPROC_SERVER, IID_ICaptureGraphBuilder2, FCaptureGraphBuilder);
  if FAILED(Result) then EXIT;

  // Задаем граф фильтров для использования в построении графа захвата
  Result := FCaptureGraphBuilder.SetFiltergraph(FGraphBuilder);
  if FAILED(Result) then EXIT;

  // Получение устройтва захвата видео
  FVideoCaptureFilter := EnumerateDevices(CLSID_VideoInputDeviceCategory,
    VideoCaptureDeviceName, NIL, TRUE);

  // Получение устройтва захвата звука
  FAudioCaptureFilter := EnumerateDevices(CLSID_AudioInputDeviceCategory,
    AudioCaptureDeviceName, NIL, TRUE);

  // Получение устройтва сжатия видео
  if VideoCompressDeviceName <> '' then
  begin
    FVideoCompressFilter := EnumerateDevices(CLSID_VideoCompressorCategory,
      VideoCompressDeviceName, NIL, TRUE);
  end;

  // Получение устройтва сжатия звука
  if AudioCompressDeviceName <> '' then
  begin
    FAudioCompressFilter := EnumerateDevices(CLSID_AudioCompressorCategory,
      AudioCompressDeviceName, NIL, TRUE);
  end;

  // Добавляем фильтр захвата видео в граф
  if FVideoCaptureFilter <> NIL then
  begin
    FGraphBuilder.AddFilter(FVideoCaptureFilter, 'VideoCaptureFilter');
  end;

  // Добавляем фильтр захвата звука в граф
  if FAudioCaptureFilter <> NIL then
  begin
    FGraphBuilder.AddFilter(FAudioCaptureFilter, 'AudioCaptureFilter');
  end;

  // Добавляем фильтр сжатия видео в граф
  if FVideoCompressFilter <> NIL then
  begin
    FGraphBuilder.AddFilter(FVideoCompressFilter, 'VideoCompressFilter');
  end;

  // Добавляем фильтр сжатия звука в граф
  if FAudioCompressFilter <> NIL then
  begin
    FGraphBuilder.AddFilter(FAudioCompressFilter, 'AudioCompressFilter');
  end;

  // Если задан режим предварительного просмотра, то ...
  if FPreview then
  begin
    // ... выводим изображени
    if FVideoCaptureFilter <> NIL then
    begin

      Result := FCaptureGraphBuilder.RenderStream(@PIN_CATEGORY_PREVIEW, @MEDIATYPE_Video,
        FVideoCaptureFilter, NIL, NIL);
      if FAILED(Result) then EXIT;

      if FVideoHandle > 0 then
      begin
        // Запрашиваем интерфейс управления окном вывода изображения
        FGraphBuilder.QueryInterface(IID_IVideoWindow, FVideoWindow);

        if FVideoWindow <> NIL then
        begin
          // Устанавливаем стиль видео окна
          FVideoWindow.put_WindowStyle(WS_CHILD or WS_CLIPSIBLINGS);

          // Устанавливаем родительское окно для вывода изображения 
          FVideoWindow.put_Owner(FVideoHandle);

          // Устанавливаем положение окна
          FVideoWindow.SetWindowPosition(
            FVideoRect.Left,
            FVideoRect.Top,
            FVideoRect.Right - FVideoRect.Left,
            FVideoRect.Bottom - FVideoRect.Top);

          // Показываем окно вывода изображения
          FVideoWindow.put_Visible(TRUE);
        end;
      end;

    end;

    // ... выводим звук
    if FAudioCaptureFilter <> NIL then
    begin
      Result := FCaptureGraphBuilder.RenderStream(@PIN_CATEGORY_PREVIEW, @MEDIATYPE_Audio,
        FAudioCaptureFilter, NIL, NIL);
      if FAILED(Result) then EXIT;
    end;
  end;

  // Если задан режим захвата, то ...
  if FCapturing then
  begin
    // Создаем файл для записи данных из графа
    Result := FCaptureGraphBuilder.SetOutputFileName(MEDIASUBTYPE_Avi,
      PWideChar(FCaptureFileName), FMux, FSink);
    if FAILED(Result) then EXIT;

    // Устанавливаем режим захвата изображения
    if FVideoCaptureFilter <> NIL then
    begin
      Result := FCaptureGraphBuilder.RenderStream(@PIN_CATEGORY_CAPTURE, @MEDIATYPE_Video,
        FVideoCaptureFilter, FVideoCompressFilter, FMux);
       
      if FAILED(Result) then EXIT;
    end;

    // Устанавливаем режим захвата звука
    if FAudioCaptureFilter <> NIL then
    begin
      Result := FCaptureGraphBuilder.RenderStream(@PIN_CATEGORY_CAPTURE, @MEDIATYPE_Audio,
       FAudioCaptureFilter, FAudioCompressFilter, FMux);
      if FAILED(Result) then EXIT;

      // При захвате видео со звуком устанавливаем звуковой поток в
      // качестве основного для синхронизации с другими потоками в файле
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

  // Запрашиваем интерфейс управления графом
  Result := FGraphBuilder.QueryInterface(IID_IMediaControl, FMediaControl);
  if FAILED(Result) then EXIT;

  // Запускаем граф
  Result := FMediaControl.Run();
end;

{******************************************************************************}
{** Перечисление устройств определенного класса                              **}
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
  // Обнуляем ссылки
  pMoniker     := NIL;
  pFilter      := NIL;
  PropertyName := NIL;
  pDevEnum     := NIL;
  pEnum        := NIL;

  // Результат по умолчанию
  Result       := NIL;

  // Создаем объект для перечисления устройств
  hr := CoCreateInstance(CLSID_SystemDeviceEnum, NIL, CLSCTX_INPROC_SERVER,
    IID_ICreateDevEnum, pDevEnum);
  if FAILED(hr) then EXIT;

  // Создаем перечислитель для указанной категории устройств
  hr := pDevEnum.CreateClassEnumerator(clsidDeviceClass, pEnum, 0);
  if (hr <> S_OK) then EXIT;

  // Цикл по устройствам
  while (S_OK = pEnum.Next(1, pMoniker, NIL)) do
  begin
    // Если нам нужен список устройств, то ...
    if not GetFirst then
    begin
      // ... получаем интерфейс хранилища, которое содержит объект,
      // идентифицируемый моникером
      hr := pMoniker.BindToStorage(NIL, NIL, IPropertyBag, PropertyName);
      if FAILED(hr) then Continue;

      // Читаем значение свойства
      hr := PropertyName.Read('FriendlyName', DeviceName, NIL);
      if FAILED(hr) then Continue;

      // Добавляем название устройства в наш список
      if DevList <> NIL then DevList.Add(DeviceName);
    end

    // Если нам нужно получить первое устройство, то ...
    else begin

      // Если указано имя устройства, то ...
      if DevName <> '' then
      begin
        // ... получаем интерфейс хранилища, которое содержит объект,
        // идентифицируемый моникером
        hr := pMoniker.BindToStorage(NIL, NIL, IPropertyBag, PropertyName);
        if FAILED(hr) then Continue;

        // Читаем значение свойства
        hr := PropertyName.Read('FriendlyName', DeviceName, NIL);
        if FAILED(hr) then Continue;

        // Продолжаем поиск, если не совпадают имена устройств
        if (DeviceName <> DevName) then Continue;
      end;

      // Используя моникер связываемся с объектом, который он
      // идентифицирует, и получаем нужный нам интерфейс
      hr := pMoniker.BindToObject(NIL, NIL, IID_IBaseFilter, pFilter);
      if SUCCEEDED(hr) then
      begin
        // Результат - полученный интерфейс
        Result := pFilter;

        // Освобождаем память
        pEnum := NIL;
        pDevEnum := NIL;
        pMoniker := NIL;
        PropertyName := NIL;

        // Выходим из процедуры досрочно
        EXIT;
      end;
    end;
  end;

  // Освобождаем память
  pEnum        := NIL;
  pDevEnum     := NIL;
  PropertyName := NIL;
  pFilter      := NIL;
  pMoniker     := NIL;
end;

{******************************************************************************}
{** Получение списка устройств захвата видео                                 **}
{******************************************************************************}
procedure TdxCaptureManager.EnumVideoCaptureDevices(List: TStrings);
begin
  EnumerateDevices(CLSID_VideoInputDeviceCategory, '', List);
end;

{******************************************************************************}
{** Получение списка устройств захвата видео                                 **}
{******************************************************************************}
procedure TdxCaptureManager.EnumVideoCompressDevices(List: TStrings);
begin
  EnumerateDevices(CLSID_VideoCompressorCategory, '', List);
end;     

{******************************************************************************}
{** Получение списка устройств захвата видео                                 **}
{******************************************************************************}
procedure TdxCaptureManager.EnumAudioCaptureDevices(List: TStrings);
begin
  EnumerateDevices(CLSID_AudioInputDeviceCategory, '', List);
end;

{******************************************************************************}
{** Получение списка устройств захвата видео                                 **}
{******************************************************************************}
procedure TdxCaptureManager.EnumAudioCompressDevices(List: TStrings);
begin
  EnumerateDevices(CLSID_AudioCompressorCategory, '', List);
end;

{******************************************************************************}
{** Чистка графа - освобождаем память                                        **}
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
{** Установка имени устройства работы с видео                                **}
{******************************************************************************}
procedure TdxCaptureManager.SetVideoCaptureDeviceName(Value: WideString);
begin
  FVideoCaptureDeviceName := Value;
end;

{******************************************************************************}
{** Установка имени устройства сжатия видео                                  **}
{******************************************************************************}
procedure TdxCaptureManager.SetVideoCompressDeviceName(Value: WideString);
begin
  FVideoCompressDeviceName := Value;
end;

{******************************************************************************}
{** Установка имени устройства работы со звуком                              **}
{******************************************************************************}
procedure TdxCaptureManager.SetAudioCaptureDeviceName(Value: WideString);
begin
  FAudioCaptureDeviceName := Value;
end;

{******************************************************************************}
{** Установка имени устройства сжатия звука                                  **}
{******************************************************************************}
procedure TdxCaptureManager.SetAudioCompressDeviceName(Value: WideString);
begin
  FAudioCompressDeviceName := Value;
end;

{******************************************************************************}
{** Установка режима предварительного просмотра                              **}
{******************************************************************************}
procedure TdxCaptureManager.SetPreview(Value: boolean);
begin
  // Установка значения свойства
  FPreview := Value;

  // Перестраимваем граф
  ConstructGraph;
end;

{******************************************************************************}
{** Начинаем запись                                                          **}
{******************************************************************************}
function TdxCaptureManager.StartCapture: HResult;
begin
  // Результат по умолчанию
  Result := E_FAIL;

  // Если уже находимся в состоянии записи, то завершаем работу
  if FCapturing then EXIT;

  // Выставляем флаг записи
  FCapturing := TRUE;

  // Перестраимваем граф
  ConstructGraph;
end;

{******************************************************************************}
{** Останавливаем процесс записи                                             **}
{******************************************************************************}
procedure TdxCaptureManager.StopCapture;
begin
  // Если запись не производится, то завершаем работу
  if not FCapturing then EXIT;

  // Выставляем флаг записи
  FCapturing := FALSE;

  // Перестраимваем граф
  ConstructGraph;
end;

{******************************************************************************}
{** Вызов страницы свойств контакта потока видео                             **}
{******************************************************************************}
function TdxCaptureManager.DisplayVideoCapturePinPropertyPage(
  Handle: THandle): HResult;
var
  StreamConfig: IAMStreamConfig;
  PropertyPages: ISpecifyPropertyPages;
  Pages: CAUUID;
begin
  // Результат по умолчанию
  Result := E_FAIL;

  // Если отсутствует интерфейс работы с видео, то завершаем работу
  if FVideoCaptureFilter = NIL then EXIT;   

  // Останавливаем работу графа
  FMediaControl.Stop;

  try
    // Ищем интерфейс управления форматом данных выходного потока
    Result := FCaptureGraphBuilder.FindInterface(@PIN_CATEGORY_CAPTURE,
      @MEDIATYPE_Video, FVideoCaptureFilter, IID_IAMStreamConfig, StreamConfig);

    // Если интерфейс найден, то ...
    if SUCCEEDED(Result) then
    begin
      // ... пытаемся найти интерфейс управления страницами свойств ...
      Result := StreamConfig.QueryInterface(ISpecifyPropertyPages, PropertyPages);

      // ... и, если он найден, то ...
      if SUCCEEDED(Result) then
      begin
        // ... получаем массив страниц свойств
        PropertyPages.GetPages(Pages);
        PropertyPages := NIL;

        // Отображаем страницу свойств в виде модального диалога
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

        // Освобождаем память
        StreamConfig := NIL;
        CoTaskMemFree(Pages.pElems);
      end;
    end;
    
  finally
    // Восстанавливаем работу графа
    FMediaControl.Run;
  end;
end;

{******************************************************************************}
{** Вызов страницы свойств заданного фильтра                                 **}
{******************************************************************************}
function TdxCaptureManager.DisplayPropertyFrame(Filter: IBaseFilter;
  Handle: THandle): HResult;
var
  PropertyPages: ISpecifyPropertyPages;
  Pages: CAUUID;
  FilterInfo: TFilterInfo;
  pfilterUnk: IUnknown;
begin
  // Результат по умолчанию
  Result := E_FAIL;

  // Если фильтр не определен, то завершаем работу
  if Filter = NIL then EXIT;

  // Пытаемся найти интерфейс управления страницами свойств фильтра
  Result := Filter.QueryInterface(ISpecifyPropertyPages, PropertyPages);
                    
  if (SUCCEEDED(Result)) then
  begin
    // Получение имени фильтра и указателя на интерфейс IUnknown
    Filter.QueryFilterInfo(FilterInfo);
    Filter.QueryInterface(IUnknown, pfilterUnk);

    // Получаем массив страниц свойств
    PropertyPages.GetPages(Pages);
    PropertyPages := NIL;

    // Отображаем страницу свойств в виде модального диалога
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

    // Освобождаем память
    pfilterUnk := NIL;
    FilterInfo.pGraph := NIL;
    
    CoTaskMemFree(Pages.pElems);
  end;
end;

{******************************************************************************}
{** Вызов страницы свойств устройства работы с видео                         **}
{******************************************************************************}
function TdxCaptureManager.DisplayVideoCaptureDeviceProperty(
  Handle: THandle): HResult;
begin
  Result := DisplayPropertyFrame(FVideoCaptureFilter, Handle);
end;

{******************************************************************************}
{** Вызов страницы свойств устройства сжатия видео                           **}
{******************************************************************************}
function TdxCaptureManager.DisplayVideoCompressDeviceProperty(
  Handle: THandle): HResult;
begin
  Result := DisplayPropertyFrame(FVideoCompressFilter, Handle);
end;

{******************************************************************************}
{** Вызов страницы свойств устройства работы со звуком                       **}
{******************************************************************************}
function TdxCaptureManager.DisplayAudioCaptureDeviceProperty(
  Handle: THandle): HResult;
begin
  Result := DisplayPropertyFrame(FAudioCaptureFilter, Handle);
end;

{******************************************************************************}
{** Вызов страницы свойств устройства сжатия звука                           **}
{******************************************************************************}
function TdxCaptureManager.DisplayAudioCompressDeviceProperty(
  Handle: THandle): HResult;
begin
  Result := DisplayPropertyFrame(FAudioCompressFilter, Handle);
end;

END.
