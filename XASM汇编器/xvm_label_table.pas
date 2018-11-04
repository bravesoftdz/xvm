unit xvm_label_table;

interface

uses xvm_types, xvm_link_list, System.SysUtils;

var
  // ��ǩ�� ��ת��ǩ
  g_LabelTable: LinkedList;

function GetLabelByIdent(pstrIdent: PAnsiChar; iFuncIndex: integer): pLabelNode;
function AddLabel(pstrIdent: PAnsiChar; iTargetIndex: integer; iFuncIndex: integer): integer;

implementation

function GetLabelByIdent(pstrIdent: PAnsiChar; iFuncIndex: integer): pLabelNode;
var
  iCurrNode: integer;
  pCurrLabel: pLabelNode;
  pCurrNode: pLinkedListNode;
begin
  // �����ʾ�յķ���Nil
  if g_LabelTable.iNodeCount = 0 then
  begin
    Result := nil;
    Exit;
  end;
  // ��ǩָ�����ڱ�ı���
  pCurrNode := g_LabelTable.pHead;
  // ����ֱ���ҵ�ƥ��ṹ
  for iCurrNode := 0 to g_LabelTable.iNodeCount - 1 do
  begin
    pCurrLabel := pLabelNode(pCurrNode.pData);
    // ������ƺͷ�Χƥ��,�򷵻ص�ǰָ��
    if (StrIComp(PAnsiChar(@pCurrLabel.pstrIdent), pstrIdent) = 0) and
      (pCurrLabel.iFuncIndex = iFuncIndex) then
    begin
      Result := pCurrLabel;
      Exit;
    end;
    // ����һ����һ���ڵ�
    pCurrNode := pCurrNode.pNext;
  end;
  // û���ҵ�����nil
  Result := nil;
end;

function AddLabel(pstrIdent: PAnsiChar; iTargetIndex: integer; iFuncIndex: integer): integer;
var
  iIndex: integer;
  pNewLabel: pLabelNode;
begin
  // �����ǩ�Ѿ�����,�򷵻�-1
  if GetLabelByIdent(pstrIdent, iFuncIndex) <> nil then
  begin
    Result := -1;
    Exit;
  end;
  // �����µı�ǩ�ڵ�
  GetMem(pNewLabel, sizeof(LabelNode));
  // ��ʼ���±�ǩ
  StrCopy(PAnsiChar(@pNewLabel.pstrIdent), pstrIdent);
  pNewLabel.iTargetIndex := iTargetIndex;
  pNewLabel.iFuncIndex := iFuncIndex;
  // ����������±�ǩ������ȡ����
  iIndex := AddNode(@g_LabelTable, pNewLabel);
  // ���ñ�ǩ�ڵ�����
  pNewLabel.iIndex := iIndex;
  // �����±�ǩ����
  Result := iIndex;
end;

end.
