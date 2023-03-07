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
  CBannerSizeMax = 1024 * 1024 * 2; // 2Mo, Google Play constraint

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
    Label1: TLabel;
    procedure FormCreate(Sender: TObject);
    procedure btnOpenProjectClick(Sender: TObject);
    procedure btnCreateProjectClick(Sender: TObject);
    procedure ImagesLayoutResize(Sender: TObject);
    procedure btnCloseClick(Sender: TObject);
    procedure btnAddImageClick(Sender: TObject);
    procedure FormCloseQuery(Sender: TObject; var CanClose: Boolean);
    procedure btnSaveClick(Sender: TObject);
    procedure btnExportClick(Sender: TObject);
    procedure btnDeleteImageClick(Sender: TObject);
    procedure FormKeyDown(Sender: TObject; var Key: Word; var KeyChar: Char;
      Shift: TShiftState);
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
    procedure RefreshFormCaption;
    procedure ImageClickEvent(Sender: TObject);
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
  System.IOUtils, FMX.DialogService, FMX.Platform;

type
  TImageWithStroke = class(timage)
  private
    FisChecked: Boolean;
    FonImageClick: tnotifyevent;
    procedure SetisChecked(const Value: Boolean);
    procedure SetonImageClick(const Value: tnotifyevent);
  protected
    procedure ImageClick(Sender: TObject);
  public
    property isChecked: Boolean read FisChecked write SetisChecked;
    property onImageClick: tnotifyevent read FonImageClick
      write SetonImageClick;
    constructor Create(AOwner: TComponent); override;
  end;

procedure TfrmMain.btnAddImageClick(Sender: TObject);
var
  ImgFileName: string;
  idx: Integer;
begin
  AddImageDialog.Title := 'Choose an image (' + CIconWidth.ToString + 'x' +
    CIconHeight.ToString + 'px)';

  if not string(AddImageDialog.FileName).IsEmpty then
  begin
    AddImageDialog.InitialDir := tpath.GetDirectoryName
      (AddImageDialog.FileName);
    AddImageDialog.FileName := '';
  end
  else if AddImageDialog.InitialDir.IsEmpty then
    AddImageDialog.InitialDir := tpath.GetPicturesPath;
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

procedure TfrmMain.btnDeleteImageClick(Sender: TObject);
var
  img: TImageWithStroke;
  i: Integer;
begin
  for i := ImagesLayout.ChildrenCount - 1 downto 0 do
    if (ImagesLayout.Children[i] is TImageWithStroke) and
      (ImagesLayout.Children[i] as TImageWithStroke).isChecked then
    begin
      img := ImagesLayout.Children[i] as TImageWithStroke;
      TGPBGProject.Current.ImagesList.DeleteImage(img.tag);
      img.Free;
    end;
  LoadImagesList;
end;

procedure TfrmMain.btnExportClick(Sender: TObject);
var
  FileName: string;
  Banner: TRectangle;
  BMP: TBitmap;
  R: TRectangle;
  S: TShadowEffect;
  x, y: single;
  FMXScreenService: IFMXScreenService;
  BMPScale: single;
