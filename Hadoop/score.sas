*------------------------------------------------------------*;
* EM SCORE CODE;
* EM Version: 13.2;
* SAS Release: 9.04.01M2P072314;
* Host: germsz-1;
* Encoding: wlatin1;
* Locale: en_US;
* Project Path: C:\Projects\EM;
* Project Name: My Project;
* Diagram Id: EMWS11;
* Diagram Name: HANA Scoring;
* Generated by: sasdemo;
* Date: 19SEP2014:13:52:44;
*------------------------------------------------------------*;
*------------------------------------------------------------*;
* TOOL: Input Data Source;
* TYPE: SAMPLE;
* NODE: Ids;
*------------------------------------------------------------*;
*------------------------------------------------------------*;
* TOOL: Extension Class;
* TYPE: HPDM;
* NODE: HPPart;
*------------------------------------------------------------*;
*------------------------------------------------------------*;
* TOOL: Extension Class;
* TYPE: TRANSFORM;
* NODE: HPImp;
*------------------------------------------------------------*;
Label IMP_CLAGE = 'Imputed CLAGE';
if missing("CLAGE"n) then IMP_CLAGE = 172.2000922;
else IMP_CLAGE ="CLAGE"n;
Label IMP_CLNO = 'Imputed CLNO';
if missing("CLNO"n) then IMP_CLNO = 20;
else IMP_CLNO ="CLNO"n;
Label IMP_DEBTINC = 'Imputed DEBTINC';
if missing("DEBTINC"n) then IMP_DEBTINC = 34.777089425;
else IMP_DEBTINC ="DEBTINC"n;
Label IMP_DELINQ = 'Imputed DELINQ';
if missing("DELINQ"n) then IMP_DELINQ = 0;
else IMP_DELINQ ="DELINQ"n;
Label IMP_DEROG = 'Imputed DEROG';
if missing("DEROG"n) then IMP_DEROG = 0;
else IMP_DEROG ="DEROG"n;
Label IMP_JOB = 'Imputed JOB';
Length IMP_JOB $7;
if missing("JOB"n) then IMP_JOB = 'OTHER';
else IMP_JOB ="JOB"n;
Label IMP_MORTDUE = 'Imputed MORTDUE';
if missing("MORTDUE"n) then IMP_MORTDUE = 64799;
else IMP_MORTDUE ="MORTDUE"n;
Label IMP_REASON = 'Imputed REASON';
Length IMP_REASON $7;
if missing("REASON"n) then IMP_REASON = 'DEBTCON';
else IMP_REASON ="REASON"n;
Label IMP_VALUE = 'Imputed VALUE';
if missing("VALUE"n) then IMP_VALUE = 89453;
else IMP_VALUE ="VALUE"n;
Label IMP_YOJ = 'Imputed YOJ';
if missing("YOJ"n) then IMP_YOJ = 7;
else IMP_YOJ ="YOJ"n;
*------------------------------------------------------------*;
* TOOL: Extension Class;
* TYPE: MODEL;
* NODE: HPTree;
*------------------------------------------------------------*;
****************************************************************;
******        HP TREE (PROC HPSPLIT) SCORING CODE        ******;
****************************************************************;
 
******         LENGTHS OF NEW CHARACTER VARIABLES         ******;
LABEL _NODE_ = 'Node number';
LABEL _LEAF_ = 'Leaf number';
LABEL _WARN_ = 'Warnings';
LABEL P_BAD1 = 'Predicted: BAD=1';
LABEL P_BAD0 = 'Predicted: BAD=0';
LABEL V_BAD1 = 'Validated: BAD=1';
LABEL V_BAD0 = 'Validated: BAD=0';
 
 _WARN_ = ' ';
 
