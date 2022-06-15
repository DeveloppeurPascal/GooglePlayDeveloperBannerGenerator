unit fMain;

interface

uses
  System.SysUtils, System.Types, System.UITypes, System.Classes,
  System.Variants,
  FMX.Types, FMX.Controls, FMX.Forms, FMX.Graphics, FMX.Dialogs, FMX.TabControl,
  FMX.Controls.Presentation, FMX.StdCtrls, FMX.Layouts, uProjectGPBG,
  Data.Bind.EngExt, FMX.Bind.DBEngExt, System.Rtti, System.Bindings.Outputs,
  FMX.Bind.Editors, Data.Bind.Components, FMX.Edit, FMX.Objects, FMX.Effects;

Const
  CBannerWidth = 4096;
  CBannerHeight = 2304;
  CIconWidth = 128;
  CIconHeight = 128;
  CIconMargin = 16;
  CIconShadowDirection = 0;
  CIconShadowDistance = 0;
  CIconRadiusX = 10;
  CIconRadiusY = 10;

type
  TfrmMain = class(TForm)
    TabControl1: TTabControl;
    tiOpenCreate: TTabItem;
    tiProject: TTabItem;
    Layout1: TLayout;
    btnCreateProject: TButton;
    btnOpenProject: TButton;
    OpenProjectDialog: TOpenDialog;
    ToolBar1: TToolBar;
    VertScrollBox1: TVertScrollBox;
    ImagesLayout: TFlowLayout;
    btnAddImage: TButton;
    btnDeleteImage: TButton;
    btnClose: TButton;
    btnSave: TButton;
    SaveProjectDialog: TSaveDialog;
    AddImageDialog: TOpenDialog;
    btnExport: TButton;
    SaveBannerDialog: TSaveDialog;
    Rectangle1: TRectangle;
    ShadowEffect1: TShadowEffect;
    Rectangle2: TRectangle;
    ShadowEffect2: TShadowEffect;
    Rectangle3: TRectangle;
    ShadowEffect3: TShadowEffect;
    procedure FormCreate(Sender: TObject);
    procedure btnOpenProjectClick(Sender: TObject);
    procedure btnCreateProjectClick(Sender: TObject);
    procedure ImagesLayoutResize(Sender: TObject);
    procedure btnCloseClick(Sender: TObject);
    procedure btnAddImageClick(Sender: TObject);
    procedure FormCloseQuery(Sender: TObject; var CanClose: Boolean);
    procedure btnSaveClick(Sender: TObject);
    procedure btnExportClick(Sender: TObject);
  private
    FProjectChanged: Boolean;
    procedure CalculeHauteurFlowLayout(fl: TFlowLayout);
    { Déclarations privées }
    procedure GoToProjectScreen;
    procedure SetProjectChanged(const Value: Boolean);
    procedure LoadImagesList;
    procedure ProjectHasChangedEvent(AProject: TGPBGProject;
      AHasChanged: Boolean);
    procedure CloseProject;
    procedure AddImageToImagesLayout(ImageIndex: Integer);
  public
    { Déclarations publiques }
    property ProjectChanged: Boolean read FProjectChanged
      write SetProjectChanged;
  end;

var
  frmMain: TfrmMain;

implementation

{$R *.fmx}

uses
  System.IOUtils, FMX.DialogService;

procedure TfrmMain.btnAddImageClick(Sender: TObject);
var
  ImgFileName: string;
  idx: Integer;
begin
  AddImageDialog.Title := 'Choose an image (' + CIconWidth.ToString + 'x' +
    CIconHeight.ToString + 'px)';

  if AddImageDialog.InitialDir.IsEmpty then
    AddImageDialog.InitialDir := tpath.GetDocumentsPath;
  // TODO : éventuellement enregistrer le dossier pour le proposer lors du lancement suivant du programme

  if AddImageDialog.Execute then
  begin
    ImgFileName := AddImageDialog.FileName;
    if ImgFileName.IsEmpty then
      raise exception.Create('Empty file name. Can''t do anything with this !');
    if not tfile.Exists(ImgFileName) then
      raise exception.Create('This file doesn''t exist. What else ?');
    idx := TGPBGProject.Current.ImagesList.AddImageFromFile(ImgFileName);
    if (idx < 0) then
      raise exception.Create('Image not added to the project. Unknown reason.');
    AddImageToImagesLayout(idx);
    CalculeHauteurFlowLayout(ImagesLayout);
  end;
end;

