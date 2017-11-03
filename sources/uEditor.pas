unit uEditor;

{$I SynEdit.inc}

interface

uses
  Windows, Messages, SysUtils, Classes, Graphics, Controls, Forms, Menus,
  uEditAppIntfs, SynEdit, SynEditTypes, SynEditMiscProcs,
  SynEditMiscClasses, SynEditSearch, SynUnicode, ExtCtrls;

type
  TEditorKind = (ekBorderless, ekInTabsheet, ekMDIChild);

  TEditor = class;

  TEditorForm = class(TForm)
    SynEditor: TSynEdit;
    pmnuEditor: TPopupMenu;
    lmiEditCut: TMenuItem;
    lmiEditCopy: TMenuItem;
    lmiEditPaste: TMenuItem;
    lmiEditDelete: TMenuItem;
    N1: TMenuItem;
    lmiEditSelectAll: TMenuItem;
    lmiEditUndo: TMenuItem;
    lmiEditRedo: TMenuItem;
    N2: TMenuItem;
    SynEditSearch1: TSynEditSearch;
    Panel1: TPanel;
    Splitter1: TSplitter;
    procedure SynEditorReplaceText(Sender: TObject;
      const ASearch, AReplace: string; Line, Column: Integer;
      var Action: TSynReplaceAction);
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
    procedure FormCloseQuery(Sender: TObject; var CanClose: Boolean);
    procedure FormDestroy(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure FormActivate(Sender: TObject);
    procedure FormDeactivate(Sender: TObject);
    procedure SynEditorChange(Sender: TObject);
    procedure SynEditorEnter(Sender: TObject);
    procedure SynEditorExit(Sender: TObject);
    procedure SynEditorStatusChange(Sender: TObject;
      Changes: TSynStatusChanges);
  private
    fEditor: TEditor;
    fKind: TEditorKind;
  private
    fSearchFromCaret: Boolean;
    function DoAskSaveChanges: Boolean;
    procedure DoAssignInterfacePointer(AActive: Boolean);
    function DoSave: Boolean;
    function DoSaveFile: Boolean;
    function DoSaveAs: Boolean;
    procedure DoSearchReplaceText(AReplace: Boolean; ABackwards: Boolean);
    procedure DoUpdateCaption;
    procedure DoUpdateHighlighter;
    procedure ShowSearchReplaceDialog(AReplace: Boolean);
  public
    procedure DoActivate;
  end;

  TEditor = class(TInterfacedObject, IEditor, IEditCommands, IFileCommands,
    ISearchCommands)
  private
    // IEditor implementation
    procedure Activate;
    function AskSaveChanges: Boolean;
    procedure Close;
    function GetCaretPos: TPoint;
    function GetEditorState: string;
    function GetFileName: string;
    function GetFileTitle: string;
    function GetModified: Boolean;
    procedure OpenFile(AFileName: string);
    // IEditCommands implementation
    function CanCopy: Boolean;
    function CanCut: Boolean;
    function IEditCommands.CanDelete = CanCut;
    function CanPaste: Boolean;
    function CanRedo: Boolean;
    function CanSelectAll: Boolean;
    function CanUndo: Boolean;
    procedure ExecCopy;
    procedure ExecCut;
    procedure ExecDelete;
    procedure ExecPaste;
    procedure ExecRedo;
    procedure ExecSelectAll;
    procedure ExecUndo;
    // IFileCommands implementation
    function CanClose: Boolean;
    function CanPrint: Boolean;
    function CanSave: Boolean;
    function CanSaveAs: Boolean;
    procedure IFileCommands.ExecClose = Close;
    procedure ExecPrint;
    procedure ExecSave;
    procedure ExecSaveAs;
    // ISearchCommands implementation
    function CanFind: Boolean;
    function CanFindNext: Boolean;
    function ISearchCommands.CanFindPrev = CanFindNext;
    function CanReplace: Boolean;
    procedure ExecFind;
    procedure ExecFindNext;
    procedure ExecFindPrev;
    procedure ExecReplace;
  private
    fFileName: string;
    fForm: TEditorForm;
    fHasSelection: Boolean;
    fIsEmpty: Boolean;
    fIsReadOnly: Boolean;
    fModified: Boolean;
    fUntitledNumber: Integer;
    constructor Create(AForm: TEditorForm);
    procedure DoSetFileName(AFileName: string);
  end;

implementation

{$R *.DFM}

uses
  ComCtrls, uCommands, uSearchText, uReplaceText, uConfirmReplace,
  uMainWorkbook, uLanguage, uConfirm;

const
  WM_DELETETHIS = WM_USER + 42;

var
  gbSearchBackwards: Boolean;
  gbSearchCaseSensitive: Boolean;
  gbSearchFromCaret: Boolean;
  gbSearchSelectionOnly: Boolean;
  gbSearchTextAtCaret: Boolean;
  gbSearchWholeWords: Boolean;

  gsSearchText: string;
  gsSearchTextHistory: string;
  gsReplaceText: string;
  gsReplaceTextHistory: string;

  { TEditor }

constructor TEditor.Create(AForm: TEditorForm);
begin
  Assert(AForm <> nil);
  inherited Create;
  fForm := AForm;
  fUntitledNumber := -1;
end;

procedure TEditor.Activate;
begin
  if fForm <> nil then
    fForm.DoActivate;
end;

function TEditor.AskSaveChanges: Boolean;
begin
  if fForm <> nil then
    Result := fForm.DoAskSaveChanges
  else
    Result := True;
end;

function TEditor.CanClose: Boolean;
begin
  Result := fForm <> nil;
end;

procedure TEditor.Close;
begin
  if (fFileName <> '') and (CommandsDataModule <> nil) then
    CommandsDataModule.AddMRUEntry(fFileName);
  if fUntitledNumber <> -1 then
    CommandsDataModule.ReleaseUntitledNumber(fUntitledNumber);
  if fForm <> nil then
    fForm.Close;
end;

procedure TEditor.DoSetFileName(AFileName: string);
begin
  if AFileName <> fFileName then
  begin
    fFileName := AFileName;
    if fUntitledNumber <> -1 then
    begin
      CommandsDataModule.ReleaseUntitledNumber(fUntitledNumber);
      fUntitledNumber := -1;
    end;
  end;
end;

function TEditor.GetCaretPos: TPoint;
begin
  if fForm <> nil then
    Result := TPoint(fForm.SynEditor.CaretXY)
  else
    Result := Point(-1, -1);
end;

function TEditor.GetEditorState: string;
begin
  if fForm <> nil then
  begin
    if fForm.SynEditor.ReadOnly then
      Result := _('Read Only')
    else if fForm.SynEditor.InsertMode then
      Result := _('Insert')
    else
      Result := _('Overwrite');
  end
  else
    Result := '';
end;

function TEditor.GetFileName: string;
begin
  Result := fFileName;
end;

function TEditor.GetFileTitle: string;
begin
  if fFileName <> '' then
    Result := ExtractFileName(fFileName)
  else
  begin
    if fUntitledNumber = -1 then
      fUntitledNumber := CommandsDataModule.GetUntitledNumber;
    Result := _('Quest') + IntToStr(fUntitledNumber);
  end;
end;

function TEditor.GetModified: Boolean;
begin
  if fForm <> nil then
    Result := fForm.SynEditor.Modified
  else
    Result := False;
end;

procedure TEditor.OpenFile(AFileName: string);
begin
  fFileName := AFileName;
  if fForm <> nil then
  begin
    if (AFileName <> '') and FileExists(AFileName) then
      fForm.SynEditor.Lines.LoadFromFile(AFileName)
    else
      fForm.SynEditor.Lines.Clear;
    fForm.DoUpdateCaption;
    fForm.DoUpdateHighlighter;
  end;
end;

// IEditCommands implementation

function TEditor.CanCopy: Boolean;
begin
  Result := (fForm <> nil) and fHasSelection;
end;

function TEditor.CanCut: Boolean;
begin
  Result := (fForm <> nil) and fHasSelection and not fIsReadOnly;
end;

function TEditor.CanPaste: Boolean;
begin
  Result := (fForm <> nil) and fForm.SynEditor.CanPaste;
end;

function TEditor.CanRedo: Boolean;
begin
  Result := (fForm <> nil) and fForm.SynEditor.CanRedo;
end;

function TEditor.CanSelectAll: Boolean;
begin
  Result := fForm <> nil;
end;

function TEditor.CanUndo: Boolean;
begin
  Result := (fForm <> nil) and fForm.SynEditor.CanUndo;
end;

procedure TEditor.ExecCopy;
begin
  if fForm <> nil then
    fForm.SynEditor.CopyToClipboard;
end;

procedure TEditor.ExecCut;
begin
  if fForm <> nil then
    fForm.SynEditor.CutToClipboard;
end;

procedure TEditor.ExecDelete;
begin
  if fForm <> nil then
    fForm.SynEditor.SelText := '';
end;

procedure TEditor.ExecPaste;
begin
  if fForm <> nil then
    fForm.SynEditor.PasteFromClipboard;
end;

procedure TEditor.ExecRedo;
begin
  if fForm <> nil then
    fForm.SynEditor.Redo;
end;

procedure TEditor.ExecSelectAll;
begin
  if fForm <> nil then
    fForm.SynEditor.SelectAll;
end;

procedure TEditor.ExecUndo;
begin
  if fForm <> nil then
    fForm.SynEditor.Undo;
end;

// IFileCommands implementation

function TEditor.CanPrint: Boolean;
begin
  Result := False;
end;

function TEditor.CanSave: Boolean;
begin
  Result := (fForm <> nil) and (fModified or (fFileName = ''));
end;

function TEditor.CanSaveAs: Boolean;
begin
  Result := fForm <> nil;
end;

procedure TEditor.ExecPrint;
begin
  if fForm <> nil then
    // TODO
end;

procedure TEditor.ExecSave;
begin
  if fForm <> nil then
  begin
    if fFileName <> '' then
      fForm.DoSave
    else
      fForm.DoSaveAs
  end;
end;

procedure TEditor.ExecSaveAs;
begin
  if fForm <> nil then
    fForm.DoSaveAs;
end;

// ISearchCommands implementation

function TEditor.CanFind: Boolean;
begin
  Result := (fForm <> nil) and not fIsEmpty;
end;

function TEditor.CanFindNext: Boolean;
begin
  Result := (fForm <> nil) and not fIsEmpty and (gsSearchText <> '');
end;

function TEditor.CanReplace: Boolean;
begin
  Result := (fForm <> nil) and not fIsReadOnly and not fIsEmpty;
end;

procedure TEditor.ExecFind;
begin
  if fForm <> nil then
    fForm.ShowSearchReplaceDialog(False);
end;

procedure TEditor.ExecFindNext;
begin
  if fForm <> nil then
    fForm.DoSearchReplaceText(False, False);
end;

procedure TEditor.ExecFindPrev;
begin
  if fForm <> nil then
    fForm.DoSearchReplaceText(False, True);
end;

procedure TEditor.ExecReplace;
begin
  if fForm <> nil then
    fForm.ShowSearchReplaceDialog(True);
end;

{ TEditorTabSheet }

type
  TEditorTabSheet = class(TTabSheet)
  private
    procedure WMDeleteThis(var Msg: TMessage); message WM_DELETETHIS;
  end;

procedure TEditorTabSheet.WMDeleteThis(var Msg: TMessage);
begin
  Free;
end;

{ TEditorFactory }

type
  TEditorFactory = class(TInterfacedObject, IEditorFactory)
  private
    // IEditorFactory implementation
    function CanCloseAll: Boolean;
    procedure CloseAll;
    function CreateBorderless(AOwner: TForm): IEditor;
    function CreateMDIChild(AOwner: TForm): IEditor;
    function CreateTabSheet(AOwner: TPageControl): IEditor;
    function GetEditorCount: Integer;
    function GetEditor(Index: Integer): IEditor;
    procedure RemoveEditor(AEditor: IEditor);
  private
    fEditors: TInterfaceList;
    constructor Create;
    destructor Destroy; override;
  end;

constructor TEditorFactory.Create;
begin
  inherited Create;
  fEditors := TInterfaceList.Create;
end;

destructor TEditorFactory.Destroy;
begin
  fEditors.Free;
  inherited Destroy;
end;

function TEditorFactory.CanCloseAll: Boolean;
var
  i: Integer;
  LEditor: IEditor;
begin
  i := fEditors.Count - 1;
  while i >= 0 do
  begin
    LEditor := IEditor(fEditors[i]);
    if not LEditor.AskSaveChanges then
    begin
      Result := False;
      exit;
    end;
    Dec(i);
  end;
  Result := True;
end;

procedure TEditorFactory.CloseAll;
var
  i: Integer;
begin
  i := fEditors.Count - 1;
  while i >= 0 do
  begin
    IEditor(fEditors[i]).Close;
    Dec(i);
  end;
end;

function TEditorFactory.CreateBorderless(AOwner: TForm): IEditor;
var
  LForm: TEditorForm;
begin
  LForm := TEditorForm.Create(AOwner);
  with LForm do
  begin
    fEditor := TEditor.Create(LForm);
    Result := fEditor;
    fKind := ekBorderless;
    BorderStyle := bsNone;
    Parent := AOwner;
    Align := alClient;
    Visible := True;
  end;
  if Result <> nil then
    fEditors.Add(Result);
end;

function TEditorFactory.CreateMDIChild(AOwner: TForm): IEditor;
var
  LForm: TEditorForm;
begin
  LForm := TEditorForm.Create(AOwner);
  with LForm do
  begin
    fEditor := TEditor.Create(LForm);
    Result := fEditor;
    fKind := ekMDIChild;
    FormStyle := fsMDIChild;
  end;
  if Result <> nil then
    fEditors.Add(Result);
end;

function TEditorFactory.CreateTabSheet(AOwner: TPageControl): IEditor;
var
  Sheet: TTabSheet;
  LForm: TEditorForm;
begin
  Sheet := TEditorTabSheet.Create(AOwner);
  try
    Sheet.PageControl := AOwner;
    LForm := TEditorForm.Create(Sheet);
    with LForm do
    begin
      fEditor := TEditor.Create(LForm);
      Result := fEditor;
      fKind := ekInTabsheet;
      BorderStyle := bsNone;
      Parent := Sheet;
      Align := alClient;
      Visible := True;
      AOwner.ActivePage := Sheet;
      LForm.SetFocus;
    end;
    // fix for Delphi 4 (???)
    LForm.Realign;
    if Result <> nil then
      fEditors.Add(Result);
  except
    Sheet.Free;
  end;
end;

function TEditorFactory.GetEditorCount: Integer;
begin
  Result := fEditors.Count;
end;

function TEditorFactory.GetEditor(Index: Integer): IEditor;
begin
  Result := IEditor(fEditors[Index]);
end;

procedure TEditorFactory.RemoveEditor(AEditor: IEditor);
var
  i: Integer;
begin
  i := fEditors.IndexOf(AEditor);
  if i > -1 then
    fEditors.Delete(i);
end;

{ TEditorForm }

procedure TEditorForm.FormActivate(Sender: TObject);
begin
  DoAssignInterfacePointer(True);
end;

procedure TEditorForm.FormDeactivate(Sender: TObject);
begin
  DoAssignInterfacePointer(False);
end;

procedure TEditorForm.FormShow(Sender: TObject);
begin
  DoUpdateCaption;
end;

procedure TEditorForm.FormClose(Sender: TObject; var Action: TCloseAction);
begin
  if fKind = ekInTabsheet then
  begin
    PostMessage(Parent.Handle, WM_DELETETHIS, 0, 0);
    Action := caNone;
  end
  else
    Action := caFree;
end;

procedure TEditorForm.FormCloseQuery(Sender: TObject; var CanClose: Boolean);
begin
  // need to prevent this from happening more than once (e.g. with MDI childs)
  if not(csDestroying in ComponentState) then
    CanClose := DoAskSaveChanges;
end;

procedure TEditorForm.FormDestroy(Sender: TObject);
var
  LEditor: IEditor;
begin
  LEditor := fEditor;
  Assert(fEditor <> nil);
  fEditor.fForm := nil;
  Assert(GI_EditorFactory <> nil);
  GI_EditorFactory.RemoveEditor(LEditor);
end;

procedure TEditorForm.SynEditorChange(Sender: TObject);
var
  Empty: Boolean;
  i: Integer;
begin
  Assert(fEditor <> nil);
  Empty := True;
  for i := SynEditor.Lines.Count - 1 downto 0 do
    if SynEditor.Lines[i] <> '' then
    begin
      Empty := False;
      break;
    end;
  fEditor.fIsEmpty := Empty;
end;

procedure TEditorForm.SynEditorEnter(Sender: TObject);
begin
  DoAssignInterfacePointer(True);
end;

procedure TEditorForm.SynEditorExit(Sender: TObject);
begin
  DoAssignInterfacePointer(False);
end;

procedure TEditorForm.SynEditorReplaceText(Sender: TObject;
  const ASearch, AReplace: string; Line, Column: Integer;
  var Action: TSynReplaceAction);
var
  APos: TPoint;
  EditRect: TRect;
begin
  if ASearch = AReplace then
    Action := raSkip
  else
  begin
    APos := SynEditor.ClientToScreen
      (SynEditor.RowColumnToPixels(SynEditor.BufferToDisplayPos
      (BufferCoord(Column, Line))));
    EditRect := ClientRect;
    EditRect.TopLeft := ClientToScreen(EditRect.TopLeft);
    EditRect.BottomRight := ClientToScreen(EditRect.BottomRight);

    if ConfirmReplaceDialog = nil then
      ConfirmReplaceDialog := TConfirmReplaceDialog.Create(Application);
    ConfirmReplaceDialog.PrepareShow(EditRect, APos.X, APos.Y,
      APos.Y + SynEditor.LineHeight, ASearch);
    case ConfirmReplaceDialog.ShowModal of
      mrYes:
        Action := raReplace;
      mrYesToAll:
        Action := raReplaceAll;
      mrNo:
        Action := raSkip;
    else
      Action := raCancel;
    end;
  end;
end;

procedure TEditorForm.SynEditorStatusChange(Sender: TObject;
  Changes: TSynStatusChanges);
begin
  Assert(fEditor <> nil);
  if Changes * [scAll, scSelection] <> [] then
    fEditor.fHasSelection := SynEditor.SelAvail;
  if Changes * [scAll, scSelection] <> [] then
    fEditor.fIsReadOnly := SynEditor.ReadOnly;
  if Changes * [scAll, scModified] <> [] then
    fEditor.fModified := SynEditor.Modified;
end;

procedure TEditorForm.DoActivate;
var
  Sheet: TTabSheet;
  PCtrl: TPageControl;
begin
  if FormStyle = fsMDIChild then
    BringToFront
  else if Parent is TTabSheet then
  begin
    Sheet := TTabSheet(Parent);
    PCtrl := Sheet.PageControl;
    if PCtrl <> nil then
      PCtrl.ActivePage := Sheet;
  end;
  DoUpdateCaption;
end;

function TEditorForm.DoAskSaveChanges: Boolean;
begin
  if SynEditor.Modified then
  begin
    DoActivate;
    MessageBeep(MB_ICONQUESTION);
    Assert(fEditor <> nil);
    case DoConfirmDialog(ExtractFileName(fEditor.GetFileTitle)) of
      crYes:
        Result := DoSave;
      crNo:
        Result := True;
    else
      Result := False;
    end;
  end
  else
    Result := True;
end;

procedure TEditorForm.DoAssignInterfacePointer(AActive: Boolean);
begin
  if AActive then
  begin
    GI_ActiveEditor := fEditor;
    GI_EditCmds := fEditor;
    GI_FileCmds := fEditor;
    GI_SearchCmds := fEditor;
  end
  else
  begin
    if GI_ActiveEditor = IEditor(fEditor) then
      GI_ActiveEditor := nil;
    if GI_EditCmds = IEditCommands(fEditor) then
      GI_EditCmds := nil;
    if GI_FileCmds = IFileCommands(fEditor) then
      GI_FileCmds := nil;
    if GI_SearchCmds = ISearchCommands(fEditor) then
      GI_SearchCmds := nil;
  end;
end;

function TEditorForm.DoSave: Boolean;
begin
  Assert(fEditor <> nil);
  if fEditor.fFileName <> '' then
    Result := DoSaveFile
  else
    Result := DoSaveAs;
end;

function TEditorForm.DoSaveFile: Boolean;
begin
  Assert(fEditor <> nil);
  try
    SynEditor.Lines.SaveToFile(fEditor.fFileName);
    SynEditor.Modified := False;
    Result := True;
  except
    Application.HandleException(Self);
    Result := False;
  end;
end;

function TEditorForm.DoSaveAs: Boolean;
var
  NewName: string;
begin
  Assert(fEditor <> nil);
  NewName := fEditor.fFileName;
  if CommandsDataModule.GetSaveFileName(NewName, SynEditor.Highlighter) then
  begin
    fEditor.DoSetFileName(NewName);
    DoUpdateCaption;
    DoUpdateHighlighter;
    Result := DoSaveFile;
  end
  else
    Result := False;
end;

procedure TEditorForm.DoSearchReplaceText(AReplace: Boolean;
  ABackwards: Boolean);
var
  Options: TSynSearchOptions;
begin
  if AReplace then
    Options := [ssoPrompt, ssoReplace, ssoReplaceAll]
  else
    Options := [];
  if ABackwards then
    Include(Options, ssoBackwards);
  if gbSearchCaseSensitive then
    Include(Options, ssoMatchCase);
  if not fSearchFromCaret then
    Include(Options, ssoEntireScope);
  if gbSearchSelectionOnly then
    Include(Options, ssoSelectedOnly);
  if gbSearchWholeWords then
    Include(Options, ssoWholeWord);
  if SynEditor.SearchReplace(gsSearchText, gsReplaceText, Options) = 0 then
  begin
    MessageBeep(MB_ICONASTERISK);
    if ssoBackwards in Options then
      SynEditor.BlockEnd := SynEditor.BlockBegin
    else
      SynEditor.BlockBegin := SynEditor.BlockEnd;
    SynEditor.CaretXY := SynEditor.BlockBegin;
  end;

  if ConfirmReplaceDialog <> nil then
    ConfirmReplaceDialog.Free;
end;

procedure TEditorForm.DoUpdateCaption;
begin
  Assert(fEditor <> nil);
  if (fKind = ekInTabsheet) then
    (Parent as TTabSheet).Caption := fEditor.GetFileTitle;
  Application.MainForm.Caption := fEditor.GetFileTitle + ' - ' + 'URQEdit';
end;

procedure TEditorForm.DoUpdateHighlighter;
begin
  Assert(fEditor <> nil);
  if fEditor.fFileName <> '' then
  begin
    SynEditor.Highlighter := CommandsDataModule.GetHighlighterForFile
      (fEditor.fFileName);
  end
  else
    SynEditor.Highlighter := nil;
end;

procedure TEditorForm.ShowSearchReplaceDialog(AReplace: Boolean);
var
  dlg: TTextSearchDialog;
begin
  if AReplace then
    dlg := TTextReplaceDialog.Create(Self)
  else
    dlg := TTextSearchDialog.Create(Self);
  with dlg do
    try
      // assign search options
      SearchBackwards := gbSearchBackwards;
      SearchCaseSensitive := gbSearchCaseSensitive;
      SearchFromCursor := gbSearchFromCaret;
      SearchInSelectionOnly := gbSearchSelectionOnly;
      // start with last search text
      SearchText := gsSearchText;
      if gbSearchTextAtCaret then
      begin
        // if something is selected search for that text
        if SynEditor.SelAvail and
          (SynEditor.BlockBegin.Line = SynEditor.BlockEnd.Line) then
          SearchText := SynEditor.SelText
        else
          SearchText := SynEditor.GetWordAtRowCol(SynEditor.CaretXY);
      end;
      SearchTextHistory := gsSearchTextHistory;
      if AReplace then
        with dlg as TTextReplaceDialog do
        begin
          ReplaceText := gsReplaceText;
          ReplaceTextHistory := gsReplaceTextHistory;
        end;
      SearchWholeWords := gbSearchWholeWords;
      if ShowModal = mrOK then
      begin
        gbSearchBackwards := SearchBackwards;
        gbSearchCaseSensitive := SearchCaseSensitive;
        gbSearchFromCaret := SearchFromCursor;
        gbSearchSelectionOnly := SearchInSelectionOnly;
        gbSearchWholeWords := SearchWholeWords;
        gsSearchText := SearchText;
        gsSearchTextHistory := SearchTextHistory;
        if AReplace then
          with dlg as TTextReplaceDialog do
          begin
            gsReplaceText := ReplaceText;
            gsReplaceTextHistory := ReplaceTextHistory;
          end;
        fSearchFromCaret := gbSearchFromCaret;
        if gsSearchText <> '' then
        begin
          DoSearchReplaceText(AReplace, gbSearchBackwards);
          fSearchFromCaret := True;
        end;
      end;
    finally
      dlg.Free;
    end;
end;

initialization

GI_EditorFactory := TEditorFactory.Create;

finalization

GI_EditorFactory := nil;

end.
