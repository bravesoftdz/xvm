unit xvm_types;

interface

uses xvm_globals;

type
  _ScriptHeader = record
    iStackSize: integer; // ����Ķ�ջ��С
    iGlobalDataSize: integer; // �ű���С
    // ȫ������
    iIsMainFuncPresent: integer; // _Main�Ƿ����
    iMainFuncIndex: integer; // _Main����
    iPriorityType: integer; // �߳����ȼ�����  0.8
    iUserPriorty: integer; // �û���������ȼ�(����еĻ�) 0.8
  end;

  ScriptHeader = _ScriptHeader;

  // --------Instruction Lookup Table ָ����ұ�----------------
type
  OpType = integer;
  pOpType = ^OpType;

  _InstrLookup = record
    // �����ַ���
    pstrMnemonic: array [0 .. MAX_INSTR_MNEMONIC_SIZE - 1] of AnsiChar;
    // ������
    iOpcode: integer;
    // ����������
    iOpcount: integer;
    // �������б�ָ��
    OpList: pOpType;
  end;

  InstrLookup = _InstrLookup;
  pInstrLookup = ^InstrLookup;

  // --------Assembled Instruction Stream  ���ָ����
type
  _Op = record // ��������
    iType: integer; // ����
    iOffserIndex: integer; // ����ƫ��
    case integer of
      0:
        (iIntLiteral: integer); // ��������ֵ
      1:
        (fFloatLiteral: Single); // ��������ֵ
      2:
        (iStringTableIndex: integer); // �ַ���������
      3:
        (iStackIndex: integer); // ջ����
      4:
        (iInstrIndex: integer); // ָ������
      5:
        (iFuncIndex: integer); // ��������
      6:
        (iHostAPICallIndex: integer); // ��API��������
      7:
        (iReg: integer); // Register code  �Ĵ���
  end;

  OP = _Op;
  pOP = ^OP;

type
  _Instr = record // An instruction
    iOpcode: integer; // ������
    iOpcount: integer; // Number of operands
    pOpList: pOP; // Point to operand list
  end;

  InStr = _Instr;

type
  _FuncNode = record // һ�������ڵ�
    iIndex: integer; // ����
    pstrName: array [0 .. MAX_IDENT_SIZE - 1] of AnsiChar;
    iEntryPoint: integer; // ���
    iParamCount: integer; // ��������
    iLocalDataSize: integer; // �ֲ���ջ��С
  end;

  FuncNode = _FuncNode;
  pFuncNode = ^FuncNode;

  // ----------Label Table-------------
type

  _LabelNode = record // a node
    iIndex: integer; // ����
    pstrIdent: array [0 .. MAX_IDENT_SIZE - 1] of AnsiChar; // identifier
    iTargetIndex: integer; // Ŀ��ָ������
    iFuncIndex: integer; // function in which then label resides
  end;

  LabelNode = _LabelNode;
  pLabelNode = ^LabelNode;

  // ----------Symbol Table------------
type
  _SymbolNode = record
    iIndex: integer; // ����
    pstrIdent: array [0 .. MAX_IDENT_SIZE - 1] of AnsiChar; // ʶ����
    iSize: integer; // Size (1 for variables, N for arrays)
    iStackIndex: integer; // ջ����
    iFuncIndex: integer; // Function in which the symbol resides
  end;

  SymbolNode = _SymbolNode;
  pSymbolNode = ^SymbolNode;

implementation

end.