procedure TfrmMain.btnCloseClick(Sender: TObject);
begin
  if TGPBGProject.Current.HasChanged then
    TDialogService.MessageDialog
      ('Project not saved. Do you want to close without saving its changes ?',
      tmsgdlgtype.mtConfirmation, [tmsgdlgbtn.mbYes, tmsgdlgbtn.mbNo],
      tmsgdlgbtn.mbNo, 0,
      procedure(const AResult: TModalResult)
      begin
        if AResult = mryes then
          CloseProject;
      end)
  else
    CloseProject;
end;

procedure TfrmMain.btnCreateProjectClick(Sender: TObject);
begin
  TGPBGProject.Current.onHasChangedEvent := ProjectHasChangedEvent;
  TGPBGProject.Current.Clear;
  GoToProjectScreen;
end;

procedure TfrmMain.btnExportClick(Sender: TObject);
var
  FileName: string;
  Banner: TRectangle;
  BMP: TBitmap;
  R: TRectangle;
  S: TShadowEffect;
  x, y: single;
begin
  if SaveBannerDialog.InitialDir.IsEmpty then
    if TGPBGProject.Current.FileName.IsEmpty then
      SaveBannerDialog.InitialDir := tpath.GetDocumentsPath
    else
    begin
      SaveBannerDialog.InitialDir := tpath.GetDirectoryName
        (TGPBGProject.Current.FileName);
      SaveBannerDialog.FileName := tpath.Combine(SaveBannerDialog.InitialDir,
        tpath.GetFileNameWithoutExtension(TGPBGProject.Current.FileName) + '-' +
        CBannerWidth.ToString + 'x' + CBannerHeight.ToString + '.png');
    end;
  // TODO : éventuellement enregistrer le dossier pour le proposer lors du lancement suivant du programme

  if SaveBannerDialog.Execute then
  begin
    FileName := SaveBannerDialog.FileName;
    if FileName.Trim.IsEmpty then
      raise exception.Create
        ('Please choose a file name for the exported banner.');

    Banner := TRectangle.Create(self);
    try
      Banner.Parent := self;
      Banner.Width := CBannerWidth;
      Banner.Height := CBannerHeight;
      Banner.Stroke.Kind := tbrushkind.None;
      Banner.fill.Kind := tbrushkind.None;

      y := -random(CIconHeight);
      while (y < Banner.Height) do
      begin
        x := -random(CIconWidth);
        while (x < Banner.Width) do
        begin
          R := TRectangle.Create(Banner);
          R.Parent := Banner;
          R.Position.x := x;
          R.Position.y := y;
          R.Width := CIconWidth;
          R.Height := CIconHeight;
          R.Stroke.Kind := tbrushkind.None;
          R.fill.Kind := tbrushkind.Bitmap;
          R.fill.Bitmap.WrapMode := twrapmode.TileStretch;
          R.fill.Bitmap.Bitmap.Assign(TGPBGProject.Current.ImagesList.GetImage
            (random(TGPBGProject.Current.ImagesList.count)).Bitmap);
          R.XRadius := CIconRadiusX;
          R.YRadius := CIconRadiusY;
          S := TShadowEffect.Create(R);
          S.Parent := R;
          S.Distance := CIconShadowDistance;
          S.Direction := CIconShadowDirection;
          x := x + CIconWidth + CIconMargin;
        end;
        y := y + CIconHeight + CIconMargin;
      end;

      BMP := Banner.MakeScreenshot;
      try
        BMP.SaveToFile(FileName);
      finally
        BMP.free;
      end;
    finally
      Banner.free;
    end;

    ShowMessage('Export done.');
  end;
end;

procedure TfrmMain.btnOpenProjectClick(Sender: TObject);
var
  FileName: string;
begin
  if OpenProjectDialog.InitialDir.IsEmpty then
    OpenProjectDialog.InitialDir := tpath.GetDocumentsPath;
  // TODO : éventuellement enregistrer le dossier pour le proposer lors du lancement suivant du programme

  if (OpenProjectDialog.Execute) then
  begin
    FileName := OpenProjectDialog.FileName;
    if FileName.Trim.IsEmpty then
      raise exception.Create('Please choose a file to open a project.');
    if not tfile.Exists(FileName) then
      raise exception.Create('File ' + FileName + ' doesn''t exist !');
    TGPBGProject.Current.onHasChangedEvent := ProjectHasChangedEvent;
    TGPBGProject.Current.LoadFromFile(FileName);
    GoToProjectScreen;
  end;
end;

procedure TfrmMain.btnSaveClick(Sender: TObject);
var
  FileName: string;
