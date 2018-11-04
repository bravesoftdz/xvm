{ ******************************************************* }
{                                                         }
{ XVM                                                     }
{                                                         }
{ ��Ȩ���� (C) 2012 adsj                                  }
{ Mode�� I-code�м����(->XASM)ģ��                       }
{ ******************************************************* }
unit i_code;

interface

uses
  System.SysUtils, linked_list, func_table;

const
{$REGION '��̬����'}
  // I_Code Node Types
  ICODE_NODE_INSTR = 0;
  ICODE_NODE_SOURCE_LINE = 1;
  ICODE_NODE_JUMP_TARGET = 2;
  // ָ��
  // -------I_CODE Instruction Opcodes
  INSTR_MOV = 0;

  INSTR_ADD = 1;
  INSTR_SUB = 2;
  INSTR_MUL = 3;
  INSTR_DIV = 4;
  INSTR_MOD = 5;
  INSTR_EXP = 6;
  INSTR_NEG = 7;
  INSTR_INC = 8;
  INSTR_DEC = 9;
  // CALC
  INSTR_AND = 10;
  INSTR_OR = 11;
  INSTR_XOR = 12;
  INSTR_NOT = 13;
  INSTR_SHL = 14;
  INSTR_SHR = 15;
  // STRING
  INSTR_CONCAT = 16;
  INSTR_GETCHAR = 17;
  INSTR_SETCHAR = 18;
  // JUMP INSTR
  INSTR_JMP = 19;
  INSTR_JE = 20;
  INSTR_JNE = 21;
  INSTR_JG = 22;
  INSTR_JL = 23;
  INSTR_JGE = 24;
  INSTR_JLE = 25;
  // STACK
  INSTR_PUSH = 26;
  INSTR_POP = 27;
  // FUNC
  INSTR_CALL = 28;
  INSTR_RET = 29;
  INSTR_CALLHOST = 30;
  // SYSTEM
  INSTR_PAUSE = 31;
  INSTR_EXIT = 32;
  // �м������������ͱ�
  OP_TYPE_INT = 0; // ����������
  OP_TYPE_FLOAT = 1; // ������������
  OP_TYPE_STRING_INDEX = 2; // �ַ���������
  OP_TYPE_VAR = 3; // ����
  OP_TYPE_ARRAY_INDEX_ABS = 4; // ʹ�þ�����������
  OP_TYPE_ARRAY_INDEX_VAR = 5; // ʹ�������������
  OP_TYPE_JUMP_TARGET_INDEX = 6; // ��תĿ������
  OP_TYPE_FUNC_INDEX = 7; // ��������
  OP_TYPE_REG = 9; // �Ĵ���
{$ENDREGION}

type
  // ----------------------------------------------------------
  // һ���м����ָ��
  _ICodeInstr = record
    iOpcode: Integer; // ������
    OpList: LinkedList; // �������б�
  end;

  ICodeInstr = _ICodeInstr;
  // ----------------------------------------------------------
  pOp = ^Op;

  // �м����Ĳ�����
  _Op = record
    iType: Integer; // ����
    iOffset: Integer; // ƫ����
    iOffsetSymbolIndex: Integer; // ƫ�Ʒ�������
    // ֵ
    case Integer of
      0:
        (iIntLiteral: Integer); // ��������ֵ
      1:
        (fFloatLiteral: Real); // ��������ֵ
      2:
        (iStringIndex: Integer); // �ַ���������
      3:
        (iSymbolIndex: Integer); // ���ű�����
      4:
        (iJumpTargetIndex: Integer); // ��תĿ������
      5:
        (iFuncIndex: Integer); // ��������
      6:
        (iRegCode: Integer); // Register code  �Ĵ���
  end;

  Op = _Op;

  // ----------------------------------------------------------
  // �м����ڵ�
  pICodeNode = ^ICodeNode;

  _ICodeNode = record
    iType: Integer; // �ڵ�����
    case Integer of
      0:
        (Instr: ICodeInstr); // �м����ָ��
      1:
        (pstrSourceLine: PAnsiChar); // ��ע���ָ���Դ������
      2:
        (iJumpTargetIndex: Integer); // ��תĿ������
  end;

  ICodeNode = _ICodeNode;

  // ----------------------------------------------------------
  (* ���ָ�� *)