begin
  if not string(SaveBannerDialog.FileName).IsEmpty then
  begin
    SaveBannerDialog.InitialDir := tpath.GetDirectoryName
      (SaveBannerDialog.FileName);
    SaveBannerDialog.FileName := tpath.GetFileName(SaveBannerDialog.FileName);
  end
  else if TGPBGProject.Current.FileName.IsEmpty then
    SaveBannerDialog.InitialDir := tpath.GetDocumentsPath
  else
  begin
    SaveBannerDialog.InitialDir := tpath.GetDirectoryName
      (TGPBGProject.Current.FileName);
    SaveBannerDialog.FileName := tpath.GetFileNameWithoutExtension
      (TGPBGProject.Current.FileName) + '-' + CBannerWidth.ToString + 'x' +
      CBannerHeight.ToString + '.png';
  end;
  // TODO : éventuellement enregistrer le dossier pour le proposer lors du lancement suivant du programme

  if SaveBannerDialog.Execute then
  begin
    FileName := SaveBannerDialog.FileName;
    if FileName.Trim.IsEmpty then
      raise exception.Create
        ('Please choose a file name for the exported banner.');

    if SupportsPlatformService(IFMXScreenService, FMXScreenService) then
      BMPScale := FMXScreenService.GetScreenScale
    else
      BMPScale := 1;

    // showmessage(bmpscale.ToString);exit;

    Banner := TRectangle.Create(self);
    try
      Banner.Parent := self;
      Banner.Width := CBannerWidth / BMPScale;
      Banner.Height := CBannerHeight / BMPScale;
      Banner.Stroke.Kind := tbrushkind.None;
      Banner.fill.Kind := tbrushkind.Solid;
      Banner.fill.Color := talphacolors.White;
      // TODO : add an option to choose this color

      y := -random(CIconHeight) / BMPScale;
      while (y < Banner.Height) do
      begin
        x := -random(CIconWidth) / BMPScale;
        while (x < Banner.Width) do
        begin
          R := TRectangle.Create(Banner);
          R.Parent := Banner;
          R.Position.x := x;
          R.Position.y := y;
          R.Width := CIconWidth / BMPScale;
          R.Height := CIconHeight / BMPScale;
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
          x := x + (CIconWidth + CIconMargin) / BMPScale;
        end;
        y := y + (CIconHeight + CIconMargin) / BMPScale;
      end;

      BMP := Banner.MakeScreenshot;
      // showmessage (bmp.BitmapScale.tostring);
      try
        BMP.SaveToFile(FileName);
        if (tfile.GetSize(FileName) >= CBannerSizeMax) then
        begin
          raise exception.Create('PNG file is too big (more than 2Mb) !');
          // TODO : à changer en JPEG si on trouve comment changer le degrès de compression de l'image (et mettre un background)
          // tfile.Delete(FileName);
          // FileName := tpath.ChangeExtension(FileName, 'jpg');
          // BMP.SaveToFile(FileName);
        end;
      finally
        BMP.Free;
      end;
    finally
      Banner.Free;
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
    OpenProjectDialog.InitialDir := tpath.GetDirectoryName
      (OpenProjectDialog.FileName);
    OpenProjectDialog.FileName := '';
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
  RefreshFormCaption;
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
{$IFNDEF DEBUG}
  Label1.Free;
{$ENDIF}
end;

procedure TfrmMain.FormKeyDown(Sender: TObject; var Key: Word;
var KeyChar: Char; Shift: TShiftState);
begin
  if Key = vkEscape then
  begin
    Key := 0;
    KeyChar := #0;
    if TabControl1.ActiveTab = tiOpenCreate then
      Close
    else if TabControl1.ActiveTab = tiProject then
      btnCloseClick(btnClose);
  end
  else if (Key = vkS) and ([ssctrl] = Shift) and
    (TabControl1.ActiveTab = tiProject) then // Ctrl+S
  begin
    Key := 0;
    KeyChar := #0;
    if btnSave.Enabled then
      btnSaveClick(btnSave);
  end;

{$IFDEF DEBUG}
  // Log the pressed key(s) in a footer label
  Label1.Text := Key.ToString + ' "' + KeyChar + '"';
  if ssctrl in Shift then
    Label1.Text := Label1.Text + ' Ctrl';
  if ssShift in Shift then
    Label1.Text := Label1.Text + ' Shift';
  if ssAlt in Shift then
    Label1.Text := Label1.Text + ' Alt';
{$ENDIF}
end;

procedure TfrmMain.GoToProjectScreen;
begin
  tagstring := caption;
  RefreshFormCaption;
  ProjectChanged := false;
  btnDeleteImage.Enabled := false;
  LoadImagesList;
  TabControl1.ActiveTab := tiProject;
end;

procedure TfrmMain.ImageClickEvent(Sender: TObject);
var
  img: TImageWithStroke;
  i: Integer;
  ImgChecked: Boolean;