begin
  if TGPBGProject.Current.FileName.IsEmpty then
  begin
    if SaveProjectDialog.InitialDir.IsEmpty then
      SaveProjectDialog.InitialDir := tpath.GetDocumentsPath;
    // TODO : éventuellement enregistrer le dossier pour le proposer lors du lancement suivant du programme
    if SaveProjectDialog.Execute then
    begin
      FileName := SaveProjectDialog.FileName;
      if FileName.Trim.IsEmpty then
        raise exception.Create('Please choose a file to save this project.');
      TGPBGProject.Current.SaveToFile(FileName);
    end;
  end
  else
    TGPBGProject.Current.SaveToFile;
end;

procedure TfrmMain.FormCloseQuery(Sender: TObject; var CanClose: Boolean);
begin
  if TGPBGProject.Current.HasChanged then
  begin
    TDialogService.MessageDialog
      ('Project not saved. Do you want to close without saving its changes ?',
      tmsgdlgtype.mtConfirmation, [tmsgdlgbtn.mbYes, tmsgdlgbtn.mbNo],
      tmsgdlgbtn.mbNo, 0,
      procedure(const AResult: TModalResult)
      begin
        if AResult = mryes then
        begin
          CloseProject;
          Close;
        end;
      end);
    CanClose := false;
  end
  else
    CanClose := true;
end;

procedure TfrmMain.FormCreate(Sender: TObject);
begin
  TabControl1.ActiveTab := tiOpenCreate;
end;

procedure TfrmMain.GoToProjectScreen;
begin
  ProjectChanged := false;
  btnDeleteImage.Enabled := false;
  LoadImagesList;
  TabControl1.ActiveTab := tiProject;
end;

procedure TfrmMain.ImagesLayoutResize(Sender: TObject);
begin
  CalculeHauteurFlowLayout(ImagesLayout);
end;

procedure TfrmMain.LoadImagesList;
var
  nb: Integer;
  i: Integer;
begin
  // Empty ImagesLayout
  while ImagesLayout.ChildrenCount > 0 do
    ImagesLayout.Children[0].free;

  // Add images from project
  for i := 0 to TGPBGProject.Current.ImagesList.count - 1 do
    AddImageToImagesLayout(i);

  // Resize TFlowLayout (ImagesLayout)
  CalculeHauteurFlowLayout(ImagesLayout);
end;

procedure TfrmMain.ProjectHasChangedEvent(AProject: TGPBGProject;
AHasChanged: Boolean);
begin
  ProjectChanged := AHasChanged;
end;

procedure TfrmMain.SetProjectChanged(const Value: Boolean);
begin
  FProjectChanged := Value;
  btnSave.Enabled := FProjectChanged;
  btnExport.Enabled := TGPBGProject.Current.ImagesList.count > 0;
end;

procedure TfrmMain.CalculeHauteurFlowLayout(fl: TFlowLayout);
var
  hauteur_fl, hauteur_children: single;
  i: Integer;
  ctrl: tcontrol;
begin
  if not assigned(fl) then
    exit;

  hauteur_fl := 0;
  for i := 0 to fl.ChildrenCount - 1 do
    if (fl.Children[i] is tcontrol) then
    begin
      ctrl := (fl.Children[i] as tcontrol);
      hauteur_children := ctrl.Position.y + ctrl.Height + ctrl.Margins.bottom;
      if hauteur_fl < hauteur_children then
        hauteur_fl := hauteur_children;
    end;
  fl.Height := hauteur_fl;
end;

procedure TfrmMain.CloseProject;
begin
  TGPBGProject.Current.Clear;
  TabControl1.ActiveTab := tiOpenCreate;
end;

procedure TfrmMain.AddImageToImagesLayout(ImageIndex: Integer);
var
  img: TImage;
begin
  if (ImageIndex < 0) or (ImageIndex >= TGPBGProject.Current.ImagesList.count)
  then
    exit;

  img := TImage.Create(self);
  img.Parent := ImagesLayout;
  img.Width := CIconWidth;
  img.Height := CIconHeight;
  img.Margins.Left := 5;
  img.Margins.right := 5;
  img.Margins.top := 5;
  img.Margins.bottom := 5;
  img.Bitmap.Assign(TGPBGProject.Current.ImagesList.GetImage
    (ImageIndex).Bitmap);
  // TODO : ajouter le traitement du clic sur l'image
end;

initialization

TDialogService.PreferredMode := TDialogService.TPreferredMode.Async;

randomize;

{$IFDEF DEBUG}
ReportMemoryLeaksOnShutdown := true;
{$ENDIF}

end.