******      TEMPORARY VARIABLES FOR FORMATTED VALUES      ******;
LENGTH _RT_7_7 $7;
_RT_7_7 = ' ';
DROP _RT_7_7;
_RT_7_7 = PUT(IMP_REASON, $7.);
%DMNORMIP(_RT_7_7);
LENGTH _RT_8_12 $12;
_RT_8_12 = ' ';
DROP _RT_8_12;
_RT_8_12 = PUT(IMP_DELINQ, BEST12.);
%DMNORMIP(_RT_8_12);
LENGTH _RT_9_12 $12;
_RT_9_12 = ' ';
DROP _RT_9_12;
_RT_9_12 = PUT(IMP_DEROG, BEST12.);
%DMNORMIP(_RT_9_12);
LENGTH _RT_10_7 $7;
_RT_10_7 = ' ';
DROP _RT_10_7;
_RT_10_7 = PUT(IMP_JOB, $7.);
%DMNORMIP(_RT_10_7);
 
******             ASSIGN OBSERVATION TO NODE             ******;
IF NOT MISSING(IMP_DELINQ) AND (_RT_8_12 IN ('1','2','3','4','5','6','7') )
 THEN DO;
  IF NOT MISSING(IMP_DEBTINC) AND ((IMP_DEBTINC >=34.99839962630492))
 THEN DO;
    IF NOT MISSING(IMP_DEBTINC) AND ((IMP_DEBTINC >=45.13778210009168))
 THEN DO;
      _NODE_ = 10;
      _LEAF_ = 0;
      P_BAD1 = 1;
      P_BAD0 = 0;
      V_BAD1 = 1;
      V_BAD0 = 0;
    END;
    ELSE DO;
      IF NOT MISSING(IMP_CLNO) AND ((IMP_CLNO >=30.53))
 THEN DO;
        IF NOT MISSING(IMP_VALUE) AND ((IMP_VALUE <67353.63))
 THEN DO;
          _NODE_ = 29;
          _LEAF_ = 8;
          P_BAD1 = 0;
          P_BAD0 = 1;
          V_BAD1 = 0;
          V_BAD0 = 1;
        END;
        ELSE DO;
          IF NOT MISSING(IMP_CLAGE) AND ((IMP_CLAGE >=210.2820409700356))
 THEN DO;
            _NODE_ = 44;
            _LEAF_ = 13;
            P_BAD1 = 0.17647059;
            P_BAD0 = 0.82352941;
            V_BAD1 = 0.25;
            V_BAD0 = 0.75;
          END;
          ELSE DO;
            IF NOT MISSING(IMP_YOJ) AND ((IMP_YOJ <2.05))
 THEN DO;
              _NODE_ = 61;
              _LEAF_ = 24;
              P_BAD1 = 0.16666667;
              P_BAD0 = 0.83333333;
              V_BAD1 = 0;
              V_BAD0 = 1;
            END;
            ELSE DO;
              _NODE_ = 62;
              _LEAF_ = 25;
              P_BAD1 = 0.8;
              P_BAD0 = 0.2;
              V_BAD1 = 0.75;
              V_BAD0 = 0.25;
            END;
        END;
      END;
    END;
    ELSE DO;
      IF NOT MISSING(IMP_CLAGE) AND ((IMP_CLAGE <93.45868487557138))
 THEN DO;
        _NODE_ = 27;
        _LEAF_ = 7;
        P_BAD1 = 0.29032258;
        P_BAD0 = 0.70967742;
        V_BAD1 = 0.6;
        V_BAD0 = 0.4;
      END;
      ELSE DO;
        IF NOT MISSING(IMP_YOJ) AND ((IMP_YOJ >=9.02))
 THEN DO;
          _NODE_ = 42;
          _LEAF_ = 12;
          P_BAD1 = 0.027027027;
          P_BAD0 = 0.97297297;
          V_BAD1 = 0.096774194;
          V_BAD0 = 0.90322581;
        END;
        ELSE DO;
          IF NOT MISSING(IMP_MORTDUE) AND ((IMP_MORTDUE <45786.57))
 THEN DO;
            _NODE_ = 59;
            _LEAF_ = 22;
            P_BAD1 = 0.5;
            P_BAD0 = 0.5;
            V_BAD1 = 0.6;
            V_BAD0 = 0.4;
          END;
          ELSE DO;
            _NODE_ = 60;
            _LEAF_ = 23;
            P_BAD1 = 0.12621359;
            P_BAD0 = 0.87378641;
            V_BAD1 = 0.076923077;
            V_BAD0 = 0.92307692;
          END;
        END;
      END;
    END;
  END;