function AddICodeInstr(iFuncIndex: Integer; iOpcode: Integer): Integer;
(* ��Ӳ����� *)
procedure AddICodeOp(iFuncIndex: Integer; iInstrIndex: Integer; Value: Op);
// ----------------------------------------------------------
{$REGION '��Ӹ��ֲ�����'}
(* ������������������� *)
procedure AddIntICodeOp(iFuncIndex: Integer; iInstrIndex: Integer; iValue: Integer);
(* ��Ӹ�������ֵ������ *)
procedure AddFloatICodeOp(iFuncIndex: Integer; iInstrIndex: Integer; fValue: Real);
(* ����ַ��������� *)
procedure AddStringICodeOp(iFuncIndex: Integer; iInstrIndex: Integer; iStringIndex: Integer);
(* ��ӱ��������� *)
procedure AddVarICodeOp(iFuncIndex: Integer; iInstrIndex: Integer; iSymbolIndex: Integer);
(* ��Ӿ���������������� *)
procedure AddArrayIndexABSICodeOp(iFuncIndex: Integer; iInstrIndex: Integer;
  iArraySymbolIndex: Integer; iOffset: Integer);
(* ������������������� *)
procedure AddArrayIndexVarICodeOp(iFuncIndex: Integer; iInstrIndex: Integer;
  iArraySymbolIndex: Integer; iOffsetSymbolIndex: Integer);
(* ��Ӻ��������� *)
procedure AddFuncICodeOp(iFuncIndex: Integer; iInstrIndex: Integer; iOpFuncIndex: Integer);
(* ��ӼĴ��������� *)
procedure AddRegICodeOp(iFuncIndex: Integer; iInstrIndex: Integer; iRegCode: Integer);
(* �����תĿ������������ *)
procedure AddJumpTargetICodeOp(iFuncIndex: Integer; iInstrIndex: Integer; iTargetIndex: Integer);
{$ENDREGION}
// ----------------------------------------------------------
(* ��ȡ�м����ڵ� *)
function GetICodeNodeByImpIndex(iFuncIndex: Integer; iInstrIndex: Integer): pICodeNode;
(* ��ȡ�ڵ� *)
function GetICodeOpByIndex(pInstr: pICodeNode; iOpIndex: Integer): pOp;
(* �����תĿ�� *)
procedure AddICodeJumpTarget(iFuncIndex: Integer; iTargetIndex: Integer);
(* ���ص�ǰĿ������ *)
function GetNextJumpTargetIndex(): Integer;
(* ���Դ�����ע *)
procedure AddICodeSourceLine(iFuncIndex: Integer; pstrSourceLine: PAnsiChar);

// ----------------------------------------------------------
var
  g_iCurrJumpTargetIndex: Integer;

implementation

function AddICodeInstr(iFuncIndex: Integer; iOpcode: Integer): Integer;
var
  pFunc: pFuncNode;
  pInstrNode: pICodeNode;
  iIndex: Integer;
begin
  pFunc := GetFuncByIndex(iFuncIndex);

  GetMem(pInstrNode, SizeOf(ICodeNode));

  pInstrNode.iType := ICODE_NODE_INSTR;
  pInstrNode.Instr.iOpcode := iOpcode;

  pInstrNode.Instr.OpList.iNodeCount := 0;

  iIndex := AddNode(@pFunc.ICodeStream, pInstrNode);

  Result := iIndex;
end;

// ----------------------------------------------------------
function GetICodeNodeByImpIndex(iFuncIndex: Integer; iInstrIndex: Integer): pICodeNode;
var
  pFunc: pFuncNode;
  pCurrNode: pLinkedListNode;
  iCurrNode: Integer;
begin
  pFunc := GetFuncByIndex(iFuncIndex);

  if pFunc.ICodeStream.iNodeCount = 0 then
  begin
    Result := nil;
    Exit;
  end;
  pCurrNode := pFunc.ICodeStream.pHead;

  for iCurrNode := 0 to pFunc.ICodeStream.iNodeCount - 1 do
  begin
    if iInstrIndex = iCurrNode then
    begin
      Result := pICodeNode(pCurrNode.pData);
      Exit;
    end;
    pCurrNode := pCurrNode.pNext;
  end;

  Result := nil;
end;

function GetICodeOpByIndex(pInstr: pICodeNode; iOpIndex: Integer): pOp;
var
  pCurrNode: pLinkedListNode;
  iCurrNode: Integer;
begin
  if pInstr.Instr.OpList.iNodeCount = 0 then
  begin
    Result := nil;
    Exit;
  end;

  pCurrNode := pInstr.Instr.OpList.pHead;

  for iCurrNode := 0 to pInstr.Instr.OpList.iNodeCount - 1 do
  begin
    if iOpIndex = iCurrNode then
    begin
      Result := pOp(pCurrNode.pData);
      Exit;
    end;
    pCurrNode := pCurrNode.pNext;
  end;
  Result := nil;
end;

procedure AddICodeOp(iFuncIndex: Integer; iInstrIndex: Integer; Value: Op);
var
  pInstr: pICodeNode;
  pValue: pOp;
begin
  pInstr := GetICodeNodeByImpIndex(iFuncIndex, iInstrIndex);
  GetMem(pValue, SizeOf(Op));
  Move(Value, pValue^, SizeOf(Op));

  AddNode(@pInstr.Instr.OpList, pValue);
