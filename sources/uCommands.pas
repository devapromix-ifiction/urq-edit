﻿unit uCommands;

{$I SynEdit.inc}

interface

uses
  Windows, Messages, SysUtils, Classes, Graphics, Controls, Forms, Dialogs,
  ActnList, SynEditHighlighter, System.Actions, SynEditCodeFolding,
  SynHighlighterURQL, SynHighlighterXML;

type
  TfCommands = class(TDataModule)
    dlgFileOpen: TOpenDialog;
    actlMain: TActionList;
    actFileSave: TAction;
    actFileSaveAs: TAction;
    actFileClose: TAction;
    actFilePrint: TAction;
    actEditCut: TAction;
    actEditCopy: TAction;
    actEditPaste: TAction;
    actEditDelete: TAction;
    actEditUndo: TAction;
    actEditRedo: TAction;
    actEditSelectAll: TAction;
    actSearchFind: TAction;
    actSearchFindNext: TAction;
    actSearchFindPrev: TAction;
    actSearchReplace: TAction;
    dlgFileSave: TSaveDialog;
    SynURQLSyn1: TSynURQLSyn;
    SynXMLSyn1: TSynXMLSyn;
    procedure DataModuleCreate(Sender: TObject);
    procedure DataModuleDestroy(Sender: TObject);
    procedure actFileSaveExecute(Sender: TObject);
    procedure actFileSaveUpdate(Sender: TObject);
    procedure actFileSaveAsExecute(Sender: TObject);
    procedure actFileSaveAsUpdate(Sender: TObject);
    procedure actFilePrintExecute(Sender: TObject);
    procedure actFilePrintUpdate(Sender: TObject);
    procedure actFileCloseExecute(Sender: TObject);
    procedure actFileCloseUpdate(Sender: TObject);
    procedure actEditCutExecute(Sender: TObject);
    procedure actEditCutUpdate(Sender: TObject);
    procedure actEditCopyExecute(Sender: TObject);
    procedure actEditCopyUpdate(Sender: TObject);
    procedure actEditPasteExecute(Sender: TObject);
    procedure actEditPasteUpdate(Sender: TObject);
    procedure actEditDeleteExecute(Sender: TObject);
    procedure actEditDeleteUpdate(Sender: TObject);
    procedure actEditSelectAllExecute(Sender: TObject);
    procedure actEditSelectAllUpdate(Sender: TObject);
    procedure actEditRedoExecute(Sender: TObject);
    procedure actEditRedoUpdate(Sender: TObject);
    procedure actEditUndoExecute(Sender: TObject);
    procedure actEditUndoUpdate(Sender: TObject);
    procedure actSearchFindExecute(Sender: TObject);
    procedure actSearchFindUpdate(Sender: TObject);
    procedure actSearchFindNextExecute(Sender: TObject);
    procedure actSearchFindNextUpdate(Sender: TObject);
    procedure actSearchFindPrevExecute(Sender: TObject);
    procedure actSearchFindPrevUpdate(Sender: TObject);
    procedure actSearchReplaceExecute(Sender: TObject);
    procedure actSearchReplaceUpdate(Sender: TObject);
  private
    FHighlighters: TStringList;
    FMRUFiles: TStringList;
    FUntitledNumbers: TBits;
  public
    procedure AddMRUEntry(AFileName: string);
    function GetHighlighterForFile(AFileName: string): TSynCustomHighlighter;
    function GetMRUEntries: Integer;
    function GetMRUEntry(Index: Integer): string;
    function GetSaveFileName(var ANewName: string;
      AHighlighter: TSynCustomHighlighter): Boolean;
    function GetUntitledNumber: Integer;
    procedure ReleaseUntitledNumber(ANumber: Integer);
    procedure RemoveMRUEntry(AFileName: string);
    function GetDefaultHighlighter: string;
  end;

var
  fCommands: TfCommands;

implementation

{$R *.DFM}

uses
  uHighlighterProcs, uEditAppIntfs, uLanguage;

const
  MAX_MRU = 5;

resourcestring
  SFilterAllFiles = 'All files |*.*|';

  { TCommandsDataModule }

procedure TfCommands.DataModuleCreate(Sender: TObject);
begin
  FHighlighters := TStringList.Create;
  GetHighlighters(Self, FHighlighters, False);
  dlgFileOpen.Filter := GetHighlightersFilter(FHighlighters) +
    _(SFilterAllFiles);
  FMRUFiles := TStringList.Create;
