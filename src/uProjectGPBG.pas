unit uProjectGPBG;

interface

uses
  System.Classes, System.Generics.Collections, fmx.Graphics;

type
  TGPBGProject = class;

  TGPBGHeaderBlock = class
  public
    procedure LoadFromStream(s: TStream);
    procedure SaveToStream(s: TStream);
  end;

  TGPBGGlobalBlock = class
  private const
    CGlobalBlockVersion = 1;

  var
    FProject: TGPBGProject;
  public
    procedure Clear;
    procedure LoadFromStream(s: TStream);
    procedure SaveToStream(s: TStream);
    constructor Create(ProjectOwner: TGPBGProject);
    destructor Destroy; override;
  end;

  TGPBGImageBlock = class
  private const
    CImageBlockVersion = 1;

  var
    FProject: TGPBGProject;
  protected
    FBitmap: TBitmap;
  public
    property Bitmap: TBitmap read FBitmap;
    procedure LoadFromStream(s: TStream);
    procedure SaveToStream(s: TStream);
    constructor Create(ProjectOwner: TGPBGProject);
    destructor Destroy; override;
  end;

  TGPBGImageBlockList = TObjectList<TGPBGImageBlock>;

  TGPBGImagesListBlock = class
  private const
    CImagesListBlockVersion = 1;

  var
    FProject: TGPBGProject;
    function GetCount: integer;
  protected
    FImages: TGPBGImageBlockList;
  public
    property Count: integer read GetCount;
    function GetImage(index: integer): TGPBGImageBlock;
    function AddImageFromFile(FileName: string): integer;
    procedure DeleteImage(index: integer);
    procedure Clear;
    procedure LoadFromStream(s: TStream);
    procedure SaveToStream(s: TStream);
    constructor Create(ProjectOwner: TGPBGProject);
    destructor Destroy; override;
  end;

  TGPBGHasChangedEvent = procedure(Project: TGPBGProject; HasChanged: boolean)
    of object;

  TGPBGProject = class
  private Const
    CGPBGFileVersion = 1;
    function GetProjectName: string;

  var
    FonHasChangedEvent: TGPBGHasChangedEvent;
    FFileName: string;
    FHasChanged: boolean;
    procedure SetonHasChangedEvent(const Value: TGPBGHasChangedEvent);
    procedure SetHasChanged(const Value: boolean);
  protected
    FGlobal: TGPBGGlobalBlock;
    FImagesList: TGPBGImagesListBlock;
  public
    property HasChanged: boolean read FHasChanged write SetHasChanged;
    property onHasChangedEvent: TGPBGHasChangedEvent read FonHasChangedEvent
      write SetonHasChangedEvent;
    property FileName: string read FFileName;
    property ProjectName: string read GetProjectName;
    property ImagesList: TGPBGImagesListBlock read FImagesList;
    class function Current: TGPBGProject;
    procedure LoadFromFile(FileName: string = '');
    procedure LoadFromStream(s: TStream);
    procedure SaveToFile(FileName: string = '');
    procedure SaveToStream(s: TStream);
    procedure Clear;
    constructor Create;
    destructor Destroy; override;
  end;

implementation

uses
  System.SysUtils, System.IOUtils, System.UITypes;

var
  Project: TGPBGProject;

  { TProject }

procedure TGPBGProject.Clear;
begin
  FFileName := '';
  FGlobal.Clear;
  FImagesList.Clear;
  HasChanged := false; // en dernier !!! important !!!
end;

constructor TGPBGProject.Create;
begin
  FonHasChangedEvent := nil;
  FGlobal := TGPBGGlobalBlock.Create(self);
  FImagesList := TGPBGImagesListBlock.Create(self);
  Clear;
end;

class function TGPBGProject.Current: TGPBGProject;
begin
  if not assigned(Project) then
    Project := TGPBGProject.Create;
  result := Project;
end;

destructor TGPBGProject.Destroy;
begin
  FImagesList.free;
  FGlobal.free;
  inherited;
end;

function TGPBGProject.GetProjectName: string;
begin
  result := tpath.GetFileNameWithoutExtension(TGPBGProject.Current.FileName);
  if result.IsEmpty then
    result := 'Project With No Name';
end;

procedure TGPBGProject.LoadFromFile(FileName: string);
var
  F: TFileStream;