end;

// ----------------------------------------------------------
procedure AddIntICodeOp(iFuncIndex: Integer; iInstrIndex: Integer; iValue: Integer);
var
  Value: Op;
begin
  Value.iType := OP_TYPE_INT;
  Value.iIntLiteral := iValue;

  AddICodeOp(iFuncIndex, iInstrIndex, Value);
end;

procedure AddFloatICodeOp(iFuncIndex: Integer; iInstrIndex: Integer; fValue: Real);
var
  Value: Op;
begin
  Value.iType := OP_TYPE_FLOAT;
  Value.fFloatLiteral := fValue;

  AddICodeOp(iFuncIndex, iInstrIndex, Value);
end;

procedure AddStringICodeOp(iFuncIndex: Integer; iInstrIndex: Integer; iStringIndex: Integer);
var
  Value: Op;
begin
  Value.iType := OP_TYPE_STRING_INDEX;
  Value.iStringIndex := iStringIndex;

  AddICodeOp(iFuncIndex, iInstrIndex, Value);
end;

procedure AddVarICodeOp(iFuncIndex: Integer; iInstrIndex: Integer; iSymbolIndex: Integer);
var
  Value: Op;
begin
  Value.iType := OP_TYPE_VAR;
  Value.iSymbolIndex := iSymbolIndex;

  AddICodeOp(iFuncIndex, iInstrIndex, Value);
end;

procedure AddArrayIndexABSICodeOp(iFuncIndex: Integer; iInstrIndex: Integer;
  iArraySymbolIndex: Integer; iOffset: Integer);
var
  Value: Op;
begin
  Value.iType := OP_TYPE_ARRAY_INDEX_ABS;
  Value.iSymbolIndex := iArraySymbolIndex;
  Value.iOffset := iOffset;
  AddICodeOp(iFuncIndex, iInstrIndex, Value);
end;

procedure AddArrayIndexVarICodeOp(iFuncIndex: Integer; iInstrIndex: Integer;
  iArraySymbolIndex: Integer; iOffsetSymbolIndex: Integer);
var
  Value: Op;
begin
  Value.iType := OP_TYPE_ARRAY_INDEX_VAR;
  Value.iSymbolIndex := iArraySymbolIndex;

  AddICodeOp(iFuncIndex, iInstrIndex, Value);
end;

procedure AddFuncICodeOp(iFuncIndex: Integer; iInstrIndex: Integer; iOpFuncIndex: Integer);
var
  Value: Op;
begin
  Value.iType := OP_TYPE_FUNC_INDEX;
  Value.iFuncIndex := iOpFuncIndex;

  AddICodeOp(iFuncIndex, iInstrIndex, Value);
end;

procedure AddRegICodeOp(iFuncIndex: Integer; iInstrIndex: Integer; iRegCode: Integer);
var
  Value: Op;
begin
  Value.iType := OP_TYPE_REG;
  Value.iRegCode := iRegCode;

  AddICodeOp(iFuncIndex, iInstrIndex, Value);
end;

procedure AddJumpTargetICodeOp(iFuncIndex: Integer; iInstrIndex: Integer; iTargetIndex: Integer);
var
  Value: Op;
begin
  Value.iType := OP_TYPE_JUMP_TARGET_INDEX;
  Value.iJumpTargetIndex := iTargetIndex;

  AddICodeOp(iFuncIndex, iInstrIndex, Value);
end;

// ----------------------------------------------------------
procedure AddICodeJumpTarget(iFuncIndex: Integer; iTargetIndex: Integer);
var
  pFunc: pFuncNode;
  pSourceLineNode: pICodeNode;
begin
  pFunc := GetFuncByIndex(iFuncIndex);
  GetMem(pSourceLineNode, SizeOf(ICodeNode));

  pSourceLineNode.iType := ICODE_NODE_JUMP_TARGET;
  pSourceLineNode.iJumpTargetIndex := iTargetIndex;

  AddNode(@pFunc.ICodeStream, pSourceLineNode);
end;

function GetNextJumpTargetIndex(): Integer;
begin
  Result := g_iCurrJumpTargetIndex;
  Inc(g_iCurrJumpTargetIndex);
end;

procedure AddICodeSourceLine(iFuncIndex: Integer; pstrSourceLine: PAnsiChar);
var
  pFunc: pFuncNode;
  pSourceLineNode: pICodeNode;
begin
  pFunc := GetFuncByIndex(iFuncIndex);

  GetMem(pSourceLineNode, SizeOf(ICodeNode));

  pSourceLineNode.iType := ICODE_NODE_SOURCE_LINE;
  pSourceLineNode.pstrSourceLine := pstrSourceLine;

  AddNode(@pFunc.ICodeStream, pSourceLineNode);
end;

// ----------------------------------------------------------
end.