end;

procedure TfCommands.DataModuleDestroy(Sender: TObject);
begin
  FMRUFiles.Free;
  FHighlighters.Free;
  FUntitledNumbers.Free;
  fCommands := nil;
end;

procedure TfCommands.AddMRUEntry(AFileName: string);
begin
  if AFileName <> '' then
  begin
    RemoveMRUEntry(AFileName);
    FMRUFiles.Insert(0, AFileName);
    while FMRUFiles.Count > MAX_MRU do
      FMRUFiles.Delete(FMRUFiles.Count - 1);
  end;
end;

function TfCommands.GetDefaultHighlighter: string;
begin
  // Хайлайтер URQ по умолчанию
  Result := SynURQLSyn1.DefaultFilter;
end;

function TfCommands.GetHighlighterForFile(AFileName: string)
  : TSynCustomHighlighter;
begin
  if AFileName <> '' then
    Result := GetHighlighterFromFileExt(FHighlighters,
      ExtractFileExt(AFileName))
  else
    Result := nil;
end;

function TfCommands.GetMRUEntries: Integer;
begin
  Result := FMRUFiles.Count;
end;

function TfCommands.GetMRUEntry(Index: Integer): string;
begin
  if (Index >= 0) and (Index < FMRUFiles.Count) then
    Result := FMRUFiles[Index]
  else
    Result := '';
end;

function TfCommands.GetSaveFileName(var ANewName: string;
  AHighlighter: TSynCustomHighlighter): Boolean;
begin
  with dlgFileSave do
  begin
    if ANewName <> '' then
    begin
      InitialDir := ExtractFileDir(ANewName);
      FileName := ExtractFileName(ANewName);
    end
    else
    begin
      InitialDir := '';
      FileName := '';
    end;
    if AHighlighter <> nil then
      Filter := AHighlighter.DefaultFilter
    else
      Filter := _(SFilterAllFiles);
    if Execute then
    begin
      ANewName := FileName;
      Result := True;
    end
    else
      Result := False;
  end;
end;

function TfCommands.GetUntitledNumber: Integer;
begin
  if FUntitledNumbers = nil then
    FUntitledNumbers := TBits.Create;
  Result := FUntitledNumbers.OpenBit;
  if Result = FUntitledNumbers.Size then
    FUntitledNumbers.Size := FUntitledNumbers.Size + 32;
  FUntitledNumbers[Result] := True;
  Inc(Result);
end;

procedure TfCommands.ReleaseUntitledNumber(ANumber: Integer);
begin
  Dec(ANumber);
  if (FUntitledNumbers <> nil) and (ANumber >= 0) and
    (ANumber < FUntitledNumbers.Size) then
    FUntitledNumbers[ANumber] := False;
end;

procedure TfCommands.RemoveMRUEntry(AFileName: string);
var
  I: Integer;
begin
  for I := FMRUFiles.Count - 1 downto 0 do
  begin
    if CompareText(AFileName, FMRUFiles[I]) = 0 then
      FMRUFiles.Delete(I);
  end;
end;

procedure TfCommands.actFileSaveExecute(Sender: TObject);
begin
  if GI_FileCmds <> nil then
    GI_FileCmds.ExecSave;
end;

procedure TfCommands.actFileSaveUpdate(Sender: TObject);
begin
  actFileSave.Enabled := (GI_FileCmds <> nil) and GI_FileCmds.CanSave;
end;

procedure TfCommands.actFileSaveAsExecute(Sender: TObject);
begin
  if GI_FileCmds <> nil then
    GI_FileCmds.ExecSaveAs;
end;

procedure TfCommands.actFileSaveAsUpdate(Sender: TObject);
begin
  actFileSaveAs.Enabled := (GI_FileCmds <> nil) and GI_FileCmds.CanSaveAs;
end;

procedure TfCommands.actFilePrintExecute(Sender: TObject);
begin
  if GI_FileCmds <> nil then
    GI_FileCmds.ExecPrint;
end;

procedure TfCommands.actFilePrintUpdate(Sender: TObject);
begin
  actFilePrint.Enabled := (GI_FileCmds <> nil) and GI_FileCmds.CanPrint;
end;

procedure TfCommands.actFileCloseExecute(Sender: TObject);
begin
  if GI_FileCmds <> nil then
    GI_FileCmds.ExecClose;
end;