begin
  if (FileName.IsEmpty) then
  begin
    if (FFileName.IsEmpty) then
      raise exception.Create
        ('Unknow project file name. Can''t load the project !');
  end
  else if not tfile.Exists(FileName) then
    raise exception.Create('File ' + FileName + ' doesn''t exist !');

  Clear;
  F := TFileStream.Create(FileName, fmOpenRead);
  try
    LoadFromStream(F);
    FFileName := FileName;
    HasChanged := false;
  finally
    F.free;
  end;
end;

procedure TGPBGProject.LoadFromStream(s: TStream);
var
  FHeader: TGPBGHeaderBlock;
  Version: byte;
begin
  if not assigned(s) then
    raise exception.Create('Stream not assigned. Can''t load the project.');

  Clear;

  FHeader := TGPBGHeaderBlock.Create;
  try
    FHeader.LoadFromStream(s);
  finally
    FHeader.free;
  end;

  if (s.Read(Version, sizeof(Version)) <> sizeof(Version)) then
    raise exception.Create('Corrupted data !');

  if (Version < 1) or (Version > CGPBGFileVersion) then
    raise exception.Create
      ('Unknown file format. Wrong version number. Please update this program.');

  FGlobal.LoadFromStream(s);
  FImagesList.LoadFromStream(s);

  HasChanged := false;
end;

procedure TGPBGProject.SaveToFile(FileName: string);
var
  F: TFileStream;
begin
  if (FileName.IsEmpty) then
  begin
    if (FFileName.IsEmpty) then
      raise exception.Create
        ('Unknow project file name. Can''t save the project !');
  end
  else
    FFileName := FileName;

  F := TFileStream.Create(FFileName, fmcreate);
  try
    SaveToStream(F);
    HasChanged := false;
  finally
    F.free;
  end;
end;

procedure TGPBGProject.SaveToStream(s: TStream);
var
  FHeader: TGPBGHeaderBlock;
  Version: byte;
begin
  if not assigned(s) then
    raise exception.Create('Stream not assigned. Can''t save the project.');

  FHeader := TGPBGHeaderBlock.Create;
  try
    FHeader.SaveToStream(s);
  finally
    FHeader.free;
  end;

  Version := CGPBGFileVersion;
  s.Write(Version, sizeof(Version));

  FGlobal.SaveToStream(s);
  FImagesList.SaveToStream(s);

  HasChanged := false;
end;

procedure TGPBGProject.SetHasChanged(const Value: boolean);
begin
  FHasChanged := Value;
  if assigned(FonHasChangedEvent) then
    FonHasChangedEvent(self, FHasChanged);
end;

procedure TGPBGProject.SetonHasChangedEvent(const Value: TGPBGHasChangedEvent);
begin
  FonHasChangedEvent := Value;
end;

{ TGPBGHeaderBlock }

procedure TGPBGHeaderBlock.LoadFromStream(s: TStream);
var
  b: byte;
  h: string;
begin
  h := 'GPBG';
  for var i := 0 to h.Length - 1 do
  begin
    if (s.Read(b, sizeof(b)) <> sizeof(b)) then
      raise exception.Create('Corrupted data !');
    if (b <> ord(h.Chars[i])) then
      raise exception.Create('Wrong file format !');
  end;
end;

procedure TGPBGHeaderBlock.SaveToStream(s: TStream);
var
  b: byte;
  h: string;
begin
  h := 'GPBG';
  for var i := 0 to h.Length - 1 do
  begin
    b := ord(h.Chars[i]);
    s.Write(b, sizeof(b));
  end;
end;

{ TGPBGGlobalBlock }

procedure TGPBGGlobalBlock.Clear;
begin
  FProject.HasChanged := true;
end;

constructor TGPBGGlobalBlock.Create(ProjectOwner: TGPBGProject);
begin
  FProject := ProjectOwner;
end;

destructor TGPBGGlobalBlock.Destroy;
begin
  inherited;
end;

procedure TGPBGGlobalBlock.LoadFromStream(s: TStream);
var
  Version: byte;
begin
  if (s.Read(Version, sizeof(Version)) <> sizeof(Version)) then
    raise exception.Create('Corrupted data !');

  if (Version < 1) or (Version > CGlobalBlockVersion) then
    raise exception.Create
      ('Unknown block format. Wrong version number. Please update this program.');

  Clear;
  // Load global datas
end;

procedure TGPBGGlobalBlock.SaveToStream(s: TStream);
var
  Version: byte;
begin
  Version := CGlobalBlockVersion;
  s.Write(Version, sizeof(Version));
end;

{ TGPBGImagesListBlock }

function TGPBGImagesListBlock.AddImageFromFile(FileName: string): integer;
var
  img: TGPBGImageBlock;