END;
ELSE DO;
  IF NOT MISSING(IMP_DEBTINC) AND ((IMP_DEBTINC <32.97052313154756))
 THEN DO;
    IF NOT MISSING(IMP_DEBTINC) AND ((IMP_DEBTINC <8.636005194459299))
 THEN DO;
      _NODE_ = 15;
      _LEAF_ = 2;
      P_BAD1 = 1;
      P_BAD0 = 0;
      V_BAD1 = 1;
      V_BAD0 = 0;
    END;
    ELSE DO;
      _NODE_ = 16;
      _LEAF_ = 3;
      P_BAD1 = 0.13636364;
      P_BAD0 = 0.86363636;
      V_BAD1 = 0.14666667;
      V_BAD0 = 0.85333333;
    END;
  END;
  ELSE DO;
    IF NOT MISSING(IMP_DELINQ) AND (_RT_8_12 IN ('3','4','5','6') )
 THEN DO;
      _NODE_ = 17;
      _LEAF_ = 4;
      P_BAD1 = 0.85714286;
      P_BAD0 = 0.14285714;
      V_BAD1 = 0.925;
      V_BAD0 = 0.075;
    END;
    ELSE DO;
      _NODE_ = 18;
      _LEAF_ = 5;
      P_BAD1 = 0.66141732;
      P_BAD0 = 0.33858268;
      V_BAD1 = 0.67479675;
      V_BAD0 = 0.32520325;
    END;
  END;
END;
END;
ELSE DO;
IF NOT MISSING(IMP_DEBTINC) AND ((IMP_DEBTINC <32.97052313154756))
 THEN DO;
  IF NOT MISSING(IMP_YOJ) AND ((IMP_YOJ <5.33))
 THEN DO;
    IF NOT MISSING(IMP_MORTDUE) AND ((IMP_MORTDUE <37836.83))
 THEN DO;
      IF NOT MISSING(IMP_CLAGE) AND ((IMP_CLAGE <70.09401365667853))
 THEN DO;
        _NODE_ = 31;
        _LEAF_ = 9;
        P_BAD1 = 0;
        P_BAD0 = 1;
        V_BAD1 = 0.2;
        V_BAD0 = 0.8;
      END;
      ELSE DO;
        IF NOT MISSING(LOAN) AND ((LOAN <12644))
 THEN DO;
          _NODE_ = 45;
          _LEAF_ = 14;
          P_BAD1 = 0.64285714;
          P_BAD0 = 0.35714286;
          V_BAD1 = 0.75;
          V_BAD0 = 0.25;
        END;
        ELSE DO;
          _NODE_ = 46;
          _LEAF_ = 15;
          P_BAD1 = 0.13333333;
          P_BAD0 = 0.86666667;
          V_BAD1 = 0;
          V_BAD0 = 1;
        END;
      END;
    END;
    ELSE DO;
      IF NOT MISSING(LOAN) AND ((LOAN >=22412))
 THEN DO;
        _NODE_ = 34;
        _LEAF_ = 10;
        P_BAD1 = 0.18;
        P_BAD0 = 0.82;
        V_BAD1 = 0.058823529;
        V_BAD0 = 0.94117647;
      END;
      ELSE DO;
        IF NOT MISSING(IMP_JOB) AND (_RT_10_7 IN ('MGR','OFFICE') )
 THEN DO;
          _NODE_ = 48;
          _LEAF_ = 16;
          P_BAD1 = 0;
          P_BAD0 = 1;
          V_BAD1 = 0;
          V_BAD0 = 1;
        END;
        ELSE DO;
          IF NOT MISSING(IMP_VALUE) AND ((IMP_VALUE <67353.63))
 THEN DO;
            _NODE_ = 63;
            _LEAF_ = 26;
            P_BAD1 = 0;
            P_BAD0 = 1;
            V_BAD1 = 0.047619048;
            V_BAD0 = 0.95238095;
          END;
          ELSE DO;
            IF NOT MISSING(IMP_REASON) AND (_RT_7_7 IN ('HOMEIMP') )
 THEN DO;
              _NODE_ = 75;
              _LEAF_ = 34;
              P_BAD1 = 0.16129032;
              P_BAD0 = 0.83870968;
              V_BAD1 = 0.086956522;
              V_BAD0 = 0.91304348;
            END;
            ELSE DO;
              IF NOT MISSING(IMP_CLAGE) AND ((IMP_CLAGE <140.1880273133571))
 THEN DO;
                _NODE_ = 83;
                _LEAF_ = 40;
                P_BAD1 = 0.13793103;
                P_BAD0 = 0.86206897;
                V_BAD1 = 0.4;
                V_BAD0 = 0.6;
              END;
              ELSE DO;
                _NODE_ = 84;
                _LEAF_ = 41;
                P_BAD1 = 0.024390244;
                P_BAD0 = 0.97560976;
                V_BAD1 = 0;
                V_BAD0 = 1;
              END;
            END;
          END;
        END;
      END;
    END;
  END;
  ELSE DO;
    _NODE_ = 12;
    _LEAF_ = 1;
    P_BAD1 = 0.02147651;
    P_BAD0 = 0.97852349;
    V_BAD1 = 0.0094637224;
    V_BAD0 = 0.99053628;
  END;
