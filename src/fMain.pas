unit fMain;

interface

uses
  System.SysUtils, System.Types, System.UITypes, System.Classes,
  System.Variants,
  FMX.Types, FMX.Controls, FMX.Forms, FMX.Graphics, FMX.Dialogs, FMX.TabControl,
  FMX.Controls.Presentation, FMX.StdCtrls, FMX.Layouts;

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
    procedure FormCreate(Sender: TObject);
    procedure btnOpenProjectClick(Sender: TObject);
    procedure btnCreateProjectClick(Sender: TObject);
    procedure ImagesLayoutResize(Sender: TObject);
  private
    FProjectChanged: boolean;
    procedure CalculeHauteurFlowLayout(fl: TFlowLayout);
    { Déclarations privées }
    procedure GoToProjectScreen;
    procedure SetProjectChanged(const Value: boolean);
    procedure LoadImagesList;
  public
    { Déclarations publiques }
    property ProjectChanged: boolean read FProjectChanged
      write SetProjectChanged;
  end;

var
  frmMain: TfrmMain;

implementation

{$R *.fmx}

uses
  System.IOUtils, uProjectGPBG;

procedure TfrmMain.btnCreateProjectClick(Sender: TObject);
begin
  TGPBGProject.Current.Clear;
  GoToProjectScreen;
end;

procedure TfrmMain.btnOpenProjectClick(Sender: TObject);
var
  filename: string;
begin
  if OpenProjectDialog.InitialDir.IsEmpty then
    OpenProjectDialog.InitialDir := tpath.GetDocumentsPath;
  // TODO : éventuellement enregistrer le dossier pour le proposer lors du lancement suivant du programme

  if (OpenProjectDialog.Execute) then
  begin
    filename := OpenProjectDialog.filename;
    if filename.Trim.IsEmpty then
      raise exception.Create('Please choose a file to open a project.');
    if not tfile.Exists(filename) then
      raise exception.Create('File ' + filename + ' doesn''t exist !');
    TGPBGProject.Current.LoadFromFile(filename);
    GoToProjectScreen;
  end;
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
begin
  // TODO : empty ImagesLayout
  // TODO : load images
end;

procedure TfrmMain.SetProjectChanged(const Value: boolean);
begin
  FProjectChanged := Value;
  btnSave.Enabled := FProjectChanged;
end;

procedure TfrmMain.CalculeHauteurFlowLayout(fl: TFlowLayout);
var
  hauteur_fl, hauteur_children: single;
  i: integer;
  ctrl: tcontrol;
begin
  if not assigned(fl) then
    exit;

  hauteur_fl := 0;
  for i := 0 to fl.ChildrenCount - 1 do
    if (fl.Children[i] is tcontrol) then
    begin
      ctrl := (fl.Children[i] as tcontrol);
      hauteur_children := ctrl.Position.Y + ctrl.Height + ctrl.Margins.bottom;
      if hauteur_fl < hauteur_children then
        hauteur_fl := hauteur_children;
    end;
  fl.Height := hauteur_fl;
end;

end.
