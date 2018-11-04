{ ******************************************************* }
{                                                         }
{ XVM                                                     }
{                                                         }
{ ��Ȩ���� (C) 2012 adsj                                  }
{ Mode�� Ԥ����ģ��                                       }
{ ******************************************************* }
unit preprocessor;

interface

uses
  System.SysUtils, linked_list, globals;
(* Ԥ���� ״̬��ģʽ *)
procedure PreprocessSourceFile();

implementation

procedure PreprocessSourceFile();
var
  iInBlockComment: Boolean; // is in the /**/
  iInString: Boolean;
  pNode: pLinkedListNode;
  pstrCurrLine: PAnsiChar;
  iCurrCharIndex: Integer;
begin
  iInBlockComment := False;
  iInString := False;
  pNode := g_SourceCode.pHead;
  while True do
  begin
    pstrCurrLine := PAnsiChar(pNode.pData);
    { TODO -oadsj -cԤ���� : û�м���±꣬���ܻ�Խ�� }
    for iCurrCharIndex := 0 to StrLen(pstrCurrLine) - 1 do
    begin
      if pstrCurrLine[iCurrCharIndex] = '"' then
      begin
        iInString := not iInString;
      end;
      if //
        (pstrCurrLine[iCurrCharIndex] = '/') and //
        (pstrCurrLine[iCurrCharIndex + 1] = '/') and //
        (not iInString) and //
        (not iInBlockComment) then
      begin
        pstrCurrLine[iCurrCharIndex] := #10;
        pstrCurrLine[iCurrCharIndex + 1] := #0;
        Break;
      end;
      // ����ע��
      if //
        (pstrCurrLine[iCurrCharIndex] = '/') and //
        (pstrCurrLine[iCurrCharIndex + 1] = '*') and //
        (not iInString) and //
        (not iInBlockComment) //
      then
      begin
        iInBlockComment := True;
      end;
      // ���ҿ�ע�ͽ�β
      if //
        (pstrCurrLine[iCurrCharIndex] = '*') and //
        (pstrCurrLine[iCurrCharIndex + 1] = '/') and //
        (iInBlockComment) //
      then
      begin
        pstrCurrLine[iCurrCharIndex] := ' ';
        pstrCurrLine[iCurrCharIndex + 1] := ' ';
        iInBlockComment := False;
      end;
      if iInBlockComment then
      begin
        if pstrCurrLine[iCurrCharIndex] <> #10 then
          pstrCurrLine[iCurrCharIndex] := ' ';
      end;
    end;

    pNode := pNode.pNext;
    if pNode = nil then
      Break;
  end;
end;

end.