procedure TfCommands.actFileCloseUpdate(Sender: TObject);
begin
  actFileClose.Enabled := (GI_FileCmds <> nil) and GI_FileCmds.CanClose;
end;

procedure TfCommands.actEditCutExecute(Sender: TObject);
begin
  if GI_EditCmds <> nil then
    GI_EditCmds.ExecCut;
end;

procedure TfCommands.actEditCutUpdate(Sender: TObject);
begin
  actEditCut.Enabled := (GI_EditCmds <> nil) and GI_EditCmds.CanCut;
end;

procedure TfCommands.actEditCopyExecute(Sender: TObject);
begin
  if GI_EditCmds <> nil then
    GI_EditCmds.ExecCopy;
end;

procedure TfCommands.actEditCopyUpdate(Sender: TObject);
begin
  actEditCopy.Enabled := (GI_EditCmds <> nil) and GI_EditCmds.CanCopy;
end;

procedure TfCommands.actEditPasteExecute(Sender: TObject);
begin
  if GI_EditCmds <> nil then
    GI_EditCmds.ExecPaste;
end;

procedure TfCommands.actEditPasteUpdate(Sender: TObject);
begin
  actEditPaste.Enabled := (GI_EditCmds <> nil) and GI_EditCmds.CanPaste;
end;

procedure TfCommands.actEditDeleteExecute(Sender: TObject);
begin
  if GI_EditCmds <> nil then
    GI_EditCmds.ExecDelete;
end;

procedure TfCommands.actEditDeleteUpdate(Sender: TObject);
begin
  actEditDelete.Enabled := (GI_EditCmds <> nil) and GI_EditCmds.CanDelete;
end;

procedure TfCommands.actEditSelectAllExecute(Sender: TObject);
begin
  if GI_EditCmds <> nil then
    GI_EditCmds.ExecSelectAll;
end;

procedure TfCommands.actEditSelectAllUpdate(Sender: TObject);
begin
  actEditSelectAll.Enabled := (GI_EditCmds <> nil) and GI_EditCmds.CanSelectAll;
end;

procedure TfCommands.actEditRedoExecute(Sender: TObject);
begin
  if GI_EditCmds <> nil then
    GI_EditCmds.ExecRedo;
end;

procedure TfCommands.actEditRedoUpdate(Sender: TObject);
begin
  actEditRedo.Enabled := (GI_EditCmds <> nil) and GI_EditCmds.CanRedo;
end;

procedure TfCommands.actEditUndoExecute(Sender: TObject);
begin
  if GI_EditCmds <> nil then
    GI_EditCmds.ExecUndo;
end;

procedure TfCommands.actEditUndoUpdate(Sender: TObject);
begin
  actEditUndo.Enabled := (GI_EditCmds <> nil) and GI_EditCmds.CanUndo;
end;

procedure TfCommands.actSearchFindExecute(Sender: TObject);
begin
  if GI_SearchCmds <> nil then
    GI_SearchCmds.ExecFind;
end;

procedure TfCommands.actSearchFindUpdate(Sender: TObject);
begin
  actSearchFind.Enabled := (GI_SearchCmds <> nil) and GI_SearchCmds.CanFind;
end;

procedure TfCommands.actSearchFindNextExecute(Sender: TObject);
begin
  if GI_SearchCmds <> nil then
    GI_SearchCmds.ExecFindNext;
end;

procedure TfCommands.actSearchFindNextUpdate(Sender: TObject);
begin
  actSearchFindNext.Enabled := (GI_SearchCmds <> nil) and
    GI_SearchCmds.CanFindNext;
end;

procedure TfCommands.actSearchFindPrevExecute(Sender: TObject);
begin
  if GI_SearchCmds <> nil then
    GI_SearchCmds.ExecFindPrev;
end;

procedure TfCommands.actSearchFindPrevUpdate(Sender: TObject);
begin
  actSearchFindPrev.Enabled := (GI_SearchCmds <> nil) and
    GI_SearchCmds.CanFindPrev;
end;

procedure TfCommands.actSearchReplaceExecute(Sender: TObject);
begin
  if GI_SearchCmds <> nil then
    GI_SearchCmds.ExecReplace;
end;

procedure TfCommands.actSearchReplaceUpdate(Sender: TObject);
begin
  actSearchReplace.Enabled := (GI_SearchCmds <> nil) and
    GI_SearchCmds.CanReplace;
end;

end.
