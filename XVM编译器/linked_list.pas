{ ******************************************************* }
{                                                         }
{ XVM                                                     }
{                                                         }
{ ��Ȩ���� (C) 2012 adsj                                  }
{ Mode�� �����б�ִ��ģ��                                 }
{ ******************************************************* }
unit linked_list;

interface

uses System.SysUtils;

type
  // ��������
  pLinkedListNode = ^LinkedListNode;

  _LinkedListNode = record
    pData: Pointer; // ָ��ڵ������
    pNext: pLinkedListNode; // ָ��������һ���ڵ�
  end;

  LinkedListNode = _LinkedListNode;

  // ά������
  pLinkedList = ^LinkedList;

  _LinkedList = record
    pHead: pLinkedListNode; // ָ���׽ڵ�
    pTail: pLinkedListNode; // ָ��β�ڵ�
    iNodeCount: Integer; // �����еĽڵ����
  end;

  LinkedList = _LinkedList;
  // �ӿ�
  (* ��ʼ������ *)
procedure InitLinkedList(pList: pLinkedList);
(* �ͷ����� *)
procedure FreeLinkedList(pList: pLinkedList);
(* ����ڵ� *)
function AddNode(pList: pLinkedList; pData: Pointer): Integer;
(* ɾ���ڵ� *)
procedure DelNode(pList: pLinkedList; pNode: pLinkedListNode);
(* �����ַ����ڵ� *)
function AddString(pList: pLinkedList; pstrString: PAnsiChar): Integer;
(* �����ַ����ڵ� *)
function GetStringByIndex(pList: pLinkedList; iIndex: Integer): PAnsiChar;

implementation

procedure InitLinkedList(pList: pLinkedList);
begin
  pList.pHead := nil;
  pList.pTail := nil;
  pList.iNodeCount := 0;
end;

procedure FreeLinkedList(pList: pLinkedList);
var
  pCurrNode: pLinkedListNode;
  pNextNode: pLinkedListNode;
begin
  if not Assigned(pList) then
    Exit;
  if pList.iNodeCount > 0 then
  begin
    pCurrNode := pList.pHead;
    while True do
    begin
      pNextNode := pCurrNode.pNext;
      // free data
      if pCurrNode.pData <> nil then
        FreeMem(pCurrNode.pData);
      // free itself
      if pCurrNode <> nil then
        FreeMem(pCurrNode);
      if pNextNode <> nil then
        pCurrNode := pNextNode
      else
        Break;
    end;
  end;
end;

function AddNode(pList: pLinkedList; pData: Pointer): Integer;
var
  pNewNode: pLinkedListNode;
begin
  GetMem(pNewNode, SizeOf(LinkedListNode));
  pNewNode.pData := pData;
  pNewNode.pNext := nil;
  if pList.iNodeCount = 0 then
  begin
    pList.pHead := pNewNode;
    pList.pTail := pNewNode;
  end
  else
  begin
    pList.pTail.pNext := pNewNode;
    pList.pTail := pNewNode;
  end;
  Result := pList.iNodeCount;
  Inc(pList.iNodeCount);
end;

procedure DelNode(pList: pLinkedList; pNode: pLinkedListNode);

var
  pTravNode: pLinkedListNode;
  iCurrNode: Integer;
begin
  if pList.iNodeCount = 0 then
    Exit;
  if pNode = pList.pHead then
  begin
    pList.pHead := pNode.pNext;
  end
  else
  begin
    pTravNode := pList.pHead;
    for iCurrNode := 0 to pList.iNodeCount - 1 do
    begin
      if pTravNode.pNext = pNode then
      begin
        if pList.pTail = pNode then
        begin
          pTravNode.pNext := nil;
          pList.pTail := pTravNode;
        end
        else
        begin
          pTravNode.pNext := pNode.pNext;
        end;
        Break;
      end;
      pTravNode := pTravNode.pNext;
    end;
  end;
  Dec(pList.iNodeCount);
  if pNode.pData <> nil then
    FreeMem(pNode.pData);
  FreeMem(pNode);
end;

function AddString(pList: pLinkedList; pstrString: PAnsiChar): Integer;
var
  pNode: pLinkedListNode;
  iCurrNode: Integer;
  pstrStringNode: PAnsiChar;
begin
  pNode := pList.pHead;
  for iCurrNode := 0 to pList.iNodeCount - 1 do
  begin
    if StrComp(PAnsiChar(pNode.pData), pstrString) = 0 then
    begin
      Result := iCurrNode;
      Exit;
    end;
    pNode := pNode.pNext;
  end;
  GetMem(pstrStringNode, StrLen(pstrString) + 1);
  StrCopy(pstrStringNode, pstrString);
  Result := AddNode(pList, pstrStringNode);
end;

function GetStringByIndex(pList: pLinkedList; iIndex: Integer): PAnsiChar;
var
  pNode: pLinkedListNode;
  iCurrNode: Integer;
begin
  pNode := pList.pHead;
  for iCurrNode := 0 to pList.iNodeCount - 1 do
  begin
    if iIndex = iCurrNode then
    begin
      Result := PAnsiChar(pNode.pData);
      Exit;
    end;
    pNode := pNode.pNext;
  end;
  Result := nil;
end;

end.