begin
  ImgChecked := false;
  if (Sender is TImageWithStroke) and (Sender as TImageWithStroke).isChecked
  then
    ImgChecked := true
  else
  begin
    for i := 0 to ImagesLayout.ChildrenCount - 1 do
      if (ImagesLayout.Children[i] is TImageWithStroke) and
        (ImagesLayout.Children[i] as TImageWithStroke).isChecked then
      begin
        ImgChecked := true;
        break;
      end;
  end;

  btnDeleteImage.Enabled := ImgChecked;
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
    ImagesLayout.Children[0].Free;

  // Add images from project
  for i := 0 to TGPBGProject.Current.ImagesList.count - 1 do
    AddImageToImagesLayout(i);

  ImageClickEvent(nil);

  // Resize TFlowLayout (ImagesLayout)
  CalculeHauteurFlowLayout(ImagesLayout);
end;

procedure TfrmMain.ProjectHasChangedEvent(AProject: TGPBGProject;
AHasChanged: Boolean);
begin
  ProjectChanged := AHasChanged;
end;

procedure TfrmMain.RefreshFormCaption;
begin
  caption := tagstring + ' - ' + TGPBGProject.Current.ProjectName;
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
  AddImageDialog.FileName := '';
  AddImageDialog.InitialDir := '';
  SaveProjectDialog.FileName := '';
  SaveProjectDialog.InitialDir := '';
  SaveBannerDialog.FileName := '';
  SaveBannerDialog.InitialDir := '';
  caption := tagstring;
  TabControl1.ActiveTab := tiOpenCreate;
end;

procedure TfrmMain.AddImageToImagesLayout(ImageIndex: Integer);
var
  img: TImageWithStroke;
begin
  if (ImageIndex < 0) or (ImageIndex >= TGPBGProject.Current.ImagesList.count)
  then
    exit;

  img := TImageWithStroke.Create(self);
  img.Parent := ImagesLayout;
  img.Width := CIconWidth;
  img.Height := CIconHeight;
  img.Margins.Left := 5;
  img.Margins.right := 5;
  img.Margins.top := 5;
  img.Margins.bottom := 5;
  img.Bitmap.Assign(TGPBGProject.Current.ImagesList.GetImage
    (ImageIndex).Bitmap);
  img.onImageClick := ImageClickEvent;
  img.tag := ImageIndex;
end;

{ TImageWithStroke }

constructor TImageWithStroke.Create(AOwner: TComponent);
begin
  inherited;
  tagobject := nil;
  onImageClick := nil;
  FisChecked := false;
  onclick := ImageClick;
  hittest := true;
end;

procedure TImageWithStroke.ImageClick(Sender: TObject);
begin
  isChecked := not isChecked;
  if assigned(onImageClick) then
    onImageClick(self);
end;

procedure TImageWithStroke.SetisChecked(const Value: Boolean);
var
  R: TRectangle;
begin
  if FisChecked = Value then
    exit;

  FisChecked := Value;
  if FisChecked then
  begin
    R := TRectangle.Create(self);
    R.Parent := self;
    R.Align := talignlayout.Client;
    R.Stroke.Kind := tbrushkind.Solid;
    R.Stroke.Color := talphacolors.red;
    R.Stroke.Dash := tstrokedash.DashDotDot;
    R.Stroke.Thickness := 4;
    R.fill.Kind := tbrushkind.Solid;
    R.fill.Color := talphacolors.White;
    R.Opacity := 0.3;
    R.hittest := false;
    R.Margins.top := -R.Stroke.Thickness / 2;
    R.Margins.right := R.Margins.top;
    R.Margins.bottom := R.Margins.top;
    R.Margins.Left := R.Margins.top;
    tagobject := R;
  end
  else if assigned(tagobject) and (tagobject is TRectangle) then
  begin
    (tagobject as TRectangle).Free;
    tagobject := nil;
  end;
end;

procedure TImageWithStroke.SetonImageClick(const Value: tnotifyevent);
begin
  FonImageClick := Value;
end;

initialization

TDialogService.PreferredMode := TDialogService.TPreferredMode.Async;

randomize;

{$IFDEF DEBUG}
ReportMemoryLeaksOnShutdown := true;
{$ENDIF}

end.