END;
ELSE DO;
  IF NOT MISSING(IMP_DEBTINC) AND ((IMP_DEBTINC <34.99839962630492))
 THEN DO;
    IF NOT MISSING(IMP_CLAGE) AND ((IMP_CLAGE >=175.2350341416963))
 THEN DO;
      IF NOT MISSING(IMP_YOJ) AND ((IMP_YOJ <0.82))
 THEN DO;
        _NODE_ = 37;
        _LEAF_ = 11;
        P_BAD1 = 0.60869565;
        P_BAD0 = 0.39130435;
        V_BAD1 = 0.25;
        V_BAD0 = 0.75;
      END;
      ELSE DO;
        IF NOT MISSING(IMP_DEROG) AND (_RT_9_12 IN ('1','2') )
 THEN DO;
          _NODE_ = 53;
          _LEAF_ = 19;
          P_BAD1 = 0.5;
          P_BAD0 = 0.5;
          V_BAD1 = 0.2;
          V_BAD0 = 0.8;
        END;
        ELSE DO;
          IF NOT MISSING(IMP_CLNO) AND ((IMP_CLNO >=33.37))
 THEN DO;
            IF NOT MISSING(LOAN) AND ((LOAN >=20636))
 THEN DO;
              _NODE_ = 80;
              _LEAF_ = 37;
              P_BAD1 = 0.57142857;
              P_BAD0 = 0.42857143;
              V_BAD1 = 0.8;
              V_BAD0 = 0.2;
            END;
            ELSE DO;
              _NODE_ = 79;
              _LEAF_ = 36;
              P_BAD1 = 0.16129032;
              P_BAD0 = 0.83870968;
              V_BAD1 = 0.11764706;
              V_BAD0 = 0.88235294;
            END;
          END;
          ELSE DO;
            _NODE_ = 69;
            _LEAF_ = 30;
            P_BAD1 = 0.12653061;
            P_BAD0 = 0.87346939;
            V_BAD1 = 0.11881188;
            V_BAD0 = 0.88118812;
          END;
        END;
      END;
    END;
    ELSE DO;
      IF NOT MISSING(LOAN) AND ((LOAN <7316))
 THEN DO;
        IF NOT MISSING(IMP_REASON) AND (_RT_7_7 IN ('DEBTCON') )
 THEN DO;
          _NODE_ = 50;
          _LEAF_ = 18;
          P_BAD1 = 0.51612903;
          P_BAD0 = 0.48387097;
          V_BAD1 = 0.33333333;
          V_BAD0 = 0.66666667;
        END;
        ELSE DO;
          _NODE_ = 49;
          _LEAF_ = 17;
          P_BAD1 = 0.84;
          P_BAD0 = 0.16;
          V_BAD1 = 0.7037037;
          V_BAD0 = 0.2962963;
        END;
      END;
      ELSE DO;
        IF NOT MISSING(IMP_CLNO) AND ((IMP_CLNO <5.68))
 THEN DO;
          IF NOT MISSING(IMP_VALUE) AND ((IMP_VALUE >=92790.89999999999))
 THEN DO;
            _NODE_ = 66;
            _LEAF_ = 27;
            P_BAD1 = 1;
            P_BAD0 = 0;
            V_BAD1 = 1;
            V_BAD0 = 0;
          END;
          ELSE DO;
            IF NOT MISSING(LOAN) AND ((LOAN >=18860))
 THEN DO;
              _NODE_ = 78;
              _LEAF_ = 35;
              P_BAD1 = 0.33333333;
              P_BAD0 = 0.66666667;
              V_BAD1 = 0.5;
              V_BAD0 = 0.5;
            END;
            ELSE DO;
              IF NOT MISSING(IMP_CLNO) AND ((IMP_CLNO <1.42))
 THEN DO;
                _NODE_ = 85;
                _LEAF_ = 42;
                P_BAD1 = 1;
                P_BAD0 = 0;
                V_BAD1 = 0.75;
                V_BAD0 = 0.25;
              END;
              ELSE DO;
                IF NOT MISSING(IMP_MORTDUE) AND ((IMP_MORTDUE <41811.7))
 THEN DO;
                  _NODE_ = 87;
                  _LEAF_ = 43;
                  P_BAD1 = 0.8;
                  P_BAD0 = 0.2;
                  V_BAD1 = 0;
                  V_BAD0 = 1;
                END;
                ELSE DO;
                  _NODE_ = 88;
                  _LEAF_ = 44;
                  P_BAD1 = 0.6;
                  P_BAD0 = 0.4;
                  V_BAD1 = 1;
                  V_BAD0 = 0;
                END;
              END;
            END;
          END;
        END;
        ELSE DO;
          IF NOT MISSING(IMP_VALUE) AND ((IMP_VALUE >=92790.89999999999))
 THEN DO;
            _NODE_ = 68;
            _LEAF_ = 29;
            P_BAD1 = 0.24623116;
            P_BAD0 = 0.75376884;
            V_BAD1 = 0.29508197;
            V_BAD0 = 0.70491803;
          END;
          ELSE DO;
            _NODE_ = 67;
            _LEAF_ = 28;
            P_BAD1 = 0.43867925;
            P_BAD0 = 0.56132075;
            V_BAD1 = 0.52222222;
            V_BAD0 = 0.47777778;
          END;
        END;
      END;
    END;
  END;
  ELSE DO;
    IF NOT MISSING(IMP_DEBTINC) AND ((IMP_DEBTINC >=45.13778210009168))
 THEN DO;
      _NODE_ = 26;
      _LEAF_ = 6;
      P_BAD1 = 0.97619048;
      P_BAD0 = 0.023809524;
      V_BAD1 = 0.84615385;
      V_BAD0 = 0.15384615;
    END;
    ELSE DO;
      IF NOT MISSING(IMP_CLAGE) AND ((IMP_CLAGE >=175.2350341416963))
 THEN DO;
        IF NOT MISSING(IMP_VALUE) AND ((IMP_VALUE >=270851.79))
 THEN DO;
          _NODE_ = 58;
          _LEAF_ = 21;
          P_BAD1 = 0.27272727;
          P_BAD0 = 0.72727273;
          V_BAD1 = 1;
          V_BAD0 = 0;
        END;
        ELSE DO;
          _NODE_ = 57;
          _LEAF_ = 20;
          P_BAD1 = 0.019354839;
          P_BAD0 = 0.98064516;
          V_BAD1 = 0.025974026;
          V_BAD0 = 0.97402597;
        END;
      END;
      ELSE DO;
        IF NOT MISSING(IMP_MORTDUE) AND ((IMP_MORTDUE >=77585.53))
 THEN DO;
          IF NOT MISSING(IMP_DEBTINC) AND ((IMP_DEBTINC >=43.10990560533433))
 THEN DO;
            _NODE_ = 74;
            _LEAF_ = 33;
            P_BAD1 = 0.33333333;
            P_BAD0 = 0.66666667;
            V_BAD1 = 1;
            V_BAD0 = 0;
          END;
          ELSE DO;
            _NODE_ = 73;
            _LEAF_ = 32;
            P_BAD1 = 0.024154589;
            P_BAD0 = 0.97584541;
            V_BAD1 = 0.087912088;
            V_BAD0 = 0.91208791;
          END;
        END;
        ELSE DO;
          IF NOT MISSING(IMP_YOJ) AND ((IMP_YOJ >=8.199999999999999))
 THEN DO;
            IF NOT MISSING(IMP_CLNO) AND ((IMP_CLNO <9.23))
 THEN DO;
              _NODE_ = 81;
              _LEAF_ = 38;
              P_BAD1 = 0.86666667;
              P_BAD0 = 0.13333333;
              V_BAD1 = 0.75;
              V_BAD0 = 0.25;
            END;
            ELSE DO;
              _NODE_ = 82;
              _LEAF_ = 39;
              P_BAD1 = 0.16190476;
              P_BAD0 = 0.83809524;
              V_BAD1 = 0.14285714;
              V_BAD0 = 0.85714286;
            END;
          END;
          ELSE DO;
            _NODE_ = 71;
            _LEAF_ = 31;
            P_BAD1 = 0.079207921;
            P_BAD0 = 0.92079208;
            V_BAD1 = 0.10569106;
            V_BAD0 = 0.89430894;
          END;
        END;
      END;
    END;
  END;
