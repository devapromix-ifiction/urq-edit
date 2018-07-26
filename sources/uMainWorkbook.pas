﻿unit uMainWorkbook;

{$I SynEdit.inc}

interface

uses
  Windows, Messages, SysUtils, Classes, Graphics, Controls, Forms, Dialogs,
  ComCtrls, ActnList, Menus, uEditAppIntfs, uMain, System.Actions;

type
  TWorkbookMainForm = class(TMainForm)
    pctrlMain: TPageControl;
    procedure pctrlMainChange(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure FormCloseQuery(Sender: TObject; var CanClose: Boolean);
  protected
    function DoCreateEditor(AFileName: string): IEditor; override;
  end;

var
  WorkbookMainForm: TWorkbookMainForm;

implementation

{$R *.DFM}
{ TWorkbookMainForm }

function TWorkbookMainForm.DoCreateEditor(AFileName: string): IEditor;
begin
  if GI_EditorFactory <> nil then
    Result := GI_EditorFactory.CreateTabSheet(pctrlMain)
  else
    Result := nil;
end;

procedure TWorkbookMainForm.FormCreate(Sender: TObject);
begin
  inherited;
  CmdLineOpenFiles(True);
end;

procedure TWorkbookMainForm.pctrlMainChange(Sender: TObject);
begin
  inherited;
  if GI_ActiveEditor <> nil then
    GI_ActiveEditor.Activate;
end;

procedure TWorkbookMainForm.FormCloseQuery(Sender: TObject;
  var CanClose: Boolean);
begin
  inherited;
  if GI_EditorFactory <> nil then
    CanClose := GI_EditorFactory.CanCloseAll;
end;

end.
