﻿unit uReplaceText;

{$I SynEdit.inc}

interface

uses
  Windows, Messages, SysUtils, Classes, Graphics, Controls, Forms, Dialogs,
  StdCtrls, ExtCtrls, uSearchText;

type
  TfReplaceText = class(TfSearchText)
    Label2: TLabel;
    cbReplaceText: TComboBox;
    procedure FormCloseQuery(Sender: TObject; var CanClose: Boolean);
    procedure FormShow(Sender: TObject);
  private
    function GetReplaceText: string;
    function GetReplaceTextHistory: string;
    procedure SetReplaceText(Value: string);
    procedure SetReplaceTextHistory(Value: string);
  public
    property ReplaceText: string read GetReplaceText write SetReplaceText;
    property ReplaceTextHistory: string read GetReplaceTextHistory write SetReplaceTextHistory;
  end;

implementation

{$R *.DFM}

uses uLanguage;

{ TTextReplaceDialog }

procedure TfReplaceText.FormShow(Sender: TObject);
begin
  inherited;
  Caption := _('Replace text');
  Label2.Caption := _('&Replace with:');
end;

function TfReplaceText.GetReplaceText: string;
begin
  Result := cbReplaceText.Text;
end;

function TfReplaceText.GetReplaceTextHistory: string;
begin
  Result := GetHistory(cbReplaceText);
end;

procedure TfReplaceText.SetReplaceText(Value: string);
begin
  cbReplaceText.Text := Value;
end;

procedure TfReplaceText.SetReplaceTextHistory(Value: string);
begin
  cbReplaceText.Items.Text := Value;
end;

procedure TfReplaceText.FormCloseQuery(Sender: TObject; var CanClose: Boolean);
begin
  inherited;
  Self.CloseForm(cbReplaceText);
end;

end.
