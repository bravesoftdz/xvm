unit script_header;

interface

// ----Data Structures
// ----Script
type
  _ScriptHeader = record
    iStackSize: integer; // Ҫ��Ķ�ջ��С
    iIsMainFuncPresent: integer; // _Main�Ƿ����
    iMainFuncIndex: integer; // _Main����
    iPriorityType: integer; // �߳����ȼ�
    iUserPriority: integer; // �û���������ȼ�
  end;

  ScriptHeader = _ScriptHeader;

implementation

end.