END;
END;
****************************************************************;
******     END OF HP TREE (PROC HPSPLIT) SCORING CODE    ******;
****************************************************************;
*------------------------------------------------------------*;
*Computing Classification Vars: BAD;
*------------------------------------------------------------*;
length I_BAD $12;
label  I_BAD = 'Bis: BAD';
length _format200 $200;
drop _format200;
_format200= ' ' ;
_p_= 0 ;
drop _p_ ;
if P_BAD1 - _p_ > 1e-8 then do ;
   _p_= P_BAD1 ;
   _format200='1';
end;
if P_BAD0 - _p_ > 1e-8 then do ;
   _p_= P_BAD0 ;
   _format200='0';
end;
I_BAD=dmnorm(_format200,32); ;
label U_BAD = 'Unnormalized Into: BAD';
if I_BAD='1' then
U_BAD=1;
if I_BAD='0' then
U_BAD=0;
*------------------------------------------------------------*;
* TOOL: Model Compare Class;
* TYPE: ASSESS;
* NODE: MdlComp;
*------------------------------------------------------------*;
*------------------------------------------------------------*;
* TOOL: Score Node;
* TYPE: ASSESS;
* NODE: Score;
*------------------------------------------------------------*;
*------------------------------------------------------------*;
* Score: Creating Fixed Names;
*------------------------------------------------------------*;
LABEL EM_SEGMENT = 'Leaf number';
EM_SEGMENT = _LEAF_;
LABEL EM_EVENTPROBABILITY = 'Probability for level 1 of BAD';
EM_EVENTPROBABILITY = P_BAD1;
LABEL EM_PROBABILITY = 'Probability of Classification';
EM_PROBABILITY =
max(
P_BAD1
,
P_BAD0
);
LENGTH EM_CLASSIFICATION $%dmnorlen;
LABEL EM_CLASSIFICATION = "Prediction for BAD";
EM_CLASSIFICATION = I_BAD;
