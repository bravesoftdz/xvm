{ ******************************************************* }
{                                                         }
{ XVM                                                     }
{                                                         }
{ ��Ȩ���� (C) 2012 adsj                                  }
{ Mode�� �����б�ģ��                                     }
{ ******************************************************* }
unit xvm_symbol_table;

interface

uses
  System.SysUtils, xvm_types, xvm_link_list;

var
  // ���ű�
  g_SymbolTable: LinkedList;

function GetSymbolByIdent(pstrIdent: PAnsiChar; iFuncIndex: integer): pSymbolNode;
function AddSymbol(pstrIdent: PAnsiChar; iSize: integer; iStackIndex: integer;
  iFuncIndex: integer): integer;
function GetStackIndexByIdent(pstrIdent: PAnsiChar; iFuncIndex: integer): integer;
function GetSizeByIdent(pstrIdent: PAnsiChar; iFuncIndex: integer): integer;

implementation

function GetSymbolByIdent(pstrIdent: PAnsiChar; iFuncIndex: integer): pSymbolNode;
var
  iCurrNode: integer;
  pCurrNode: pLinkedListNode;
  pCurrSymbol: pSymbolNode;
begin
  if (g_SymbolTable.iNodeCount = 0) then
  begin
    Result := nil;
    Exit;
  end;
  pCurrNode := g_SymbolTable.pHead;
  for iCurrNode := 0 to g_SymbolTable.iNodeCount - 1 do
  begin
    pCurrSymbol := pSymbolNode(pCurrNode.pData);
    if StrIComp(PAnsiChar(@pCurrSymbol.pstrIdent), pstrIdent) = 0 then
      if (pCurrSymbol.iFuncIndex = iFuncIndex) or (pCurrSymbol.iStackIndex >= 0) then
      begin
        Result := pCurrSymbol;
        Exit;
      end;
    pCurrNode := pCurrNode.pNext;

  end;
  Result := nil;
end;

function AddSymbol(pstrIdent: PAnsiChar; iSize: integer; iStackIndex: integer;
  iFuncIndex: integer): integer;
var
  iIndex: integer;
  pNewSymbol: pSymbolNode;
begin
  // �����ǩ�Ѿ�����
  if GetSymbolByIdent(pstrIdent, iFuncIndex) <> nil then
  begin
    Result := -1;
    Exit;
  end;
  // �����µķ��Žڵ�
  GetMem(pNewSymbol, sizeof(SymbolNode));
  // ��ʼ���±�ǩ
  StrCopy(@pNewSymbol.pstrIdent, pstrIdent);
  pNewSymbol.iSize := iSize;
  pNewSymbol.iStackIndex := iStackIndex;
  pNewSymbol.iFuncIndex := iFuncIndex;
  // ��������ӷ���,��ȡ��������
  iIndex := AddNode(@g_SymbolTable, pNewSymbol);
  // ���÷��Žڵ�����
  pNewSymbol.iIndex := iIndex;
  // �����·��ŵ�����
  Result := iIndex;
end;

function GetStackIndexByIdent(pstrIdent: PAnsiChar; iFuncIndex: integer): integer;
var
  pSymbol: pSymbolNode;
begin
  pSymbol := GetSymbolByIdent(pstrIdent, iFuncIndex);
  Result := pSymbol.iStackIndex;
end;

function GetSizeByIdent(pstrIdent: PAnsiChar; iFuncIndex: integer): integer;
var
  pSymbol: pSymbolNode;
begin
  pSymbol := GetSymbolByIdent(pstrIdent, iFuncIndex);
  Result := pSymbol.iSize;
end;

end.
