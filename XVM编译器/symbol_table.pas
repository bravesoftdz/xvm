{ ******************************************************* }
{ }
{ XVM }
{ }
{ ��Ȩ���� (C) 2012 adsj }
{ Mode�� �����б�ģ�� }
{ ******************************************************* }
unit symbol_table;

interface

uses
  System.SysUtils, globals, linked_list;

const
  SCOPE_GLOBAL = 0;

  SYMBOL_TYPE_VAR = 0;
  SYMBOL_TYPE_PARAM = 1;

type
  pSymbolNode = ^SymbolNode;

  _SymbolNode = record
    iIndex: Integer; // ����
    pstrIdent: array [0 .. MAX_IDENT_SIZE - 1] of AnsiChar; // ��ʶ��
    iSize: Integer; // ��С ����ʹ�� 1 ����ʹ�� N
    iScope: Integer; // ������ ȫ�� 0 �ֲ���������ʹ�� N
    iType: Integer; // ��������(�������߱���)
  end;

  SymbolNode = _SymbolNode;
  // �ӿ�
  (* ��÷��Žṹ *)
function GetSymbolByIndex(iIndex: Integer): pSymbolNode;
function GetSymbolByIdent(pstrIdent: PAnsiChar; iScope: Integer): pSymbolNode;
(* ��ӷ��� *)
function AddSymbol(pstrIdent: PAnsiChar; iSize: Integer; iScope: Integer; iType: Integer): Integer;

implementation

function GetSymbolByIndex(iIndex: Integer): pSymbolNode;
var
  pCurrNode: pLinkedListNode;
  pCurrSymbol: pSymbolNode;
  iCurrNode: Integer;
begin
  if g_SymbolTable.iNodeCount = 0 then
  begin
    Result := nil;
    Exit;
  end;
  pCurrNode := g_SymbolTable.pHead;
  for iCurrNode := 0 to g_SymbolTable.iNodeCount - 1 do
  begin
    pCurrSymbol := pSymbolNode(pCurrNode.pData);
    if iIndex = pCurrSymbol.iIndex then
    begin
      Result := pCurrSymbol;
      Exit;
    end;
    pCurrNode := pCurrNode.pNext;
  end;
  Result := nil;
end;


function GetSymbolByIdent(pstrIdent: PAnsiChar; iScope: Integer): pSymbolNode;
var
  pCurrSymbol: pSymbolNode;
  iCurrSymbolIndex: Integer;
begin
  // ѭ�����
  for iCurrSymbolIndex := 0 to g_SymbolTable.iNodeCount - 1 do
  begin
    pCurrSymbol := GetSymbolByIndex(iCurrSymbolIndex);
    // �����ʶ������������ͬ�ͷ���
    if //
      (pCurrSymbol <> nil) and //
      (StrIComp(PAnsiChar(@pCurrSymbol.pstrIdent), pstrIdent) = 0) and //
      (pCurrSymbol.iScope = iScope) //
    then
    begin
      Result := pCurrSymbol;
      Exit;
    end;
  end;
  Result := nil;
end;

function GetSizeByIdent(pstrIdent: PAnsiChar; iScope: Integer): Integer;
var
  pSymbol: pSymbolNode;
begin
  pSymbol := GetSymbolByIdent(pstrIdent, iScope);
  Result := pSymbol.iSize;
end;

function AddSymbol(pstrIdent: PAnsiChar; iSize: Integer; iScope: Integer; iType: Integer): Integer;
var
  iIndex: Integer;
  pNewSymbol: pSymbolNode;
begin
  if GetSymbolByIdent(pstrIdent, iScope) <> nil then
  begin
    Result := -1;
    Exit;
  end;
  GetMem(pNewSymbol, SizeOf(SymbolNode));

  StrCopy(@pNewSymbol.pstrIdent, pstrIdent);
  pNewSymbol.iSize := iSize;
  pNewSymbol.iScope := iScope;
  pNewSymbol.iType := iType;

  iIndex := AddNode(@g_SymbolTable, pNewSymbol);
  pNewSymbol.iIndex := iIndex;

  Result := iIndex;
end;

end.