begin
  result := -1;
  if not tfile.Exists(FileName) then
    raise exception.Create('File ' + FileName + ' doesn''t exist.');
  img := TGPBGImageBlock.Create(FProject);
  img.Bitmap.LoadFromFile(FileName);
  result := FImages.Add(img);
  FProject.HasChanged := true;
end;

procedure TGPBGImagesListBlock.Clear;
begin
  FImages.Clear;
  FProject.HasChanged := true;
end;

constructor TGPBGImagesListBlock.Create(ProjectOwner: TGPBGProject);
begin
  FProject := ProjectOwner;
  FImages := TGPBGImageBlockList.Create;
end;

procedure TGPBGImagesListBlock.DeleteImage(index: integer);
begin
  if (index < 0) or (index >= FImages.Count) then
    exit;
  FImages.Delete(index);
  FProject.HasChanged := true;
end;

destructor TGPBGImagesListBlock.Destroy;
begin
  FImages.Destroy;
  inherited;
end;

function TGPBGImagesListBlock.GetCount: integer;
begin
  result := FImages.Count;
end;

function TGPBGImagesListBlock.GetImage(index: integer): TGPBGImageBlock;
begin
  if (index < 0) or (index >= FImages.Count) then
    result := nil
  else
    result := FImages[index];
end;

procedure TGPBGImagesListBlock.LoadFromStream(s: TStream);
var
  Version: byte;
  Nbimages: Word;
  img: TGPBGImageBlock;
begin
  if (s.Read(Version, sizeof(Version)) <> sizeof(Version)) then
    raise exception.Create('Corrupted data !');

  if (Version < 1) or (Version > CImagesListBlockVersion) then
    raise exception.Create
      ('Unknown block format. Wrong version number. Please update this program.');

  Clear;

  if (s.Read(Nbimages, sizeof(Nbimages)) <> sizeof(Nbimages)) then
    raise exception.Create('Corrupted data !');

  for var i := 0 to Nbimages - 1 do
  begin
    img := TGPBGImageBlock.Create(FProject);
    img.LoadFromStream(s);
    FImages.Add(img);
  end;
end;

procedure TGPBGImagesListBlock.SaveToStream(s: TStream);
var
  Version: byte;
  Nbimages: Word;
begin
  Version := CImagesListBlockVersion;
  s.Write(Version, sizeof(Version));

  Nbimages := FImages.Count;
  s.Write(Nbimages, sizeof(Nbimages));

  for var i := 0 to FImages.Count - 1 do
    FImages[i].SaveToStream(s);
end;

{ TGPBGImageBlock }

constructor TGPBGImageBlock.Create(ProjectOwner: TGPBGProject);
begin
  FProject := ProjectOwner;
  FBitmap := TBitmap.Create;
end;

destructor TGPBGImageBlock.Destroy;
begin
  FBitmap.free;
  inherited;
end;

procedure TGPBGImageBlock.LoadFromStream(s: TStream);
var
  Version: byte;
  ImgSize: cardinal;
  ms: tmemorystream;
begin
  if (s.Read(Version, sizeof(Version)) <> sizeof(Version)) then
    raise exception.Create('Corrupted data !');

  if (Version < 1) or (Version > CImageBlockVersion) then
    raise exception.Create
      ('Unknown block format. Wrong version number. Please update this program.');

  if (s.Read(ImgSize, sizeof(ImgSize)) <> sizeof(ImgSize)) then
    raise exception.Create('Corrupted data !');

  FBitmap.Clear(TAlphaColors.black);
  if (ImgSize > 0) then
  begin
    ms := tmemorystream.Create;
    try
      if (ms.CopyFrom(s, ImgSize) <> ImgSize) then
        raise exception.Create('Corrupted data !');
      ms.Position := 0;
      FBitmap.LoadFromStream(ms);
    finally
      ms.free;
    end;
  end;
end;

procedure TGPBGImageBlock.SaveToStream(s: TStream);
var
  Version: byte;
  ImgSize: cardinal;
  ms: tmemorystream;
begin
  Version := CImageBlockVersion;
  s.Write(Version, sizeof(Version));
  ms := tmemorystream.Create;
  try
    FBitmap.SaveToStream(ms);
    ImgSize := ms.Size;
    s.Write(ImgSize, sizeof(ImgSize));
    ms.Position := 0;
    s.CopyFrom(ms, ImgSize);
  finally
    ms.free;
  end;
end;

initialization

Project := nil;

finalization

Project.free;

end.
