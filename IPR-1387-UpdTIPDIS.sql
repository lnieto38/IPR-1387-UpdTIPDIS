CREATE OR REPLACE PACKAGE SGCVNZ.PQPCLRLOAD
IS

gRetN       NUMBER;
gRetC       VARCHAR2(512);
gIRDMCM     CHAR(2):=NULL; -- IRD MasterCard Maestro
gNumERR     NUMBER:=0;

FUNCTION RevCarga (pFecSesion DATE, pHoraProc CHAR:=NULL) RETURN CHAR;

FUNCTION RevCargaXID (pIDClrLoad NUMBER) RETURN CHAR;

FUNCTION GenFileCTL (pIDClrLoad NUMBER, pCodArchivo CHAR,
                     pFecSesion DATE, pHoraProc CHAR) RETURN CHAR;
FUNCTION GenFileCFG (pNomArchivo CHAR) RETURN CHAR;

FUNCTION GetIDCLRLOAD (pFecSesion DATE,pCodArchivo CHAR, pHoraProc CHAR) RETURN CHAR;

FUNCTION InsCTL (pFecSesion DATE,pCodArchivo CHAR, pHoraProc CHAR,
                 pNomLOG CHAR:=NULL) RETURN CHAR;

FUNCTION UpdCTL (pIDClrLoad NUMBER, pEstProc CHAR) RETURN CHAR;

FUNCTION UpdCtaBan (pFecSesion DATE, pHoraProc CHAR) RETURN CHAR;
FUNCTION UpdComIntMC (pFecSesion DATE, pHoraProc CHAR) RETURN CHAR;

PROCEDURE VrfCarga (pFecSesion DATE:=NULL, pHoraProc CHAR:=NULL);

FUNCTION GetStatusCLRLOAD (pFecSesion DATE,Estado CHAR,pHoraProc CHAR) RETURN CHAR;
FUNCTION GetTIPO_TRAN3SUB(pTIPO_TRAN3 CHAR, pP02NUMTAR CHAR, pP48TIPMOV CHAR, pP48FILLER CHAR) RETURN CHAR;
FUNCTION UpdImpProv (pFecSesion DATE, pHoraProc CHAR) RETURN CHAR;
FUNCTION UpdNumTar (pFecSesion DATE, pHoraProc CHAR) RETURN CHAR;
FUNCTION UpdTipDis (pFecSesion DATE, pHoraProc CHAR) RETURN CHAR; -- FJVG  -IPR1387 CONTACTLESS 21/12/2022 TIPO DE DISPOSITIVOS 
-- IPR 1044 - JVJ
FUNCTION f_LoadLiqLote (pFecSesion DATE, pHoraProc CHAR) RETURN CHAR;
FUNCTION f_LoadLiqLoteXID (pFecSesion DATE, pCodArchivo CHAR, pIDClrLoad NUMBER, pIDproc NUMBER) RETURN CHAR;
FUNCTION f_UpdateLiqLote (pFecSesion DATE, pHraProceso CHAR) RETURN CHAR;
FUNCTION GetIDLIQLOTE (pFecSesion DATE,pCodComercio CHAR, pNroSerie CHAR, pNumLote CHAR) RETURN NUMBER;
-- Fin IPR 1044

END; -- PQPCLRLOAD_IPR1387
/




-----------------------------------------------------------------------------------------------------------------------------------------------



CREATE OR REPLACE PACKAGE BODY SGCVNZ.PQPCLRLOAD
IS
-- Modificaci??????n -> crosadof -> adaptacion de todo el package para PCI DSS
-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
-- FUNCTION GenFileCTL
-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

FUNCTION GenFileCTL (pIDClrLoad NUMBER, pCodArchivo CHAR, pFecSesion DATE, pHoraProc CHAR) RETURN CHAR
IS

vFileHandle  UTL_FILE.FILE_TYPE;
vFileCTL     VARCHAR2(40);
vFile        VARCHAR2(40);
vCodFormato  CFG_CLRLOAD.COD_FORMATO%TYPE;
vNomTabla    CFG_CLRLOAD.NOM_TABLA%TYPE;
vDirTMP      VARCHAR2(50):=NULL;
vfecha       VARCHAR2(8);

vOraCode     NUMBER:=0;

procedure put_txt(pTXT char)
is
begin
  UTL_FILE.PUT(vFileHandle,pTXT);
  UTL_FILE.NEW_LINE(vFileHandle);
end;

BEGIN
  -- Datos de la Carga
  BEGIN
    SELECT COD_FORMATO,
           NOM_TABLA
      INTO vCodFormato,
           vNomTabla
      FROM CFG_CLRLOAD
     WHERE COD_ARCHIVO = pCodArchivo;
  EXCEPTION
    WHEN NO_DATA_FOUND THEN
         RETURN 'E|Codigo de Archivo Incorrecto.';
  END;
  -- Creacion del Archivo CTL
  vDirTMP:=STD.F_GETVALPAR('DIR-TMP');
  vFileCTL:=pCodArchivo||TO_CHAR(pFecSesion,'YYYYMMDD')||pHoraProc||'.CTL';
  vFile:= pCodArchivo||TO_CHAR(pFecSesion,'YYYYMMDD')||pHoraProc||'.DAT';
  vFileHandle:=UTL_FILE.FOPEN(vDirTMP,vFileCTL,'W');
  vfecha:=TO_CHAR(pFecSesion,'YYYYMMDD');
  put_txt('LOAD DATA');

  IF vCodFormato = 'EXMX' OR vCodFormato = 'ACCP' THEN -- JMG 01/10/2012: FORMATO ACCP
     put_txt('CHARACTERSET WE8ISO8859P1');
     put_txt('INFILE '||vFile||' "fix 1025"');
  END IF;

  IF vCodFormato = 'OTRO' THEN
     put_txt('CHARACTERSET WE8ISO8859P1');
     put_txt('INFILE '||vFile||' "fix 377"');
  END IF;

  IF vCodFormato = 'AX01' OR vCodFormato = 'AX02' THEN
     put_txt('CHARACTERSET WE8ISO8859P1');
     put_txt('INFILE '||vFile||' "fix 101"');
  END IF;

 IF vCodFormato = 'OTRO' THEN
  put_txt('APPEND');
  put_txt('INTO TABLE CLR_DCEMVFULL_IPR1387');
 ELSE
  put_txt('APPEND');
  put_txt('INTO TABLE '||vNomTabla);
  END IF;
  -- Formato ACTC
  IF vCodFormato IN ('ACTC','EXMX') THEN
     put_txt('(ID_CLRLOAD      CONSTANT '||pIDClrLoad);
     put_txt(',COD_HRCIERRE    POSITION(672:672)  CHAR');
     put_txt(',ID_REGISTRO     RECNUM');
     put_txt(',IDEMEN_P00_ACTC POSITION(001:004)  CHAR');
     put_txt(',LONTAR_L02_ACTC POSITION(021:022)  CHAR');
     -- put_txt(',NUMTAR_P02_ACTC POSITION(023:041)  CHAR');
     put_txt(',CODPRO_P03_ACTC POSITION(042:047)  CHAR');
     put_txt(',IMPTRA_P04_ACTC POSITION(048:059)  CHAR');
     put_txt(',IMPCON_P05_ACTC POSITION(060:071)  CHAR');
     put_txt(',IMPTIT_P06_ACTC POSITION(072:083)  CHAR');
     put_txt(',CONCON_P09_ACTC POSITION(084:091)  CHAR');
     put_txt(',CONCLI_P10_ACTC POSITION(092:099)  CHAR');
     put_txt(',IDETRA_P11_ACTC POSITION(100:105)  CHAR');
     put_txt(',TIMLOC_P12_ACTC POSITION(106:117)  CHAR');
     put_txt(',FECCAD_P14_ACTC POSITION(118:121)  CHAR');
     put_txt(',FECCON_P16_ACTC POSITION(122:125)  CHAR');
     put_txt(',FECCAP_P17_ACTC POSITION(126:129)  CHAR');
     put_txt(',CODACT_P18_ACTC POSITION(130:133)  CHAR');
     put_txt(',CODPAI_P19_ACTC POSITION(134:136)  CHAR');
     put_txt(',PUNSER_P22_ACTC POSITION(137:148)  CHAR');
     put_txt(',CODFUN_P24_ACTC POSITION(149:151)  CHAR');
     put_txt(',CODRAZ_P25_ACTC POSITION(152:155)  CHAR');
     put_txt(',CODACT_P26_ACTC POSITION(156:159)  CHAR');
     put_txt(',SESION_P28_ACTC POSITION(160:165)  CHAR');
     put_txt(',INLOTE_P29_ACTC POSITION(166:168)  CHAR');
     put_txt(',IMPORI_P30_ACTC POSITION(169:180)  CHAR');
     put_txt(',ORICON_P30_ACTC POSITION(181:192)  CHAR');
     put_txt(',LONREF_L31_ACTC POSITION(193:194)  CHAR');
     put_txt(',REFADQ_P31_ACTC POSITION(195:217)  CHAR');
     put_txt(',IDEADQ_L32_ACTC POSITION(218:219)  CHAR');
     put_txt(',IDEADQ_P32_ACTC POSITION(220:230)  CHAR');
     put_txt(',IDEPRE_L33_ACTC POSITION(231:232)  CHAR');
     put_txt(',IDEPRE_P33_ACTC POSITION(233:243)  CHAR');
     put_txt(',LONPIS_L35_ACTC POSITION(244:245)  CHAR');
     put_txt(',PISTA2_P35_ACTC POSITION(246:282)  CHAR');
     put_txt(',DATREF_P37_ACTC POSITION(283:294)  CHAR');
     put_txt(',NUMAUT_P38_ACTC POSITION(295:300)  CHAR');
     put_txt(',CODACR_P39_ACTC POSITION(301:303)  CHAR');
     put_txt(',CODSER_P40_ACTC POSITION(304:306)  CHAR');
     put_txt(',IDETER_P41_ACTC POSITION(307:314)  CHAR');
     put_txt(',IDEEST_P42_ACTC POSITION(315:329)  CHAR');
     put_txt(',NOMEST_P43_ACTC POSITION(330:354)  CHAR');
     put_txt(',LOCEST_P43_ACTC POSITION(355:367)  CHAR');
     put_txt(',PAIEST_P43_ACTC POSITION(368:369)  CHAR');
     put_txt(',LONPI1_P45_ACTC POSITION(370:371)  CHAR');
     put_txt(',PISTA1_P45_ACTC POSITION(372:447)  CHAR');
     ---
     put_txt(',LONCTR_P46_ACTC POSITION(756:757)  CHAR'); --Cambio IPR 1272 09-08-2018/Cambio IPR 1334 07-10-2020
     put_txt(',TIPCU1_P46_ACTC POSITION(758:759)  CHAR'); --Cambio IPR 1272 09-08-2018/Cambio IPR 1334 07-10-2020
     put_txt(',SIGCU1_P46_ACTC POSITION(760:760)  CHAR'); --Cambio IPR 1272 09-08-2018/Cambio IPR 1334 07-10-2020
     put_txt(',IMPCU1_P46_ACTC POSITION(761:770)  CHAR'); --Cambio IPR 1272 09-08-2018/Cambio IPR 1334 07-10-2020
     put_txt(',TIPCU2_P46_ACTC POSITION(771:772)  CHAR'); --Cambio IPR 1272 09-08-2018/Cambio IPR 1334 07-10-2020
     put_txt(',SIGCU2_P46_ACTC POSITION(773:773)  CHAR'); --Cambio IPR 1272 09-08-2018/Cambio IPR 1334 07-10-2020
     put_txt(',IMPCU2_P46_ACTC POSITION(774:783)  CHAR'); --Cambio IPR 1272 09-08-2018/Cambio IPR 1334 07-10-2020
     put_txt(',TIPCU3_P46_ACTC POSITION(784:785)  CHAR'); --Cambio IPR 1272 09-08-2018/Cambio IPR 1334 07-10-2020
     put_txt(',SIGCU3_P46_ACTC POSITION(786:786)  CHAR'); --Cambio IPR 1272 09-08-2018/Cambio IPR 1334 07-10-2020
     put_txt(',IMPCU3_P46_ACTC POSITION(787:796)  CHAR'); --Cambio IPR 1272 09-08-2018/Cambio IPR 1334 07-10-2020
     put_txt(',TIPCU4_P46_ACTC POSITION(797:798)  CHAR'); --Cambio IPR 1272 09-08-2018/Cambio IPR 1334 07-10-2020
     put_txt(',SIGCU4_P46_ACTC POSITION(799:799)  CHAR'); --Cambio IPR 1272 09-08-2018/Cambio IPR 1334 07-10-2020
     put_txt(',IMPCU4_P46_ACTC POSITION(800:809)  CHAR'); --Cambio IPR 1272 09-08-2018/Cambio IPR 1334 07-10-2020
     ---
     put_txt(',LONDAT_P48_ACTC POSITION(494:496)  CHAR');
     put_txt(',LONR28_P48_ACTC POSITION(497:499)  CHAR');
     put_txt(',CODR28_P48_ACTC POSITION(500:501)  CHAR');
     put_txt(',MCASHB_P48_ACTC POSITION(502:510)  CHAR');
     -- put_txt(',LONR99_P48_ACTC POSITION(511:513)  CHAR');
     -- put_txt(',CODR99_P48_ACTC POSITION(514:515)  CHAR');
     -- put_txt(',FREE99_P48_ACTC POSITION(516:526)  CHAR');
     put_txt(',CMFLAT_P48_ACTC POSITION(511:515)  CHAR');
     put_txt(',TICEMI_P48_ACTC POSITION(516:517)  CHAR');
     put_txt(',SICEMI_P48_ACTC POSITION(518:518)  CHAR');
     put_txt(',INCEMI_P48_ACTC POSITION(519:526)  CHAR');
     put_txt(',LONR13_P48_ACTC POSITION(527:529)  CHAR');
     put_txt(',CODR13_P48_ACTC POSITION(530:531)  CHAR');
     put_txt(',TIPTRA_P48_ACTC POSITION(532:534)  CHAR');
     put_txt(',LONR14_P48_ACTC POSITION(535:537)  CHAR');
     put_txt(',CODR14_P48_ACTC POSITION(538:539)  CHAR');
     put_txt(',CTAABO_P48_ACTC POSITION(540:559)  CHAR');
     put_txt(',LONR16_P48_ACTC POSITION(560:562)  CHAR');
     put_txt(',CODR16_P48_ACTC POSITION(563:564)  CHAR');
     put_txt(',FECEST_P48_ACTC POSITION(565:570)  CHAR');
     put_txt(',LONR18_P48_ACTC POSITION(571:573)  CHAR');
     put_txt(',CODR18_P48_ACTC POSITION(574:575)  CHAR');
     put_txt(',LISTNE_P48_ACTC POSITION(576:580)  CHAR');
     put_txt(',LONR19_P48_ACTC POSITION(581:583)  CHAR');
     put_txt(',CODR19_P48_ACTC POSITION(584:585)  CHAR');
     put_txt(',LIMCON_P48_ACTC POSITION(586:586)  CHAR');
     put_txt(',LONR50_P48_ACTC POSITION(587:589)  CHAR');
     put_txt(',CODR50_P48_ACTC POSITION(590:591)  CHAR');
     put_txt(',VTAPLA_P48_ACTC POSITION(592:593)  CHAR');
     put_txt(',LONR51_P48_ACTC POSITION(594:596)  CHAR');
     put_txt(',CODR51_P48_ACTC POSITION(597:598)  CHAR');
     put_txt(',SWIAUT_P48_ACTC POSITION(599:599)  CHAR');
     put_txt(',ESTPRO_P48_ACTC POSITION(600:600)  CHAR');
     put_txt(',BINADQ_P48_ACTC POSITION(601:606)  CHAR');
     put_txt(',PORCUO_P48_ACTC POSITION(607:612)  CHAR');
     put_txt(',CODERR_P48_ACTC POSITION(613:617)  CHAR');
     put_txt(',TIMADQ_P48_ACTC POSITION(618:625)  CHAR');
     put_txt(',TIMRES_P48_ACTC POSITION(626:633)  CHAR');
     put_txt(',TIPMOV_P48_ACTC POSITION(634:634)  CHAR');
     put_txt(',MODING_P48_ACTC POSITION(635:635)  CHAR');
     -- put_txt(',PUNLEA_P48_ACTC POSITION(636:640)  CHAR');
     put_txt(',DIFERI_P48_ACTC POSITION(636:636)  CHAR');
     -- put_txt(',OTROSX_P48_ACTC POSITION(637:640)  CHAR');
     put_txt(',INDPRE_P48_ACTC POSITION(637:638)  CHAR');
     put_txt(',OTROSX_P48_ACTC POSITION(639:640)  CHAR');
     put_txt(',CODPRE_P48_ACTC POSITION(641:642)  CHAR');
     put_txt(',TIPPRE_P48_ACTC POSITION(643:643)  CHAR');
     put_txt(',TIPSOR_P48_ACTC POSITION(644:644)  CHAR');
     put_txt(',PREIMP_P48_ACTC POSITION(645:656)  CHAR');
     -- put_txt(',CODCIA_P48_ACTC POSITION(657:657)  CHAR');
     -- put_txt(',DOCIDE_P48_ACTC POSITION(658:668)  CHAR');
     -- put_txt(',NPLACA_P48_ACTC POSITION(669:674)  CHAR');
     -- put_txt(',INDDIR_P48_ACTC POSITION(675:675)  CHAR');
     -- put_txt(',TELEFO_P48_ACTC POSITION(676:687)  CHAR');
     -- put_txt(',FILLER_P48_ACTC POSITION(688:696)  CHAR');
     put_txt(',CODEMP_P48_ACTC POSITION(657:660)  CHAR');
     put_txt(',CODFUN_P48_ACTC POSITION(661:664)  CHAR');
     put_txt(',TIPOPE_P48_ACTC POSITION(665:665)  CHAR');
     put_txt(',NUMORI_P48_ACTC POSITION(666:671)  CHAR');
     put_txt(',NUMGUI_P48_ACTC POSITION(672:683)  CHAR');
     put_txt(',FILLER_P48_ACTC POSITION(684:696)  CHAR');
     put_txt(',MONTRA_P49_ACTC POSITION(697:699)  CHAR');
     put_txt(',MONCON_P50_ACTC POSITION(700:702)  CHAR');
     put_txt(',MONTIT_P51_ACTC POSITION(703:705)  CHAR');
     put_txt(',ORIDAT_L56_ACTC POSITION(706:707)  CHAR');
     put_txt(',ORIIDE_P56_ACTC POSITION(708:711)  CHAR');
     put_txt(',ORITRA_P56_ACTC POSITION(712:717)  CHAR');
     put_txt(',ORITIM_P56_ACTC POSITION(718:729)  CHAR');
     put_txt(',ORIADQ_L56_ACTC POSITION(730:731)  CHAR');
     put_txt(',ORIADQ_P56_ACTC POSITION(732:742)  CHAR');
     put_txt(',IDEAUT_L58_ACTC POSITION(743:744)  CHAR');
     put_txt(',IDEAUT_P58_ACTC POSITION(745:755)  CHAR');
     --put_txt(',LONMON_P62_ACTC POSITION(756:758)  CHAR'); Cambio realizado
     --put_txt(',LONR01_P62_ACTC POSITION(759:761)  CHAR'); para ampliar P46
     --put_txt(',CODR01_P62_ACTC POSITION(762:763)  CHAR'); TST 09/08/2018
     --put_txt(',MEFACT_P62_ACTC POSITION(764:769)  CHAR');
     --put_txt(',LONR02_P62_ACTC POSITION(770:772)  CHAR');
     --put_txt(',CODR02_P62_ACTC POSITION(773:774)  CHAR');
     --put_txt(',MENUTR_P62_ACTC POSITION(775:782)  CHAR');
     --put_txt(',LONR03_P62_ACTC POSITION(783:785)  CHAR');
     --put_txt(',CODR03_P62_ACTC POSITION(786:787)  CHAR');
     --put_txt(',MESALD_P62_ACTC POSITION(788:795)  CHAR');
     --put_txt(',LONR04_P62_ACTC POSITION(796:798)  CHAR');
     --put_txt(',CODR04_P62_ACTC POSITION(799:800)  CHAR');
     --put_txt(',MEFICH_P62_ACTC POSITION(801:804)  CHAR');
     --put_txt(',LONR05_P62_ACTC POSITION(805:807)  CHAR');
     --put_txt(',CODR05_P62_ACTC POSITION(808:809)  CHAR'); fin cambio
     put_txt(',MEULOP_P62_ACTC POSITION(810:813)  CHAR');
     put_txt(',LONR06_P62_ACTC POSITION(814:816)  CHAR');
     put_txt(',CODR06_P62_ACTC POSITION(817:818)  CHAR');
     put_txt(',MEOPPE_P62_ACTC POSITION(819:826)  CHAR');
     put_txt(',LONR07_P62_ACTC POSITION(827:829)  CHAR');
     put_txt(',CODR07_P62_ACTC POSITION(830:831)  CHAR');
     put_txt(',MECERT_P62_ACTC POSITION(832:839)  CHAR');
     put_txt(',LONR08_P62_ACTC POSITION(840:842)  CHAR');
     put_txt(',CODR08_P62_ACTC POSITION(843:844)  CHAR');
     put_txt(',MEGCER_P62_ACTC POSITION(845:852)  CHAR');
     put_txt(',LONR14_P62_ACTC POSITION(853:855)  CHAR');
     put_txt(',CODR14_P62_ACTC POSITION(856:857)  CHAR');
     put_txt(',DATADI_P62_ACTC POSITION(858:865)  CHAR');
     put_txt(',LONR15_P62_ACTC POSITION(866:868)  CHAR');
     put_txt(',CODR15_P62_ACTC POSITION(869:870)  CHAR');
     put_txt(',IDESAM_P62_ACTC POSITION(871:878)  CHAR');
     put_txt(',LONR16_P62_ACTC POSITION(879:881)  CHAR');
     put_txt(',CODR16_P62_ACTC POSITION(882:883)  CHAR');
     put_txt(',LONTAR_P62_ACTC POSITION(884:885)  CHAR');
     put_txt(',NUMTAR_P62_ACTC POSITION(886:904)  CHAR');
     put_txt(',FECCAD_P62_ACTC POSITION(905:908)  CHAR');
     put_txt(',CODSER_P62_ACTC POSITION(909:911)  CHAR');
     put_txt(',LONR99_P62_ACTC POSITION(912:914)  CHAR');
     put_txt(',CODR99_P62_ACTC POSITION(915:916)  CHAR');
     put_txt(',PANSEQ_P62_ACTC POSITION(917:919)  CHAR');
     put_txt(',FILLER_P62_ACTC POSITION(920:958)  CHAR');
     put_txt(',NUMMEN_P71_ACTC POSITION(959:966)  CHAR');
     put_txt(',NUMEMI_L95_ACTC POSITION(967:968)  CHAR');
     put_txt(',NUMEMI_P95_ACTC POSITION(969:1024) CHAR');
     put_txt(',NUMTAR_P02_RAW  POSITION(023:041)  RAW'); -- JMG 2012/02/14: PCI
     put_txt(')');
  END IF;
  -- Formato ACCP
  IF vCodFormato = 'ACCP' THEN
     put_txt('(ID_CLRLOAD      CONSTANT '||pIDClrLoad);
     put_txt(',COD_HRCIERRE    POSITION(714:714)  CHAR');
     put_txt(',ID_REGISTRO     RECNUM');
     put_txt(',IDEMEN_P00_ACCP POSITION(001:004) CHAR');
     put_txt(',LONTAR_L02_ACCP POSITION(021:022) CHAR');
     -- put_txt(',NUMTAR_P02_ACCP POSITION(023:041) CHAR');
     put_txt(',IDETRA_P11_ACCP POSITION(042:047) CHAR');
     put_txt(',TIMLOC_P12_ACCP POSITION(048:059) CHAR');
     put_txt(',CODFUN_P24_ACCP POSITION(060:062) CHAR');
     put_txt(',CODRAZ_P25_ACCP POSITION(063:066) CHAR');
     put_txt(',SESION_P28_ACCP POSITION(067:072) CHAR');
     put_txt(',INLOTE_P29_ACCP POSITION(073:075) CHAR');
     put_txt(',IDEADQ_L32_ACCP POSITION(076:077) CHAR');
     put_txt(',IDEADQ_P32_ACCP POSITION(078:083) CHAR');
     put_txt(',IDEPRE_L33_ACCP POSITION(089:090) CHAR');
     put_txt(',IDEPRE_P33_ACCP POSITION(091:096) CHAR');
     put_txt(',CODACR_P39_ACCP POSITION(102:104) CHAR');
     put_txt(',LONCTR_P46_ACCP POSITION(105:106) CHAR');
     put_txt(',TIPCU1_P46_ACCP POSITION(107:108) CHAR');
     put_txt(',SIGCU1_P46_ACCP POSITION(109:109) CHAR');
     put_txt(',IMPCU1_P46_ACCP POSITION(110:117) CHAR');
     put_txt(',TIPCU2_P46_ACCP POSITION(118:119) CHAR');
     put_txt(',SIGCU2_P46_ACCP POSITION(120:120) CHAR');
     put_txt(',IMPCU2_P46_ACCP POSITION(121:128) CHAR');
     put_txt(',TIPCU3_P46_ACCP POSITION(129:130) CHAR');
     put_txt(',SIGCU3_P46_ACCP POSITION(131:131) CHAR');
     put_txt(',IMPCU3_P46_ACCP POSITION(132:139) CHAR');
     put_txt(',TIPCU4_P46_ACCP POSITION(140:141) CHAR');
     put_txt(',SIGCU4_P46_ACCP POSITION(142:142) CHAR');
     put_txt(',IMPCU4_P46_ACCP POSITION(143:150) CHAR');
     put_txt(',ORIDAT_L56_ACCP POSITION(151:152) CHAR');
     put_txt(',ORIIDE_P56_ACCP POSITION(153:156) CHAR');
     put_txt(',ORITRA_P56_ACCP POSITION(157:162) CHAR');
     put_txt(',ORITIM_P56_ACCP POSITION(163:174) CHAR');
     put_txt(',ORIADQ_L56_ACCP POSITION(175:176) CHAR');
     put_txt(',ORIADQ_P56_ACCP POSITION(177:187) CHAR');
     put_txt(',NUMMEN_P71_ACCP POSITION(188:195) CHAR');
     put_txt(',REGDAT_L72_ACCP POSITION(196:198) CHAR');
     put_txt(',REGDAT_P72_ACCP POSITION(199:454) CHAR');
     put_txt(',TEXTO_L104_ACCP POSITION(455:457) CHAR');
     put_txt(',TEXTO_P104_ACCP POSITION(458:713) CHAR');
     put_txt(',NUMTAR_P02_RAW  POSITION(023:041) RAW'); -- JMG 2012/02/14: PCI
     put_txt(')');
  END IF;

  -- Formato OTRO
  IF vCodFormato = 'OTRO' THEN
     put_txt('(ID_CLRLOAD      CONSTANT '||pIDClrLoad);
     put_txt(',FEC_SESION      CONSTANT '||vfecha);
     put_txt(',HORA_SESION     CONSTANT '||pHoraProc);
     put_txt(',idemen_p00_actc POSITION(025:028) INTEGER EXTERNAL');
     put_txt(',idetra_p11_actc POSITION(019:024) INTEGER EXTERNAL');
     put_txt(',timloc_p12_actc POSITION(007:018) CHAR');
     put_txt(',ideadq_p32_actc POSITION(001:006) INTEGER EXTERNAL');
     put_txt(',EMVTVR_P55_ACTC POSITION(057:061) RAW');
     put_txt(',PERINT_P55_ACTC POSITION(062:063) RAW');
     put_txt(',NUMALE_P55_ACTC POSITION(064:067) RAW');
     put_txt(',RMVERT_P55_ACTC POSITION(068:070) RAW');
     put_txt(',CAPTER_P55_ACTC POSITION(071:073) RAW');
     put_txt(',SCREMI_P55_ACTC POSITION(098:102) RAW');
     put_txt(',NUMSEC_P23_ACTC POSITION(120:122) INTEGER EXTERNAL');
     put_txt(',DAPLEM_P55_ACTC POSITION(123:154) RAW');
     put_txt(',TTCRIP_P55_ACTC POSITION(155:155) RAW');
     put_txt(',INFCRI_P55_ACTC POSITION(156:156) RAW');
     put_txt(',EMVATC_P55_ACTC POSITION(157:158) RAW');
     put_txt(',CRIPPE_P55_ACTC POSITION(159:166) RAW');
     put_txt(',PAICRI_P55_ACTC POSITION(167:168) RAW');
     put_txt(',FECCRI_P55_ACTC POSITION(169:171) RAW');
     put_txt(',IMPCRI_P55_ACTC POSITION(172:177) RAW');
     put_txt(',MONCRI_P55_ACTC POSITION(178:179) RAW');
     put_txt(',IMCCRI_P55_ACTC POSITION(180:185) RAW');
     put_txt(',CRARPC_P55_ACTC POSITION(039:054) RAW');
     put_txt(',RESCRI_P55_ACTC POSITION(055:056) CHAR');
     put_txt(',FFI_P55_ACTC POSITION(187:190) RAW');    -- campo 55 - Tag 9F6E - LDN 20221104
     put_txt(',DFNAME_P55_ACTC POSITION(192:207) RAW'); -- campo 55 - Tag 84 - LDN 20221104   
     put_txt(')');                                      -- FJV 20221117 - CIERRE
  END IF;

--- crosadof - > IPR POS Version 7
  --- Introduciendo el nuevo archivo AX1644....clr_ax1644
  --- que contiene el formato de mensajes administrativos....

  IF vCodFormato = 'AX01' THEN
     put_txt('(ID_CLRLOAD      CONSTANT '||pIDClrLoad);
     put_txt(',FEC_SESION      CONSTANT '||vfecha);
     put_txt(',IDEADQ_P32_ACTC POSITION(001:006) CHAR');
     put_txt(',TIMLOC_P12_ACTC POSITION(007:018) CHAR');
     put_txt(',IDETRA_P11_ACTC POSITION(019:024) CHAR');
     put_txt(',IDEMEN_P00_ACTC POSITION(025:028) INTEGER EXTERNAL');
     put_txt(',CODPRO_P03_ACTC POSITION(029:034) CHAR');
     put_txt(',CODFUN_P24_ACTC POSITION(035:037) CHAR');
     put_txt(',CODACR_P39_ACTC POSITION(038:040) CHAR');
     put_txt(',IDETER_P41_ACTC POSITION(041:048) CHAR');
     put_txt(',IDEEST_P42_ACTC POSITION(049:063) CHAR');
     put_txt(',MSGADM_PXX_ACTC POSITION(064:085) CHAR');
     put_txt(',FILLER_PXX_ACTC POSITION(086:100) CHAR');
     put_txt(')');
  END IF;


  --- fin crosadof

  --- jvelasquezj - > IPR 1044 Cierre por Lotes
  --- Introduciendo el nuevo archivo AX1520....clr_ax1520
  --- que contiene el formato de mensajes administrativos para el cierre por lotes....

  IF vCodFormato = 'AX02' THEN
     put_txt('(ID_CLRLOAD      CONSTANT '||pIDClrLoad);
     put_txt(',FEC_SESION      CONSTANT '||vfecha);
     put_txt(',TIMLOC_P12_ACTC POSITION(001:012) CHAR');
     put_txt(',IDETRA_P11_ACTC POSITION(013:018) CHAR');
     put_txt(',IDEMEN_P00_ACTC POSITION(019:022) INTEGER EXTERNAL');
     put_txt(',CODACR_P39_ACTC POSITION(023:025) CHAR');
     put_txt(',NUMTER_P41_ACTC POSITION(026:033) CHAR');
     put_txt(',NUMEST_P42_ACTC POSITION(034:048) CHAR');
     put_txt(',NUMLOTE_CIERRE_ACTC POSITION(049:051) CHAR');
     put_txt(',TIPO_CIERRE_ACTC POSITION(052:052) CHAR');
     put_txt(',FILLER_PXX_ACTC POSITION(053:100) CHAR');
     put_txt(')');
  END IF;
  --- fin jvelasquezj

  --
  UTL_FILE.FClose(vFileHandle);
  RETURN '0|'||vFileCTL;
EXCEPTION
  WHEN OTHERS THEN
       vOraCode:=ABS(SQLCODE);
       UTL_FILE.FClose(vFileHandle);
       RETURN 'E|Error de Base de Datos (ORA-'||LTRIM(LPAD(vOraCode,5,'0'))||')';
END; -- GenFileCTL


-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
-- FUNCTION GenFileLST
-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

FUNCTION GenFileCFG (pNomArchivo CHAR) RETURN CHAR
IS

vFileHandle  UTL_FILE.FILE_TYPE;
vOraCode     NUMBER:=0;

procedure put_txt(pTXT char)
is
begin
  UTL_FILE.PUT(vFileHandle,pTXT);
  UTL_FILE.NEW_LINE(vFileHandle);
end;

BEGIN
  -- Creacion del Archivo CFG
  vFileHandle:=UTL_FILE.FOPEN(STD.F_GETVALPAR('DIR-TMP'),pNomArchivo,'W');
  --vFileHandle:=UTL_FILE.FOPEN('DIR_TMP',pNomArchivo,'W');
  --
  put_txt('# ------------------------------------------------------------------------------');
  put_txt('# PCLRLOAD.<SYSDATE>.CFG - Archivos de Carga de Clearing');
  put_txt('# Generado el '||TO_CHAR(SYSDATE,'DD/MM/YYYY HH24:MI:SS'));
  put_txt('# ------------------------------------------------------------------------------');
  --
  FOR r IN (SELECT COD_ARCHIVO
              FROM CFG_CLRLOAD
             ORDER BY COD_ARCHIVO) LOOP
      put_txt(r.COD_ARCHIVO);
  END LOOP;
  --
  UTL_FILE.FClose(vFileHandle);
  RETURN '0';
EXCEPTION
  WHEN OTHERS THEN
       vOraCode:=ABS(SQLCODE);
       UTL_FILE.FClose(vFileHandle);
       RETURN 'E|Error de Base de Datos (ORA-'||LTRIM(LPAD(vOraCode,5,'0'))||')';
END; -- fGenFileLST


-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
-- FUNCTION RevCargaXID
-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

FUNCTION RevCargaXID (pIDClrLoad NUMBER) RETURN CHAR
IS

vOraCode     NUMBER:=0;
vP28SESION   VARCHAR2(15);
vNomTabla    CFG_CLRLOAD.NOM_TABLA%TYPE;
vSQL         VARCHAR2(256);

BEGIN
  -- Elminina informacion anterior
  SELECT CFG.NOM_TABLA
    INTO vNomTabla
    FROM CTL_CLRLOAD CTL,
         CFG_CLRLOAD CFG
   WHERE CTL.COD_ARCHIVO = CFG.COD_ARCHIVO
     AND CTL.ID_CLRLOAD = pIDClrLoad;
  vSQL:='DELETE '||vNomTabla||' WHERE ID_CLRLOAD = '||pIDClrLoad;
  EXECUTE IMMEDIATE vSQL;
  COMMIT;
  RETURN '0';
EXCEPTION
  WHEN OTHERS THEN
       vOraCode:=ABS(SQLCODE);
       ROLLBACK;
       RETURN 'E|Error de Base de Datos (ORA-'||LTRIM(LPAD(vOraCode,5,'0'))||')';
END; -- RevCargaXID


-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
-- FUNCTION GetIDCLRLOAD
-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

FUNCTION GetIDCLRLOAD (pFecSesion DATE,pCodArchivo CHAR, pHoraProc CHAR) RETURN CHAR
IS

vIDClrLoad   NUMBER:=NULL;
vOraCode     NUMBER:=0;

BEGIN

  SELECT ID_CLRLOAD
    INTO vIDClrLoad
    FROM CTL_CLRLOAD
   WHERE FEC_SESION = pFecSesion
     AND COD_ARCHIVO = pCodArchivo
     AND HRA_PROCESO = pHoraProc;
  --
  RETURN vIDClrLoad;

EXCEPTION
  WHEN NO_DATA_FOUND THEN
       RETURN 0;
  WHEN OTHERS THEN
       vOraCode:=ABS(SQLCODE);
       RETURN 'E|Error de Base de Datos (ORA-'||LTRIM(LPAD(vOraCode,5,'0'))||')';
END; -- GetIDCLRLOAD

-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
-- FUNCTION GetIDLIQLOTE - LMJ 20131009
-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

FUNCTION GetIDLIQLOTE (pFecSesion DATE,pCodComercio CHAR, pNroSerie CHAR, pNumLote CHAR) RETURN NUMBER
IS

vExiste   NUMBER:=NULL;
vOraCode     NUMBER:=0;

BEGIN

  SELECT COUNT(*)
    INTO vExiste
    FROM LIQ_LOTE
   WHERE FEC_SESION >= pFecSesion - 2
     AND COD_COMERCIO = pCodComercio
     AND NRO_SERIE    = pNroSerie
     AND NUM_LOTE     = pNumLote;
  --
  RETURN vExiste;

EXCEPTION
  WHEN NO_DATA_FOUND THEN
       RETURN 0;
  WHEN OTHERS THEN
       vOraCode:=ABS(SQLCODE);
       RETURN 'E|Error de Base de Datos (ORA-'||LTRIM(LPAD(vOraCode,5,'0'))||')';
END; -- GetIDLIQLOTE


-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
-- FUNCTION GetStatusCLRLOAD
-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

FUNCTION GetStatusCLRLOAD (pFecSesion DATE,Estado CHAR,pHoraProc CHAR) RETURN CHAR
IS

vStatusClrLoad   CHAR;
vOraCode     NUMBER:=0;

BEGIN

  SELECT distinct est_proceso
    INTO vStatusClrLoad
    FROM CTL_CLRLOAD
   WHERE FEC_SESION = pFecSesion
     AND est_proceso = Estado
     AND HRA_PROCESO = pHoraProc;

  RETURN vStatusClrLoad;

EXCEPTION
  WHEN NO_DATA_FOUND THEN
       RETURN '0';
  WHEN OTHERS THEN
       vOraCode:=ABS(SQLCODE);
       RETURN 'E|Error de Base de Datos (ORA-'||LTRIM(LPAD(vOraCode,5,'0'))||')';
END; -- GetStatusCLRLOAD

-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
-- FUNCTION InsCTL
-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

FUNCTION InsCTL (pFecSesion DATE,pCodArchivo CHAR, pHoraProc CHAR,
                 pNomLOG CHAR:=NULL) RETURN CHAR
IS

vIDClrLoad   NUMBER:=NULL;
vOraCode     NUMBER:=0;
BEGIN
  -- Verifica si ya esta registrado
  BEGIN
    SELECT ID_CLRLOAD
      INTO vIDClrLoad
      FROM CTL_CLRLOAD
     WHERE FEC_SESION = pFecSesion
       AND COD_ARCHIVO = pCodArchivo
       AND HRA_PROCESO = pHoraProc;
  EXCEPTION
    WHEN NO_DATA_FOUND THEN
         -- Obtiene el ID del Proceso (ID_CLRLOAD)
         SELECT SEQ_IDCLRLOAD.NEXTVAL
           INTO vIDClrLoad
           FROM DUAL;
         -- INSERT
         INSERT INTO CTL_CLRLOAD (FEC_SESION,
                                  COD_ARCHIVO,
                                  HRA_PROCESO,
                                  ID_CLRLOAD,
                                  EST_PROCESO,
                                  NOM_LOGFILE,
                                  FH_INICIO,
                                  FH_UPDATE)
                          VALUES (pFecSesion,
                                  pCodArchivo,
                                  pHoraProc,
                                  vIDClrLoad,
                                  'I',
                                  pNomLOG,
                                  SYSDATE,
                                  NULL);
         COMMIT;
  END;
  RETURN vIDClrLoad;

EXCEPTION
  WHEN OTHERS THEN
       vOraCode:=ABS(SQLCODE);
       ROLLBACK;
       RETURN 'E|Error de Base de Datos (ORA-'||LTRIM(LPAD(vOraCode,5,'0'))||')';
END; -- InsCTL


-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
-- FUNCTION UpdCTL
-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

FUNCTION UpdCTL (pIDClrLoad NUMBER, pEstProc CHAR) RETURN CHAR
IS

vOraCode     NUMBER:=0;

BEGIN
  -- Actualiza el Estado del Proceso
  UPDATE CTL_CLRLOAD
     SET EST_PROCESO = pEstProc,
         FH_UPDATE = SYSDATE
   WHERE ID_CLRLOAD = pIDClrLoad;
  RETURN '0';
EXCEPTION
  WHEN OTHERS THEN
       vOraCode:=ABS(SQLCODE);
       ROLLBACK;
       RETURN 'E|Error de Base de Datos (ORA-'||LTRIM(LPAD(vOraCode,5,'0'))||')';
END; -- UpdCTL

/*
-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
-- FUNCTION UpdCtaBanXID
-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

FUNCTION UpdCtaBanXID (pCodArchivo CHAR, pIDClrLoad NUMBER, pIDproc NUMBER) RETURN CHAR
IS

vIDCtaBan   CUENTAS_BANCARIAS.ID_CTABAN%TYPE;
vCodCtaBan  CUENTAS_BANCARIAS.COD_CTABAN%TYPE;
vCodEntBco  CUENTAS_BANCARIAS.COD_ENTBCO%TYPE;
vTIPOTRAN3  CHAR(2);
vP62FILLER  VARCHAR2(39):=NULL;
vOraCode    NUMBER:=0;
vCont       NUMBER:=0;

procedure GetCtaBan (pIDEMEN_P00_ACTC number, pNUMTAR_P02_ACTC char,
                     pCODPRO_P03_ACTC char,   pPUNSER_P22_ACTC char,
                     pIDEADQ_P32_ACTC char,   pIDEEST_P42_ACTC char,
                     pTIPTRA_P48_ACTC char)
is
vCOD_ENTADQ CHAR(2);
vCodBcoEmi  CHAR(4);
vISLR       CHAR(5);
vIVA        CHAR(5);

begin
  --
  vIDCtaBan:=NULL;
  vCodCtaBan:=NULL;
  vCodEntBco:=NULL;
  -- TipoTran3
  if pIDEMEN_P00_ACTC = 1744 then
     vTIPOTRAN3:='10'; -- 10: TXN Miscelanea
  elsif pTIPTRA_P48_ACTC = '200' then
        vTIPOTRAN3:='09'; -- 09: TXN Propietaria
  elsif pTIPTRA_P48_ACTC in ('201','202') then
        vTIPOTRAN3:='08'; -- 08: Alimentacion
  elsif SUBSTR(pCODPRO_P03_ACTC,1,2) = '08' then
        vTIPOTRAN3:='07'; -- 07: Fidelizacion
  elsif SUBSTR(pPUNSER_P22_ACTC,7,1) = '1' then
        vTIPOTRAN3:='04'; -- 04: TXN Manual
  elsif (SUBSTR(pTIPTRA_P48_ACTC,1,2) = '10' or pTIPTRA_P48_ACTC in ('01C','01E','01D','011')) then
        vTIPOTRAN3:='02'; -- 02: Debito
  else
     vTIPOTRAN3:='01'; -- 01: Credito
  end if;
  -- Codigo de Entidad Adquirente
  SELECT COD_ENTADQ
    INTO vCOD_ENTADQ
    FROM ENTIDADES_PRICE
   WHERE C00LCSB = SUBSTR(pIDEADQ_P32_ACTC,3,4);
  -- Codigo de Cuenta Bancaria
  begin
    SELECT CC.ID_CTABAN,
           CB.COD_CTABAN,
           CB.COD_ENTBCO
      INTO vIDCtaBan,
           vCodCtaBan,
           vCodEntBco
      FROM CUENTAS_COMERCIO CC,
           CUENTAS_BANCARIAS CB
     WHERE CC.ID_CTABAN = CB.ID_CTABAN
       AND CC.COD_ENTADQ = vCOD_ENTADQ
       AND CC.COD_COMERCIO = RTRIM(pIDEEST_P42_ACTC)
       AND CC.TIPO_TRAN3 = vTIPOTRAN3
       AND CC.ESTADO = 1 ; -- ACTIVO
    vP62FILLER:=vTIPOTRAN3||LPAD(vIDCtaBan,6,'0')||LPAD(vCodEntBco,4,'0');
  exception
    when no_data_found then
         -- SSM 20070628: Si no encuentra la cuenta para el TIPO_TRAN3
         --               original, busca la cuenta administradora
         --               (JPC 20070628)
         begin
           SELECT CC.ID_CTABAN,
                  CB.COD_CTABAN,
                  CB.COD_ENTBCO
             INTO vIDCtaBan,
                  vCodCtaBan,
                  vCodEntBco
             FROM CUENTAS_COMERCIO CC,
                  CUENTAS_BANCARIAS CB
            WHERE CC.ID_CTABAN = CB.ID_CTABAN
              AND CC.COD_ENTADQ = vCOD_ENTADQ
              AND CC.COD_COMERCIO = RTRIM(pIDEEST_P42_ACTC)
              AND CC.TIPO_TRAN3 = '01'
              AND CC.ESTADO = 1 ; -- ACTIVO
           vP62FILLER:=vTIPOTRAN3||LPAD(vIDCtaBan,6,'0')||LPAD(vCodEntBco,4,'0');
         exception
           when no_data_found then
                vIDCtaBan:=NULL;
                vCodCtaBan:=NULL;
                vCodEntBco:=NULL;
                INSERT INTO CLR_VRFCTABAN (ID_CLRLOAD,
                                           IDEMEN_P00_ACTC,
                                           CODPRO_P03_ACTC,
                                           PUNSER_P22_ACTC,
                                           IDEADQ_P32_ACTC,
                                           IDEEST_P42_ACTC,
                                           TIPTRA_P48_ACTC,
                                           TIPO_TRAN3,
                                           TIPO_TRAN3_ORI)
                                   VALUES (pIDClrLoad,
                                           pIDEMEN_P00_ACTC,
                                           pCODPRO_P03_ACTC,
                                           pPUNSER_P22_ACTC,
                                           pIDEADQ_P32_ACTC,
                                           pIDEEST_P42_ACTC,
                                           pTIPTRA_P48_ACTC,
                                           '01',
                                           vTIPOTRAN3);
         end;
  end;
  -- COD_BCOEMI
  begin
    SELECT LPAD(COD_BCOEMI,4,'0')
      INTO vCodBcoEmi
      FROM BINES_NACIONALES
     WHERE BIN = SUBSTR(pNUMTAR_P02_ACTC,1,6);
  exception
    when others then
         vCodBcoEmi:='0099'; -- ERROR: BIN NO REGISTRADO EN BINES_NACIONALES
  end;
  -- ISLR
  begin
    SELECT LPAD(TASA_ISLR,5,'0'),
           LPAD(TASA_IVA,5,'0')
      INTO vISLR,
           vIVA
      FROM COMERCIOS_PMP COMPMP,
           COM_TASASISLR COMISLR,
           COM_TASASIVA COMIVA
     WHERE COMPMP.COD_ISLR = COMISLR.COD_ISLR
       AND COMPMP.COD_IVA = COMIVA.COD_IVA
       AND COMPMP.COD_COMERCIO = RTRIM(pIDEEST_P42_ACTC);
  exception
    when no_data_found then
         vISLR:='00000';
         vIVA:='00000';
  end;
  --
  if vIDCtaBan is not NULL then
     vP62FILLER:=vP62FILLER||vCodBcoEmi||vISLR||vIVA;
  else
     vP62FILLER:=RPAD(0,12,'0')||vCodBcoEmi||vISLR||vIVA;
  end if;
end; -- GetCtaBan

BEGIN
  -- Tabla de Control de Verificacion de Cuentas Bancarias
  PQMONPROC.InsLog(pIDproc,'M','Procesando '||pCodArchivo||'...');
  PQMONPROC.InsLog(pIDproc,'M','Elimina Informacion Anterior...');
  DELETE CLR_VRFCTABAN
   WHERE ID_CLRLOAD = pIDClrLoad;
  COMMIT;

  -- CLR_MX8998
  IF pCodArchivo = 'MX8998' THEN
     FOR r IN (SELECT ID_REGISTRO,
                      IDEMEN_P00_ACTC,
                      NUMTAR_P02_ACTC,
                      CODPRO_P03_ACTC,
                      PUNSER_P22_ACTC,
                      IDEADQ_P32_ACTC,
                      IDEEST_P42_ACTC,
                      TIPTRA_P48_ACTC
                 FROM CLR_MX8998
                WHERE ID_CLRLOAD = pIDClrLoad
                  AND IDEMEN_P00_ACTC IN (1244,1442,1444) ) LOOP
         GetCtaBan(r.IDEMEN_P00_ACTC, r.NUMTAR_P02_ACTC, r.CODPRO_P03_ACTC, r.PUNSER_P22_ACTC,
                   r.IDEADQ_P32_ACTC, r.IDEEST_P42_ACTC, r.TIPTRA_P48_ACTC);
         UPDATE CLR_MX8998
            SET CTAABO_P48_ACTC = DECODE(vCodCtaBan,NULL,CTAABO_P48_ACTC,vCodCtaBan),
                FILLER_P62_ACTC = vP62FILLER
          WHERE ID_CLRLOAD = pIDClrLoad
            AND ID_REGISTRO = r.ID_REGISTRO;
         vCont:=vCont+1;
         IF MOD(vCont,1000) = 0 THEN
            PQMONPROC.InsLog(pIDproc,'M','Registros Procesados: '||LTRIM(RTRIM(TO_CHAR(vCont,'999,999')))||' ...');
         END IF;
     END LOOP;
     PQMONPROC.InsLog(pIDproc,'M','Registros Procesados: '||LTRIM(RTRIM(TO_CHAR(vCont,'999,999'))));
  END IF;

  -- CLR_MX9998
  IF pCodArchivo = 'MX9998' THEN
     FOR r IN (SELECT ID_REGISTRO,
                      IDEMEN_P00_ACTC,
                      NUMTAR_P02_ACTC,
                      CODPRO_P03_ACTC,
                      PUNSER_P22_ACTC,
                      IDEADQ_P32_ACTC,
                      IDEEST_P42_ACTC,
                      TIPTRA_P48_ACTC
                 FROM CLR_MX9998
                WHERE ID_CLRLOAD = pIDClrLoad
                  AND IDEMEN_P00_ACTC IN (1244,1442,1444) ) LOOP
         GetCtaBan(r.IDEMEN_P00_ACTC, r.NUMTAR_P02_ACTC, r.CODPRO_P03_ACTC, r.PUNSER_P22_ACTC,
                   r.IDEADQ_P32_ACTC, r.IDEEST_P42_ACTC, r.TIPTRA_P48_ACTC);
         UPDATE CLR_MX9998
            SET CTAABO_P48_ACTC = DECODE(vCodCtaBan,NULL,CTAABO_P48_ACTC,vCodCtaBan),
                FILLER_P62_ACTC = vP62FILLER
          WHERE ID_CLRLOAD = pIDClrLoad
            AND ID_REGISTRO = r.ID_REGISTRO;
         vCont:=vCont+1;
         IF MOD(vCont,1000) = 0 THEN
            PQMONPROC.InsLog(pIDproc,'M','Registros Procesados: '||LTRIM(RTRIM(TO_CHAR(vCont,'999,999')))||' ...');
         END IF;
     END LOOP;
     PQMONPROC.InsLog(pIDproc,'M','Registros Procesados: '||LTRIM(RTRIM(TO_CHAR(vCont,'999,999'))));
  END IF;

  -- CLR_MX9999
  IF pCodArchivo = 'MX9999' THEN
     FOR r IN (SELECT ID_REGISTRO,
                      IDEMEN_P00_ACTC,
                      NUMTAR_P02_ACTC,
                      CODPRO_P03_ACTC,
                      PUNSER_P22_ACTC,
                      IDEADQ_P32_ACTC,
                      IDEEST_P42_ACTC,
                      TIPTRA_P48_ACTC
                 FROM CLR_MX9999
                WHERE ID_CLRLOAD = pIDClrLoad
                  AND IDEMEN_P00_ACTC IN (1244,1442,1444) ) LOOP
         GetCtaBan(r.IDEMEN_P00_ACTC, r.NUMTAR_P02_ACTC, r.CODPRO_P03_ACTC, r.PUNSER_P22_ACTC,
                   r.IDEADQ_P32_ACTC, r.IDEEST_P42_ACTC, r.TIPTRA_P48_ACTC);
         UPDATE CLR_MX9999
            SET CTAABO_P48_ACTC = DECODE(vCodCtaBan,NULL,CTAABO_P48_ACTC,vCodCtaBan),
                FILLER_P62_ACTC = vP62FILLER
          WHERE ID_CLRLOAD = pIDClrLoad
            AND ID_REGISTRO = r.ID_REGISTRO;
         vCont:=vCont+1;
         IF MOD(vCont,1000) = 0 THEN
            PQMONPROC.InsLog(pIDproc,'M','Registros Procesados: '||LTRIM(RTRIM(TO_CHAR(vCont,'999,999')))||' ...');
         END IF;
     END LOOP;
     PQMONPROC.InsLog(pIDproc,'M','Registros Procesados: '||LTRIM(RTRIM(TO_CHAR(vCont,'999,999'))));
  END IF;

  -- CLR_MX9898
  IF pCodArchivo = 'MX9898' THEN
     FOR r IN (SELECT ID_REGISTRO,
                      IDEMEN_P00_ACTC,
                      NUMTAR_P02_ACTC,
                      CODPRO_P03_ACTC,
                      PUNSER_P22_ACTC,
                      IDEADQ_P32_ACTC,
                      IDEEST_P42_ACTC,
                      TIPTRA_P48_ACTC
                 FROM CLR_MX9898
                WHERE ID_CLRLOAD = pIDClrLoad
                  AND IDEMEN_P00_ACTC IN (1244,1442,1444) ) LOOP
         GetCtaBan(r.IDEMEN_P00_ACTC, r.NUMTAR_P02_ACTC, r.CODPRO_P03_ACTC, r.PUNSER_P22_ACTC,
                   r.IDEADQ_P32_ACTC, r.IDEEST_P42_ACTC, r.TIPTRA_P48_ACTC);
         UPDATE CLR_MX9898
            SET CTAABO_P48_ACTC = DECODE(vCodCtaBan,NULL,CTAABO_P48_ACTC,vCodCtaBan),
                FILLER_P62_ACTC = vP62FILLER
          WHERE ID_CLRLOAD = pIDClrLoad
            AND ID_REGISTRO = r.ID_REGISTRO;
         vCont:=vCont+1;
         IF MOD(vCont,1000) = 0 THEN
            PQMONPROC.InsLog(pIDproc,'M','Registros Procesados: '||LTRIM(RTRIM(TO_CHAR(vCont,'999,999')))||' ...');
         END IF;
     END LOOP;
     PQMONPROC.InsLog(pIDproc,'M','Registros Procesados: '||LTRIM(RTRIM(TO_CHAR(vCont,'999,999'))));
  END IF;

  -- CLR_MX9899
  IF pCodArchivo = 'MX9899' THEN
     FOR r IN (SELECT ID_REGISTRO,
                      IDEMEN_P00_ACTC,
                      NUMTAR_P02_ACTC,
                      CODPRO_P03_ACTC,
                      PUNSER_P22_ACTC,
                      IDEADQ_P32_ACTC,
                      IDEEST_P42_ACTC,
                      TIPTRA_P48_ACTC
                 FROM CLR_MX9899
                WHERE ID_CLRLOAD = pIDClrLoad
                  AND IDEMEN_P00_ACTC IN (1244,1442,1444) ) LOOP
         GetCtaBan(r.IDEMEN_P00_ACTC, r.NUMTAR_P02_ACTC, r.CODPRO_P03_ACTC, r.PUNSER_P22_ACTC,
                   r.IDEADQ_P32_ACTC, r.IDEEST_P42_ACTC, r.TIPTRA_P48_ACTC);
         UPDATE CLR_MX9899
            SET CTAABO_P48_ACTC = DECODE(vCodCtaBan,NULL,CTAABO_P48_ACTC,vCodCtaBan),
                FILLER_P62_ACTC = vP62FILLER
          WHERE ID_CLRLOAD = pIDClrLoad
            AND ID_REGISTRO = r.ID_REGISTRO;
         vCont:=vCont+1;
         IF MOD(vCont,1000) = 0 THEN
            PQMONPROC.InsLog(pIDproc,'M','Registros Procesados: '||LTRIM(RTRIM(TO_CHAR(vCont,'999,999')))||' ...');
         END IF;
     END LOOP;
     PQMONPROC.InsLog(pIDproc,'M','Registros Procesados: '||LTRIM(RTRIM(TO_CHAR(vCont,'999,999'))));
  END IF;

  -- CLR_MX9798
  IF pCodArchivo = 'MX9798' THEN
     FOR r IN (SELECT ID_REGISTRO,
                      IDEMEN_P00_ACTC,
                      NUMTAR_P02_ACTC,
                      CODPRO_P03_ACTC,
                      PUNSER_P22_ACTC,
                      IDEADQ_P32_ACTC,
                      IDEEST_P42_ACTC,
                      TIPTRA_P48_ACTC
                 FROM CLR_MX9798
                WHERE ID_CLRLOAD = pIDClrLoad
                  AND IDEMEN_P00_ACTC IN (1244,1442,1444) ) LOOP
         GetCtaBan(r.IDEMEN_P00_ACTC, r.NUMTAR_P02_ACTC, r.CODPRO_P03_ACTC, r.PUNSER_P22_ACTC,
                   r.IDEADQ_P32_ACTC, r.IDEEST_P42_ACTC, r.TIPTRA_P48_ACTC);
         UPDATE CLR_MX9798
            SET CTAABO_P48_ACTC = DECODE(vCodCtaBan,NULL,CTAABO_P48_ACTC,vCodCtaBan),
                FILLER_P62_ACTC = vP62FILLER
          WHERE ID_CLRLOAD = pIDClrLoad
            AND ID_REGISTRO = r.ID_REGISTRO;
         vCont:=vCont+1;
         IF MOD(vCont,1000) = 0 THEN
            PQMONPROC.InsLog(pIDproc,'M','Registros Procesados: '||LTRIM(RTRIM(TO_CHAR(vCont,'999,999')))||' ...');
         END IF;
     END LOOP;
     PQMONPROC.InsLog(pIDproc,'M','Registros Procesados: '||LTRIM(RTRIM(TO_CHAR(vCont,'999,999'))));
  END IF;

--INICIO IPR 1068
    --FECHA DE CREACION : 26/10/2012
    --AUTOR : EDGAR MENA AZA??????ERO.
    --DESCRIPCION : Permite agregar Diners para BP.

    -- CLR_MX9799
    IF pCodArchivo = 'MX9799' THEN
        FOR r IN (SELECT ID_REGISTRO,     IDEMEN_P00_ACTC, NUMTAR_P02_ACTC, CODPRO_P03_ACTC,
                         PUNSER_P22_ACTC, IDEADQ_P32_ACTC, IDEEST_P42_ACTC, TIPTRA_P48_ACTC,
                         TIPMOV_P48_ACTC, INDPRE_P48_ACTC, FILLER_P48_ACTC
                 FROM CLR_MX9799
                WHERE ID_CLRLOAD = pIDClrLoad
                  AND IDEMEN_P00_ACTC IN (1244,1442,1444) )
        LOOP
            GetCtaBan(r.IDEMEN_P00_ACTC, r.NUMTAR_P02_ACTC, r.CODPRO_P03_ACTC, r.PUNSER_P22_ACTC,
                      r.IDEADQ_P32_ACTC, r.IDEEST_P42_ACTC, r.TIPTRA_P48_ACTC, r.TIPMOV_P48_ACTC,
                      r.INDPRE_P48_ACTC, r.FILLER_P48_ACTC);
            UPDATE CLR_MX9799
               SET CTAABO_P48_ACTC = DECODE(vCodCtaBan,NULL,CTAABO_P48_ACTC,vCodCtaBan),
                   FILLER_P62_ACTC = vP62FILLER,
                   FILLER_P48_ACTC = vP48FILLER
             WHERE ID_CLRLOAD = pIDClrLoad
               AND ID_REGISTRO = r.ID_REGISTRO;
            vCont:=vCont+1;
        END LOOP;
        PQMONPROC.InsLog(pIDproc,'M','Registros Procesados: '||LTRIM(RTRIM(TO_CHAR(vCont,'999,999'))));
    END IF;
    --FIN IPR 1068

  -- CLR_MX8999
  IF pCodArchivo = 'MX8999' THEN
     FOR r IN (SELECT ID_REGISTRO,
                      IDEMEN_P00_ACTC,
                      NUMTAR_P02_ACTC,
                      CODPRO_P03_ACTC,
                      PUNSER_P22_ACTC,
                      IDEADQ_P32_ACTC,
                      IDEEST_P42_ACTC,
                      TIPTRA_P48_ACTC
                 FROM CLR_MX8999
                WHERE ID_CLRLOAD = pIDClrLoad
                  AND IDEMEN_P00_ACTC IN (1244,1442,1444) ) LOOP
         GetCtaBan(r.IDEMEN_P00_ACTC, r.NUMTAR_P02_ACTC, r.CODPRO_P03_ACTC, r.PUNSER_P22_ACTC,
                   r.IDEADQ_P32_ACTC, r.IDEEST_P42_ACTC, r.TIPTRA_P48_ACTC);
         UPDATE CLR_MX8999
            SET CTAABO_P48_ACTC = DECODE(vCodCtaBan,NULL,CTAABO_P48_ACTC,vCodCtaBan),
                FILLER_P62_ACTC = vP62FILLER
          WHERE ID_CLRLOAD = pIDClrLoad
            AND ID_REGISTRO = r.ID_REGISTRO;
         vCont:=vCont+1;
         IF MOD(vCont,1000) = 0 THEN
            PQMONPROC.InsLog(pIDproc,'M','Registros Procesados: '||LTRIM(RTRIM(TO_CHAR(vCont,'999,999')))||' ...');
         END IF;
     END LOOP;
     PQMONPROC.InsLog(pIDproc,'M','Registros Procesados: '||LTRIM(RTRIM(TO_CHAR(vCont,'999,999'))));
  END IF;
  --
  RETURN '0';
EXCEPTION
  WHEN OTHERS THEN
       vOraCode:=ABS(SQLCODE);
       ROLLBACK;
       PQMONPROC.InsLog(pIDproc,'E','E|Error de Base de Datos (ORA-'||LTRIM(LPAD(vOraCode,5,'0'))||')');
       RETURN 'E|Error de Base de Datos (ORA-'||LTRIM(LPAD(vOraCode,5,'0'))||')';
END; -- UpdCtaBanXID
*/

-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
-- FUNCTION GetTIPO_TRAN3SUB
-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

FUNCTION GetTIPO_TRAN3SUB(pTIPO_TRAN3 CHAR, pP02NUMTAR CHAR, pP48TIPMOV CHAR, pP48FILLER CHAR) RETURN CHAR IS
  vTIPOTRAN3_SUB CHAR(2):= NULL;
BEGIN
  IF pTIPO_TRAN3 = '08' THEN
     -- ALIMENTACION
     vTIPOTRAN3_SUB:=SUBSTR(pP48FILLER,9,2);
     IF vTIPOTRAN3_SUB = '  ' THEN
        BEGIN
           SELECT COD_PRODUCTO
             INTO vTIPOTRAN3_SUB
             FROM SDX_PRODUCTO_BIN
            WHERE BIN = TO_NUMBER(SUBSTR(pP02NUMTAR,1,8));
        EXCEPTION
           WHEN OTHERS THEN vTIPOTRAN3_SUB := '  ';
        END;
     END IF;
  ELSIF pTIPO_TRAN3 IN ('11','12','13') THEN
     -- CONTRACARGOS, ANULACIONES GC Y ENTRYPOINTS
     IF pP48TIPMOV = 'c' THEN -- CREDITO
        vTIPOTRAN3_SUB:='01';
     ELSIF pP48TIPMOV = 'd' THEN -- DEBITO
        vTIPOTRAN3_SUB:='02';
     ELSIF pP48TIPMOV = 'a' THEN -- ALIMENTACION
        vTIPOTRAN3_SUB:=SUBSTR(pP48FILLER,9,2);
        IF vTIPOTRAN3_SUB = '  ' THEN
           BEGIN
              SELECT COD_PRODUCTO
                INTO vTIPOTRAN3_SUB
                FROM SDX_PRODUCTO_BIN
               WHERE BIN = TO_NUMBER(SUBSTR(pP02NUMTAR,1,8));
           EXCEPTION
              WHEN OTHERS THEN vTIPOTRAN3_SUB := '  ';
           END;
        END IF;
     END IF;
  END IF;
  RETURN vTIPOTRAN3_SUB;
END;

-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
-- FUNCTION UpdCtaBanXID
-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

FUNCTION UpdCtaBanXID (pCodArchivo CHAR, pIDClrLoad NUMBER, pIDproc NUMBER) RETURN CHAR
IS

vIDCtaBan   CUENTAS_BANCARIAS.ID_CTABAN%TYPE;
vCodCtaBan  CUENTAS_BANCARIAS.COD_CTABAN%TYPE;
vCodEntBco  CUENTAS_BANCARIAS.COD_ENTBCO%TYPE;
vTIPOTRAN3  CHAR(2);
vTIPOTRAN3_SUB CHAR(2):=NULL;
vP62FILLER  VARCHAR2(39):=NULL;
vP48FILLER  VARCHAR2(13):=NULL;
vOraCode    NUMBER:=0;
vCont       NUMBER:=0;
vrefadq     VARCHAR2(39);

PROCEDURE GetCtaBan (pIDEMEN_P00_ACTC number, pNUMTAR_P02_ACTC char,
                     pCODPRO_P03_ACTC char,   pPUNSER_P22_ACTC char,
                     pIDEADQ_P32_ACTC char,   pIDEEST_P42_ACTC char,
                     pTIPTRA_P48_ACTC char,   pTIPMOV_P48_ACTC char,
                     pINDPRE_P48_ACTC char,   pFILLER_P48_ACTC char,
                     pCODACT_P18_ACTC char, pIMPTRA_P04_ACTC char -- 20161223 : IPR 1217
                     )
IS
vCOD_ENTADQ CHAR(2);
vCodBcoEmi  CHAR(4);
vISLR       CHAR(5);
vIVA        CHAR(5);
/*
CREATE TABLE CLR_VRFCTABAN
   (ID_CLRLOAD                     NUMBER,
    IDEMEN_P00_ACTC                NUMBER(4,0),
    CODPRO_P03_ACTC                VARCHAR2(6),
    PUNSER_P22_ACTC                VARCHAR2(12),
    IDEADQ_P32_ACTC                VARCHAR2(11),
    IDEEST_P42_ACTC                VARCHAR2(15),
    TIPTRA_P48_ACTC                VARCHAR2(3),
    TIPO_TRAN3                     CHAR(2),
    TIPO_TRAN3_ORI                 CHAR(2),
    ID_CTABAN                      NUMBER(6,0));

CREATE INDEX IDX_CLR_VRFCTABAN ON CLR_VRFCTABAN (ID_CLRLOAD)
TABLESPACE  IDX_SGCVNZ;

*/

BEGIN
  --
  vIDCtaBan:=NULL;
  vCodCtaBan:=NULL;
  vCodEntBco:=NULL;
  vP48FILLER:=pFILLER_P48_ACTC;
   ---------------------------------------------------------------------
   --- VARIABLES INICIALIZADAS POR TST 13/10/2015
   ---------------------------------------------------------------------
   vTIPOTRAN3:=NULL;
   vTIPOTRAN3_SUB:=NULL;

  -- TIPO_TRAN3
  IF pIDEMEN_P00_ACTC = 1444 AND SUBSTR(pPUNSER_P22_ACTC,7,1) = '1' THEN
     vTIPOTRAN3:='12'; -- 12: ANULACIONES DE GC
     vTIPOTRAN3_SUB:=GetTIPO_TRAN3SUB(vTIPOTRAN3, pNUMTAR_P02_ACTC, pTIPMOV_P48_ACTC, pFILLER_P48_ACTC);
  ELSIF pIDEMEN_P00_ACTC = 1442 THEN
        vTIPOTRAN3:='11'; -- 11: CONTRACARGO
        vTIPOTRAN3_SUB:=GetTIPO_TRAN3SUB(vTIPOTRAN3, pNUMTAR_P02_ACTC, pTIPMOV_P48_ACTC, pFILLER_P48_ACTC);
        IF pTIPMOV_P48_ACTC='a' THEN
           vP48FILLER := SUBSTR(pFILLER_P48_ACTC,1,8)||NVL(vTIPOTRAN3_SUB,'  ')||SUBSTR(pFILLER_P48_ACTC,11);
        END IF;
  ELSIF pIDEMEN_P00_ACTC = 1744 THEN
        vTIPOTRAN3:='10'; -- 10: TXN MISCELANEA
  ELSIF pTIPTRA_P48_ACTC = '200' THEN
        vTIPOTRAN3:='09'; -- 09: TXN PROPIETARIA
  ELSIF pTIPTRA_P48_ACTC IN ('201','202') THEN
        vTIPOTRAN3:='08'; -- 08: ALIMENTACION
        vTIPOTRAN3_SUB:=GetTIPO_TRAN3SUB(vTIPOTRAN3, pNUMTAR_P02_ACTC, pTIPMOV_P48_ACTC, pFILLER_P48_ACTC);
        vP48FILLER := SUBSTR(pFILLER_P48_ACTC,1,8)||NVL(vTIPOTRAN3_SUB,'  ')||SUBSTR(pFILLER_P48_ACTC,11);
  ELSIF pINDPRE_P48_ACTC = '04' THEN
        vTIPOTRAN3:='07'; -- 07: FIDELIZACION
  ELSIF SUBSTR(pPUNSER_P22_ACTC,7,1) = '1' THEN
        IF (SUBSTR(pPUNSER_P22_ACTC,1,1) = '1' AND SUBSTR(pPUNSER_P22_ACTC,9,1) = '3' AND SUBSTR(pIDEADQ_P32_ACTC,1,2) = '01') THEN
            vTIPOTRAN3:='13'; -- 13: ENTRYPOINTS
            vTIPOTRAN3_SUB:=GetTIPO_TRAN3SUB(vTIPOTRAN3, pNUMTAR_P02_ACTC, pTIPMOV_P48_ACTC, pFILLER_P48_ACTC);
        ELSE
            vTIPOTRAN3:='04'; -- 04: TXN MANUAL
        END IF;
 -- ELSIF SUBSTR(pTIPTRA_P48_ACTC,1,2) = '10' OR pTIPTRA_P48_ACTC IN ('01C','01E','01D','011') THEN
 ELSIF TRIM(SUBSTR(pTIPTRA_P48_ACTC,1,2)) = '10' OR TRIM(pTIPMOV_P48_ACTC) ='d' OR TRIM(pTIPTRA_P48_ACTC) IN ('01C','01E','01D','011') THEN /* ORIGINAL MODIFICADO POR TST */
     vTIPOTRAN3:='02'; -- 02: DEBITO
  ELSE
     vTIPOTRAN3:='01'; -- 01: CREDITO
  END IF;
  -- Codigo de Entidad Adquirente
  SELECT COD_ENTADQ
    INTO vCOD_ENTADQ
    FROM ENTIDADES_PRICE
   WHERE C00LCSB = SUBSTR(pIDEADQ_P32_ACTC,3,4);
  -- Codigo de Cuenta Bancaria
  begin
   vrefadq := pIDEEST_P42_ACTC;
    SELECT CC.ID_CTABAN,
           CB.COD_CTABAN,
           CB.COD_ENTBCO
      INTO vIDCtaBan,
           vCodCtaBan,
           vCodEntBco
      FROM CUENTAS_COMERCIO CC,
           CUENTAS_BANCARIAS CB
     WHERE CC.ID_CTABAN = CB.ID_CTABAN
       AND CC.COD_ENTADQ = vCOD_ENTADQ
       AND CC.COD_COMERCIO = RTRIM(pIDEEST_P42_ACTC)
       AND CC.TIPO_TRAN3 = NVL(vTIPOTRAN3_SUB, vTIPOTRAN3)
       AND CC.ESTADO = 1 ; -- ACTIVO
    vP62FILLER:=vTIPOTRAN3||LPAD(vIDCtaBan,6,'0')||LPAD(vCodEntBco,4,'0');
  exception
    when no_data_found then
         -- SSM 20070628: Si no encuentra la cuenta para el TIPO_TRAN3 original,
         --               busca la cuenta para el TIPO_TRAN3 = '01' (credito)
         --               (JPC 20070628)
         begin
           SELECT CC.ID_CTABAN,
                  CB.COD_CTABAN,
                  CB.COD_ENTBCO
             INTO vIDCtaBan,
                  vCodCtaBan,
                  vCodEntBco
             FROM CUENTAS_COMERCIO CC,
                  CUENTAS_BANCARIAS CB
            WHERE CC.ID_CTABAN = CB.ID_CTABAN
              AND CC.COD_ENTADQ = vCOD_ENTADQ
              AND CC.COD_COMERCIO = RTRIM(pIDEEST_P42_ACTC)
              AND CC.TIPO_TRAN3 = '01'
              AND CC.ESTADO = 1 ; -- ACTIVO
           vP62FILLER:=vTIPOTRAN3||LPAD(vIDCtaBan,6,'0')||LPAD(vCodEntBco,4,'0');
         exception
           when no_data_found then
                -- SSM 20080523: Si no encuentra la cuenta para el TIPO_TRAN3 = '01' (credito),
                --               busca la cuenta para el TIPO_TRAN3 = '02' (debito)
                --               (JPC 20070628)
                begin
                  SELECT CC.ID_CTABAN,
                         CB.COD_CTABAN,
                         CB.COD_ENTBCO
                    INTO vIDCtaBan,
                         vCodCtaBan,
                         vCodEntBco
                    FROM CUENTAS_COMERCIO CC,
                         CUENTAS_BANCARIAS CB
                   WHERE CC.ID_CTABAN = CB.ID_CTABAN
                     AND CC.COD_ENTADQ = vCOD_ENTADQ
                     AND CC.COD_COMERCIO = RTRIM(pIDEEST_P42_ACTC)
                     AND CC.TIPO_TRAN3 = '02'
                     AND CC.ESTADO = 1 ; -- ACTIVO
                  vP62FILLER:=vTIPOTRAN3||LPAD(vIDCtaBan,6,'0')||LPAD(vCodEntBco,4,'0');
                exception
                  when no_data_found then
                       vIDCtaBan:=NULL;
                       vCodCtaBan:=NULL;
                       vCodEntBco:=NULL;
                       INSERT INTO CLR_VRFCTABAN (ID_CLRLOAD,
                                                  IDEMEN_P00_ACTC,
                                                  CODPRO_P03_ACTC,
                                                  PUNSER_P22_ACTC,
                                                  IDEADQ_P32_ACTC,
                                                  IDEEST_P42_ACTC,
                                                  TIPTRA_P48_ACTC,
                                                  TIPO_TRAN3,
                                                  TIPO_TRAN3_ORI)
                                          VALUES (pIDClrLoad,
                                                  pIDEMEN_P00_ACTC,
                                                  pCODPRO_P03_ACTC,
                                                  pPUNSER_P22_ACTC,
                                                  pIDEADQ_P32_ACTC,
                                                  pIDEEST_P42_ACTC,
                                                  pTIPTRA_P48_ACTC,
                                                  '02',
                                                  vTIPOTRAN3);
                       gNumERR:=gNumERR+1;
                       PQMONPROC.InsLog(pIDproc,'E','ERROR: Cuenta NO Encontrada (COD_COMERCIO: '||TRIM(pIDEEST_P42_ACTC)||', COD_ENTADQ: '||vCOD_ENTADQ||', TIPO_TRAN3: ' || vTIPOTRAN3 ||')');
                end;
         end;
  end;
  -- COD_BCOEMI
  begin
    SELECT LPAD(COD_BCOEMI,4,'0')
      INTO vCodBcoEmi
      FROM BINES_NACIONALES
     WHERE BIN = SUBSTR(pNUMTAR_P02_ACTC,1,8);-- Brivas: Extensi?n de longitud de bines de 6 a 8 dig. IPR 1359 - 07/09/2021.
  exception
    when others then
         vCodBcoEmi:='0099'; -- ERROR: BIN NO REGISTRADO EN BINES_NACIONALES
  end;
  -- ISLR
  begin
    if pTIPMOV_P48_ACTC = 'c' then

       SELECT LPAD(TASA_ISLR,5,'0'),
              LPAD(TASA_IVA,5,'0')
         INTO vISLR,
              vIVA
         FROM COMERCIOS_PMP COMPMP,
              COM_TASASISLR COMISLR,
              COM_TASASIVA COMIVA
        WHERE COMPMP.COD_ISLR_CRE = COMISLR.COD_ISLR
          AND COMPMP.COD_IVA_CRE = COMIVA.COD_IVA
          AND COMPMP.COD_COMERCIO = RTRIM(pIDEEST_P42_ACTC);

          -- IPR 1246 27/09/2017
       /*
          IF (pCODACT_P18_ACTC NOT IN  ('5944','5094')) AND(TO_NUMBER(pIMPTRA_P04_ACTC)/100  <= 2180000) AND (vIVA = '00012') THEN
                vIVA := '00009';
          ELSIF (pCODACT_P18_ACTC NOT IN  ('5944','5094')) AND(TO_NUMBER(pIMPTRA_P04_ACTC)/100  > 2180000) AND (vIVA = '00012') THEN
                vIVA := '00007';
          END IF;
         01/01/2018 */

    else
       SELECT LPAD(TASA_ISLR,5,'0'),
              LPAD(TASA_IVA,5,'0')
         INTO vISLR,
              vIVA
         FROM COMERCIOS_PMP COMPMP,
              COM_TASASISLR COMISLR,
              COM_TASASIVA COMIVA
        WHERE COMPMP.COD_ISLR_DEB = COMISLR.COD_ISLR
          AND COMPMP.COD_IVA_DEB = COMIVA.COD_IVA
          AND COMPMP.COD_COMERCIO = RTRIM(pIDEEST_P42_ACTC);
    end if;
  exception
    when no_data_found then
         vISLR:='00000';
         vIVA:='00000';
         gNumERR:=gNumERR+1;
         PQMONPROC.InsLog(pIDproc,'E','ERROR: El Comercio '||TRIM(pIDEEST_P42_ACTC)||' no tiene TASAS asignadas.');
  end;
  --
  if vIDCtaBan is not NULL then
     vP62FILLER:=vP62FILLER||vCodBcoEmi||vISLR||vIVA;
  else
     vP62FILLER:=RPAD(0,12,'0')||vCodBcoEmi||vISLR||vIVA;
  end if;
END; -- GetCtaBan

BEGIN
  -- Tabla de Control de Verificacion de Cuentas Bancarias
  PQMONPROC.InsLog(pIDproc,'M','Procesando '||pCodArchivo||'...');
  PQMONPROC.InsLog(pIDproc,'M','Elimina Informacion Anterior...');
  DELETE CLR_VRFCTABAN
   WHERE ID_CLRLOAD = pIDClrLoad;
  COMMIT;

  -- CLR_MX8998
  IF pCodArchivo = 'MX8998' THEN
     FOR r IN (SELECT ID_REGISTRO,
                      IDEMEN_P00_ACTC,
                      NUMTAR_P02_ACTC,
                      CODPRO_P03_ACTC,
                      PUNSER_P22_ACTC,
                      IDEADQ_P32_ACTC,
                      IDEEST_P42_ACTC,
                      TIPTRA_P48_ACTC,
                      TIPMOV_P48_ACTC,
                      INDPRE_P48_ACTC,
                      FILLER_P48_ACTC,
                      CODACT_P18_ACTC, -- 20161223 : IPR 1217
                      IMPTRA_P04_ACTC  -- 20161223 : IPR 1217
                 FROM CLR_MX8998
                WHERE ID_CLRLOAD = pIDClrLoad
                  AND IDEMEN_P00_ACTC IN (1244,1442,1444) ) LOOP
         GetCtaBan(r.IDEMEN_P00_ACTC, r.NUMTAR_P02_ACTC, r.CODPRO_P03_ACTC, r.PUNSER_P22_ACTC,
                   r.IDEADQ_P32_ACTC, r.IDEEST_P42_ACTC, r.TIPTRA_P48_ACTC, r.TIPMOV_P48_ACTC,
                   r.INDPRE_P48_ACTC, r.FILLER_P48_ACTC,
                   r.CODACT_P18_ACTC , r.IMPTRA_P04_ACTC); -- 20161223 : IPR 1217
         UPDATE CLR_MX8998
            SET CTAABO_P48_ACTC = DECODE(vCodCtaBan,NULL,CTAABO_P48_ACTC,vCodCtaBan),
                FILLER_P62_ACTC = vP62FILLER,
                FILLER_P48_ACTC = vP48FILLER
          WHERE ID_CLRLOAD = pIDClrLoad
            AND ID_REGISTRO = r.ID_REGISTRO;
         vCont:=vCont+1;
         IF MOD(vCont,1000) = 0 THEN
            PQMONPROC.InsLog(pIDproc,'M','Registros Procesados: '||LTRIM(RTRIM(TO_CHAR(vCont,'999,999')))||' ...');
         END IF;
     END LOOP;
     PQMONPROC.InsLog(pIDproc,'M','Registros Procesados: '||LTRIM(RTRIM(TO_CHAR(vCont,'999,999'))));
  END IF;

  -- CLR_MX9998
  IF pCodArchivo = 'MX9998' THEN
     FOR r IN (SELECT ID_REGISTRO,
                      IDEMEN_P00_ACTC,
                      NUMTAR_P02_ACTC,
                      CODPRO_P03_ACTC,
                      PUNSER_P22_ACTC,
                      IDEADQ_P32_ACTC,
                      IDEEST_P42_ACTC,
                      TIPTRA_P48_ACTC,
                      TIPMOV_P48_ACTC,
                      INDPRE_P48_ACTC,
                      FILLER_P48_ACTC,
                      CODACT_P18_ACTC, -- 20161223 : IPR 1217
                      IMPTRA_P04_ACTC  -- 20161223 : IPR 1217
                 FROM CLR_MX9998
                WHERE ID_CLRLOAD = pIDClrLoad
                  AND IDEMEN_P00_ACTC IN (1244,1442,1444) ) LOOP
         GetCtaBan(r.IDEMEN_P00_ACTC, r.NUMTAR_P02_ACTC, r.CODPRO_P03_ACTC, r.PUNSER_P22_ACTC,
                   r.IDEADQ_P32_ACTC, r.IDEEST_P42_ACTC, r.TIPTRA_P48_ACTC, r.TIPMOV_P48_ACTC,
                   r.INDPRE_P48_ACTC, r.FILLER_P48_ACTC,
                   r.CODACT_P18_ACTC , r.IMPTRA_P04_ACTC); -- 20161223 : IPR 1217
         UPDATE CLR_MX9998
            SET CTAABO_P48_ACTC = DECODE(vCodCtaBan,NULL,CTAABO_P48_ACTC,vCodCtaBan),
                FILLER_P62_ACTC = vP62FILLER,
                FILLER_P48_ACTC = vP48FILLER
          WHERE ID_CLRLOAD = pIDClrLoad
            AND ID_REGISTRO = r.ID_REGISTRO;
         vCont:=vCont+1;
         IF MOD(vCont,1000) = 0 THEN
            PQMONPROC.InsLog(pIDproc,'M','Registros Procesados: '||LTRIM(RTRIM(TO_CHAR(vCont,'999,999')))||' ...');
         END IF;
     END LOOP;
     PQMONPROC.InsLog(pIDproc,'M','Registros Procesados: '||LTRIM(RTRIM(TO_CHAR(vCont,'999,999'))));
  END IF;

  -- CLR_MX9999
  IF pCodArchivo = 'MX9999' THEN
     FOR r IN (SELECT ID_REGISTRO,
                      IDEMEN_P00_ACTC,
                      NUMTAR_P02_ACTC,
                      CODPRO_P03_ACTC,
                      PUNSER_P22_ACTC,
                      IDEADQ_P32_ACTC,
                      IDEEST_P42_ACTC,
                      TIPTRA_P48_ACTC,
                      TIPMOV_P48_ACTC,
                      INDPRE_P48_ACTC,
                      FILLER_P48_ACTC,
                      CODACT_P18_ACTC, -- 20161223 : IPR 1217
                      IMPTRA_P04_ACTC  -- 20161223 : IPR 1217
                 FROM CLR_MX9999
                WHERE ID_CLRLOAD = pIDClrLoad
                  AND IDEMEN_P00_ACTC IN (1244,1442,1444) ) LOOP
         GetCtaBan(r.IDEMEN_P00_ACTC, r.NUMTAR_P02_ACTC, r.CODPRO_P03_ACTC, r.PUNSER_P22_ACTC,
                   r.IDEADQ_P32_ACTC, r.IDEEST_P42_ACTC, r.TIPTRA_P48_ACTC, r.TIPMOV_P48_ACTC,
                   r.INDPRE_P48_ACTC, r.FILLER_P48_ACTC,
                   r.CODACT_P18_ACTC , r.IMPTRA_P04_ACTC); -- 20161223 : IPR 1217
         UPDATE CLR_MX9999
            SET CTAABO_P48_ACTC = DECODE(vCodCtaBan,NULL,CTAABO_P48_ACTC,vCodCtaBan),
                FILLER_P62_ACTC = vP62FILLER,
                FILLER_P48_ACTC = vP48FILLER
          WHERE ID_CLRLOAD = pIDClrLoad
            AND ID_REGISTRO = r.ID_REGISTRO;
         vCont:=vCont+1;
         IF MOD(vCont,1000) = 0 THEN
            PQMONPROC.InsLog(pIDproc,'M','Registros Procesados: '||LTRIM(RTRIM(TO_CHAR(vCont,'999,999')))||' ...');
         END IF;
     END LOOP;
     PQMONPROC.InsLog(pIDproc,'M','Registros Procesados: '||LTRIM(RTRIM(TO_CHAR(vCont,'999,999'))));
  END IF;

  -- CLR_MX9898
  IF pCodArchivo = 'MX9898' THEN
     FOR r IN (SELECT ID_REGISTRO,
                      IDEMEN_P00_ACTC,
                      NUMTAR_P02_ACTC,
                      CODPRO_P03_ACTC,
                      PUNSER_P22_ACTC,
                      IDEADQ_P32_ACTC,
                      IDEEST_P42_ACTC,
                      TIPTRA_P48_ACTC,
                      TIPMOV_P48_ACTC,
                      INDPRE_P48_ACTC,
                      FILLER_P48_ACTC,
                      CODACT_P18_ACTC, -- 20161223 : IPR 1217
                      IMPTRA_P04_ACTC  -- 20161223 : IPR 1217
                 FROM CLR_MX9898
                WHERE ID_CLRLOAD = pIDClrLoad
                  AND IDEMEN_P00_ACTC IN (1244,1442,1444) ) LOOP
         GetCtaBan(r.IDEMEN_P00_ACTC, r.NUMTAR_P02_ACTC, r.CODPRO_P03_ACTC, r.PUNSER_P22_ACTC,
                   r.IDEADQ_P32_ACTC, r.IDEEST_P42_ACTC, r.TIPTRA_P48_ACTC, r.TIPMOV_P48_ACTC,
                   r.INDPRE_P48_ACTC, r.FILLER_P48_ACTC,
                   r.CODACT_P18_ACTC , r.IMPTRA_P04_ACTC); -- 20161223 : IPR 1217
         UPDATE CLR_MX9898
            SET CTAABO_P48_ACTC = DECODE(vCodCtaBan,NULL,CTAABO_P48_ACTC,vCodCtaBan),
                FILLER_P62_ACTC = vP62FILLER,
                FILLER_P48_ACTC = vP48FILLER
          WHERE ID_CLRLOAD = pIDClrLoad
            AND ID_REGISTRO = r.ID_REGISTRO;
         vCont:=vCont+1;
         IF MOD(vCont,1000) = 0 THEN
            PQMONPROC.InsLog(pIDproc,'M','Registros Procesados: '||LTRIM(RTRIM(TO_CHAR(vCont,'999,999')))||' ...');
         END IF;
     END LOOP;
     PQMONPROC.InsLog(pIDproc,'M','Registros Procesados: '||LTRIM(RTRIM(TO_CHAR(vCont,'999,999'))));
  END IF;

  -- CLR_MX9899
  IF pCodArchivo = 'MX9899' THEN
     FOR r IN (SELECT ID_REGISTRO,
                      IDEMEN_P00_ACTC,
                      NUMTAR_P02_ACTC,
                      CODPRO_P03_ACTC,
                      PUNSER_P22_ACTC,
                      IDEADQ_P32_ACTC,
                      IDEEST_P42_ACTC,
                      TIPTRA_P48_ACTC,
                      TIPMOV_P48_ACTC,
                      INDPRE_P48_ACTC,
                      FILLER_P48_ACTC,
                      CODACT_P18_ACTC, -- 20161223 : IPR 1217
                      IMPTRA_P04_ACTC  -- 20161223 : IPR 1217
                 FROM CLR_MX9899
                WHERE ID_CLRLOAD = pIDClrLoad
                  AND IDEMEN_P00_ACTC IN (1244,1442,1444) ) LOOP
         GetCtaBan(r.IDEMEN_P00_ACTC, r.NUMTAR_P02_ACTC, r.CODPRO_P03_ACTC, r.PUNSER_P22_ACTC,
                   r.IDEADQ_P32_ACTC, r.IDEEST_P42_ACTC, r.TIPTRA_P48_ACTC, r.TIPMOV_P48_ACTC,
                   r.INDPRE_P48_ACTC, r.FILLER_P48_ACTC,
                   r.CODACT_P18_ACTC , r.IMPTRA_P04_ACTC); -- 20161223 : IPR 1217
         UPDATE CLR_MX9899
            SET CTAABO_P48_ACTC = DECODE(vCodCtaBan,NULL,CTAABO_P48_ACTC,vCodCtaBan),
                FILLER_P62_ACTC = vP62FILLER,
                FILLER_P48_ACTC = vP48FILLER
          WHERE ID_CLRLOAD = pIDClrLoad
            AND ID_REGISTRO = r.ID_REGISTRO;
         vCont:=vCont+1;
         IF MOD(vCont,1000) = 0 THEN
            PQMONPROC.InsLog(pIDproc,'M','Registros Procesados: '||LTRIM(RTRIM(TO_CHAR(vCont,'999,999')))||' ...');
         END IF;
     END LOOP;
     PQMONPROC.InsLog(pIDproc,'M','Registros Procesados: '||LTRIM(RTRIM(TO_CHAR(vCont,'999,999'))));
  END IF;

  -- CLR_MX9798
  IF pCodArchivo = 'MX9798' THEN
     FOR r IN (SELECT ID_REGISTRO,
                      IDEMEN_P00_ACTC,
                      NUMTAR_P02_ACTC,
                      CODPRO_P03_ACTC,
                      PUNSER_P22_ACTC,
                      IDEADQ_P32_ACTC,
                      IDEEST_P42_ACTC,
                      TIPTRA_P48_ACTC,
                      TIPMOV_P48_ACTC,
                      INDPRE_P48_ACTC,
                      FILLER_P48_ACTC,
                      CODACT_P18_ACTC, -- 20161223 : IPR 1217
                      IMPTRA_P04_ACTC  -- 20161223 : IPR 1217
                 FROM CLR_MX9798
                WHERE ID_CLRLOAD = pIDClrLoad
                  AND IDEMEN_P00_ACTC IN (1244,1442,1444) ) LOOP
         GetCtaBan(r.IDEMEN_P00_ACTC, r.NUMTAR_P02_ACTC, r.CODPRO_P03_ACTC, r.PUNSER_P22_ACTC,
                   r.IDEADQ_P32_ACTC, r.IDEEST_P42_ACTC, r.TIPTRA_P48_ACTC, r.TIPMOV_P48_ACTC,
                   r.INDPRE_P48_ACTC, r.FILLER_P48_ACTC,
                   r.CODACT_P18_ACTC , r.IMPTRA_P04_ACTC); -- 20161223 : IPR 1217
         UPDATE CLR_MX9798
            SET CTAABO_P48_ACTC = DECODE(vCodCtaBan,NULL,CTAABO_P48_ACTC,vCodCtaBan),
                FILLER_P62_ACTC = vP62FILLER,
                FILLER_P48_ACTC = vP48FILLER
          WHERE ID_CLRLOAD = pIDClrLoad
            AND ID_REGISTRO = r.ID_REGISTRO;
         vCont:=vCont+1;
         IF MOD(vCont,1000) = 0 THEN
            PQMONPROC.InsLog(pIDproc,'M','Registros Procesados: '||LTRIM(RTRIM(TO_CHAR(vCont,'999,999')))||' ...');
         END IF;
     END LOOP;
     PQMONPROC.InsLog(pIDproc,'M','Registros Procesados: '||LTRIM(RTRIM(TO_CHAR(vCont,'999,999'))));
  END IF;

  -- CLR_MX8999
  IF pCodArchivo = 'MX8999' THEN
     FOR r IN (SELECT ID_REGISTRO,
                      IDEMEN_P00_ACTC,
                      NUMTAR_P02_ACTC,
                      CODPRO_P03_ACTC,
                      PUNSER_P22_ACTC,
                      IDEADQ_P32_ACTC,
                      IDEEST_P42_ACTC,
                      TIPTRA_P48_ACTC,
                      TIPMOV_P48_ACTC,
                      INDPRE_P48_ACTC,
                      FILLER_P48_ACTC,
                      CODACT_P18_ACTC, -- 20161223 : IPR 1217
                      IMPTRA_P04_ACTC  -- 20161223 : IPR 1217
                 FROM CLR_MX8999
                WHERE ID_CLRLOAD = pIDClrLoad
                  AND IDEMEN_P00_ACTC IN (1244,1442,1444) ) LOOP
         GetCtaBan(r.IDEMEN_P00_ACTC, r.NUMTAR_P02_ACTC, r.CODPRO_P03_ACTC, r.PUNSER_P22_ACTC,
                   r.IDEADQ_P32_ACTC, r.IDEEST_P42_ACTC, r.TIPTRA_P48_ACTC, r.TIPMOV_P48_ACTC,
                   r.INDPRE_P48_ACTC, r.FILLER_P48_ACTC,
                   r.CODACT_P18_ACTC , r.IMPTRA_P04_ACTC); -- 20161223 : IPR 1217
         UPDATE CLR_MX8999
            SET CTAABO_P48_ACTC = DECODE(vCodCtaBan,NULL,CTAABO_P48_ACTC,vCodCtaBan),
                FILLER_P62_ACTC = vP62FILLER,
                FILLER_P48_ACTC = vP48FILLER
          WHERE ID_CLRLOAD = pIDClrLoad
            AND ID_REGISTRO = r.ID_REGISTRO;
         vCont:=vCont+1;
         IF MOD(vCont,1000) = 0 THEN
            PQMONPROC.InsLog(pIDproc,'M','Registros Procesados: '||LTRIM(RTRIM(TO_CHAR(vCont,'999,999')))||' ...');
         END IF;
     END LOOP;
     PQMONPROC.InsLog(pIDproc,'M','Registros Procesados: '||LTRIM(RTRIM(TO_CHAR(vCont,'999,999'))));
  END IF;

  -- CLR_MX9799
  IF pCodArchivo = 'MX9799' THEN
     FOR r IN (SELECT ID_REGISTRO,
                      IDEMEN_P00_ACTC,
                      NUMTAR_P02_ACTC,
                      CODPRO_P03_ACTC,
                      PUNSER_P22_ACTC,
                      IDEADQ_P32_ACTC,
                      IDEEST_P42_ACTC,
                      TIPTRA_P48_ACTC,
                      TIPMOV_P48_ACTC,
                      INDPRE_P48_ACTC,
                      FILLER_P48_ACTC,
                      CODACT_P18_ACTC, -- 20161223 : IPR 1217
                      IMPTRA_P04_ACTC  -- 20161223 : IPR 1217
                 FROM CLR_MX9799
                WHERE ID_CLRLOAD = pIDClrLoad
                  AND IDEMEN_P00_ACTC IN (1244,1442,1444) ) LOOP
         GetCtaBan(r.IDEMEN_P00_ACTC, r.NUMTAR_P02_ACTC, r.CODPRO_P03_ACTC, r.PUNSER_P22_ACTC,
                   r.IDEADQ_P32_ACTC, r.IDEEST_P42_ACTC, r.TIPTRA_P48_ACTC, r.TIPMOV_P48_ACTC,
                   r.INDPRE_P48_ACTC, r.FILLER_P48_ACTC,
                   r.CODACT_P18_ACTC , r.IMPTRA_P04_ACTC); -- 20161223 : IPR 1217
         UPDATE CLR_MX9799
            SET CTAABO_P48_ACTC = DECODE(vCodCtaBan,NULL,CTAABO_P48_ACTC,vCodCtaBan),
                FILLER_P62_ACTC = vP62FILLER,
                FILLER_P48_ACTC = vP48FILLER
          WHERE ID_CLRLOAD = pIDClrLoad
            AND ID_REGISTRO = r.ID_REGISTRO;
         vCont:=vCont+1;
         IF MOD(vCont,1000) = 0 THEN
            PQMONPROC.InsLog(pIDproc,'M','Registros Procesados: '||LTRIM(RTRIM(TO_CHAR(vCont,'999,999')))||' ...');
         END IF;
     END LOOP;
     PQMONPROC.InsLog(pIDproc,'M','Registros Procesados: '||LTRIM(RTRIM(TO_CHAR(vCont,'999,999'))));
  END IF;

  --
  RETURN '0';
EXCEPTION
  WHEN OTHERS THEN
       vOraCode:=ABS(SQLCODE);
       ROLLBACK;
       PQMONPROC.InsLog(pIDproc,'E','Error de Base de Datos (ORA-'||LTRIM(LPAD(vOraCode,5,'0'))||')' || ' comercio ' || vrefadq);
       RETURN 'E';
END; -- UpdCtaBanXID


-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
-- FUNCTION UpdCtaBan
-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

FUNCTION UpdCtaBan (pFecSesion DATE, pHoraProc CHAR) RETURN CHAR
IS
vRet         VARCHAR2(512);
vOraCode     NUMBER:=0;
vIDproc      NUMBER;
BEGIN
  gNumERR := 0;
  vIDproc:=PQMONPROC.InsMonProc('CLRUPDCTABAN');
  PQMONPROC.InsLog(vIDproc,'M','INICIO | Fecha de Sesion: '||TO_CHAR(pFecSesion,'DD/MM/YYYY')||' / Hora de Proceso: '||pHoraProc||':00 hrs.');
  FOR r IN (SELECT COD_ARCHIVO,
                   ID_CLRLOAD
              FROM CTL_CLRLOAD
             WHERE FEC_SESION = pFecSesion
               AND HRA_PROCESO = pHoraProc
               AND EST_PROCESO = 'F'
               AND COD_ARCHIVO IN ('MX9998','MX9999','MX9898','MX9899','MX9798','MX8998','MX8999','MX9799')
             ORDER BY ID_CLRLOAD) LOOP
      vRet:=UpdCtaBanXID(r.COD_ARCHIVO,r.ID_CLRLOAD,vIDproc);
      IF vRet = 'E' THEN
         gNumERR:=gNumERR+1;
         PQMONPROC.InsLog(vIDproc,'E','Error en la ejecuci??????n de UpdCtaBanXID');
      END IF;
  END LOOP;
  IF gNumERR = 0 THEN
     PQMONPROC.InsLog(vIDproc,'M','FIN OK | Fecha de Sesion: '||TO_CHAR(pFecSesion,'DD/MM/YYYY')||' / Hora de Proceso: '||pHoraProc||':00 hrs.');
     vRet:=PQMONPROC.UpdMonProc(vIDproc,'F');
     RETURN '0';
  ELSE
     PQMONPROC.InsLog(vIDproc,'M','FIN ERROR | Fecha de Sesion: '||TO_CHAR(pFecSesion,'DD/MM/YYYY')||' / Hora de Proceso: '||pHoraProc||':00 hrs.');
     vRet:=PQMONPROC.UpdMonProc(vIDproc,'E');
     RETURN 'E|ERROR en Asignacion de Cuentas Bancarias. Revisar Monitor de Procesos.~';
  END IF;
EXCEPTION
  WHEN OTHERS THEN
       vOraCode:=ABS(SQLCODE);
       ROLLBACK;
       PQMONPROC.InsLog(vIDproc,'M','FIN ERROR | Fecha de Sesion: '||TO_CHAR(pFecSesion,'DD/MM/YYYY')||' / Hora de Proceso: '||pHoraProc||':00 hrs.');
       vRet:=PQMONPROC.UpdMonProc(vIDproc,'E');
       RETURN 'E|ERROR de Base de Datos (ORA-'||LTRIM(LPAD(vOraCode,5,'0'))||')~';
END; -- UpdCtaBan


-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
-- FUNCTION RevCarga
-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

FUNCTION RevCarga (pFecSesion DATE, pHoraProc CHAR:=NULL) RETURN CHAR
IS
vRet         VARCHAR2(512);
vOraCode     NUMBER:=0;
BEGIN
  FOR r IN (SELECT ID_CLRLOAD
              FROM CTL_CLRLOAD
             WHERE FEC_SESION = TRUNC(pFecSesion)
               AND HRA_PROCESO = DECODE (pHoraProc,NULL,HRA_PROCESO,pHoraProc)
             ORDER BY ID_CLRLOAD) LOOP
      vRet:=RevCargaXID(r.ID_CLRLOAD);
      IF SUBSTR(vRet,1,1) = 'E' THEN
         RETURN vRet;
      END IF;
  END LOOP;
  RETURN '0';
EXCEPTION
  WHEN OTHERS THEN
       vOraCode:=ABS(SQLCODE);
       ROLLBACK;
       RETURN 'E|Error de Base de Datos (ORA-'||LTRIM(LPAD(vOraCode,5,'0'))||')';
END; -- RevCarga


-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
-- PROCEDURE VrfCarga
-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

PROCEDURE VrfCarga (pFecSesion DATE:=NULL, pHoraProc CHAR:=NULL)
IS

vFecSesion   CTL_CLRLOAD.FEC_SESION%TYPE;
vHoraProc    CTL_CLRLOAD.HRA_PROCESO%TYPE;
vHoraSys     CTL_CLRLOAD.HRA_PROCESO%TYPE;
vIDClrLoad   CTL_CLRLOAD.ID_CLRLOAD%TYPE;
vCntReg      NUMBER:=0;
vCntErr      NUMBER:=0;
vCntCFG      NUMBER:=0;
vOraCode     NUMBER:=0;

BEGIN

  -- Fecha de Sesion
  IF pFecSesion IS NOT NULL THEN
     vFecSesion:=TRUNC(pFecSesion);
  ELSE
     vFecSesion:=TRUNC(SYSDATE);
  END IF;

  -- Hora de Proceso
  IF vHoraProc IS NOT NULL THEN
     vHoraProc:=pHoraProc;
  ELSE
     vHoraSys:=TO_CHAR(SYSDATE,'HH24');
     IF vHoraSys = '00' THEN
        vHoraProc:='23';
        vFecSesion:=TRUNC(SYSDATE-1);
     ELSE
        vHoraProc:=LPAD(TO_NUMBER(vHoraSys)-1,2,'0');
     END IF;
  END IF;

  -- Verificacion de la Carga
  SELECT COUNT(FEC_SESION)
    INTO vCntReg
    FROM CTL_CLRLOAD
   WHERE FEC_SESION = vFecSesion
     AND HRA_PROCESO = vHoraProc;

  IF vCntReg IS NULL OR vCntReg = 0 THEN
     -- ALERTA: Carga de Archivos NO Realizada
     gRetN:=PQMONPROC.InsAlerta('SGCPCLRLOAD | Carga de Archivos de Datos NO Realizada (Hora: '||vHoraProc||':00 hrs.');
  END IF;

  -- Verificacion de Errores en la Carga
  SELECT COUNT(FEC_SESION)
    INTO vCntErr
    FROM CTL_CLRLOAD
   WHERE FEC_SESION = vFecSesion
     AND HRA_PROCESO = vHoraProc
     AND EST_PROCESO = 'E';

  IF vCntErr > 0 THEN
     -- ALERTA: Errores en la Carga de Archivos
     gRetN:=PQMONPROC.InsAlerta('SGCPCLRLOAD | '||vCntErr||' Errores en la Carga de Archivos de Datos (Hora: '||vHoraProc||':00 hrs.');
  END IF;

  -- Verificacion de Cantidad de Archivos Cargados
  SELECT COUNT(COD_ARCHIVO)
    INTO vCntCFG
    FROM CFG_CLRLOAD;

  IF vCntCFG <> vCntReg THEN
     -- ALERTA: Cantidad de Archivos Cargados Diferente
     gRetN:=PQMONPROC.InsAlerta('SGCPCLRLOAD | Carga de Archivos Incompleta (Hora: '||vHoraProc||':00 hrs.');
  END IF;

EXCEPTION
  WHEN OTHERS THEN
       vOraCode:=ABS(SQLCODE);
END; -- VrfCarga


-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
-- FUNCTION UpdComIntMCXID
-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

FUNCTION UpdComIntMCXID (pCodArchivo CHAR, pIDClrLoad NUMBER, pIDproc NUMBER) RETURN CHAR
IS

vIRD        CHAR(2):=NULL;
vComiTot    NUMBER:=0;
vP46IMPCU1  NUMBER:=0;
vP46IMPCU2  NUMBER:=0;
vP46SIGCU3  CHAR(1):=NULL;
vP46IMPCU3  NUMBER:=0;

vOraCode    NUMBER:=0;
vOraErr     VARCHAR2(200):=NULL;
vCont       NUMBER:=0;
vx_registro NUMBER ; /* Colocado por TST 06/03/2018 */
vx_idload   NUMBER ; /* Colocado por TST 04/08/2020 */

function f_findTipoCambio(pfecha date)return number is
     --vtip_cambio     number(11,3);
     vtip_cambio SGDVNZ.disputas_tipo_cambio_incoming.tipo_cambio%TYPE;
begin
    select distinct tipo_cambio
      into vtip_cambio
      from disputas_tipo_cambio_incoming
     where cod_marca      = 'MC'
       and incoming_date  = pfecha;

     return NVL(vtip_cambio,0);

exception
  WHEN OTHERS THEN
     PQMONPROC.InsLog(pIDproc,'E','Error al Buscar Tipo de cambio fecha:'||pfecha||', Function:PQPCLRLOAD.f_findTipoCambio');
end;

function GetComiEMI(pP46TCUOT01 char,
                    pP46TCUOT02 char) return number is

vSigno   char(1);
vMonto   number:=0;
vImporte number:=0;
begin
  if pP46TCUOT01 is not null then
     vSigno:=substr(pP46TCUOT01,3,1);
     vMonto:=substr(pP46TCUOT01,4,10);--8-- IPR 1334 Karina Rojas 16/07/2020
     if vSigno='D' then -- actua como cargo
        vImporte:=vImporte-vMonto;
     elsif vSigno='C' then -- actua como abono
           vImporte:=vImporte+vMonto;
     end if;
  end if ;
  if pP46TCUOT02 is not null then
     vSigno:=substr(pP46TCUOT02,3,1);
     vMonto:=substr(pP46TCUOT02,4,10);--8-- IPR 1334 Karina Rojas 16/07/2020
     if vSigno='D' then
        vImporte:=vImporte-vMonto;
     elsif vSigno='C' then
           vImporte:=vImporte+vMonto;
     end if;
  end if ;
 return vImporte;
end ;

function GetComiADQ(pP46TCUOT03 char,
                    pP46TCUOT04 char,
                    pP48FILLER  char ) return number is

vSigno   char(1);
vMonto   number:=0;
vImporte number:=0;
vPVM     number(5,2); -- Porcentaje de Provimillas
begin

  vPVM := pqcomercios.gcw_f_getpporcprovimilla(pP48FILLER);

  if pP46TCUOT03 is not null then
     vSigno:=substr(pP46TCUOT03,3,1);
     vMonto:=substr(pP46TCUOT03,4,10);--8-- IPR 1334 Karina Rojas 16/07/2020
     vMonto:=vMonto*(1-vPVM);
     if vSigno='D' then
        vImporte:=vImporte-vMonto;
     elsif vSigno='C' then
           vImporte:=vImporte+vMonto;
     end if;
  end if ;
  if pP46TCUOT04 is not null then
     vSigno:=substr(pP46TCUOT04,3,1);
     vMonto:=substr(pP46TCUOT04,4,10);--8-- IPR 1334 Karina Rojas 16/07/2020
     vMonto:=vMonto*(1-vPVM);
     if vSigno='D' then
        vImporte:=vImporte-vMonto;
     elsif vSigno='D' then
           vImporte:=vImporte+vMonto;
     end if;
  end if;
 return vImporte;
end ;

procedure GetComisiones (pP28SESION DATE, pP04IMPTRA NUMBER,
                         pP46TCUOT01 CHAR, pP46TCUOT02 CHAR, pP48TIPTRA CHAR,
                         pP18CODACT CHAR, pP48TIPMOV CHAR)
is
vComPCTL  NUMBER:=0;
vComFIJA  NUMBER:=0;
vTC       NUMBER:=0;
begin
  -- Obtiene las Comisiones Porcentual y Fija
  BEGIN
    SELECT NVL(COM_PCTL,0)/100 COM_PCTL,
           NVL(COM_FIJA,0)
      INTO vComPCTL,
           vComFIJA
      FROM CFG_MCIRD
     WHERE COD_TIPTRA = SUBSTR(pP48TIPTRA,1,2)
       AND COD_IRD = vIRD
       AND FEC_INIVIG <= TO_DATE(pP28SESION,'DD/MM/YYYY')
       AND FEC_FINVIG >= TO_DATE(pP28SESION,'DD/MM/YYYY');

       --PQMONPROC.InsLog(pIDproc,'M',',P48TIPTRA:'||pP48TIPTRA||',P28SESION:'||pP28SESION||',vIRD:'||vIRD||',ComPCTL:'||vComPCTL||',ComFIJA:'||vComFIJA);

  EXCEPTION
    WHEN NO_DATA_FOUND THEN
         SELECT (DECODE(pP48TIPMOV,'c',TASA_CRE,'d',TASA_DEB)*0.8)/100 COM_PCTL
           INTO vComPCTL
           FROM MCC_PMP
          WHERE COD_MCC = pP18CODACT;

         ---PQMONPROC.InsLog(pIDproc,'M','P18CODACT: '||pP18CODACT||',ComPCTL:'||vComPCTL);

         vComFIJA:=0;
  END;
  -- Obtiene Tasa de Cambio
  -- vTC:=GetTC();
  --  vTC:=2.15;
  PQMONPROC.InsLog(pIDproc,'M','Inicio Procesando Tipo de Cambio f_findTipoCambio');
  vTC := f_findTipoCambio(pP28SESION-1);
  PQMONPROC.InsLog(pIDproc,'M','Fin Procesando Tipo de Cambio f_findTipoCambio');
  -- Calcula Comisiones
  vP46IMPCU1:=ROUND(vComPCTL*pP04IMPTRA);
  IF SUBSTR(pP46TCUOT01,3,1) = 'D' THEN
     vP46IMPCU1:=ABS(vP46IMPCU1); --vP46IMPCU1:=(-1)*vP46IMPCU1;
  END IF;
  vP46IMPCU2:=(vComFIJA*vTC)*100;
  IF SUBSTR(pP46TCUOT02,3,1) = 'D' THEN
     vP46IMPCU2:=ABS(vP46IMPCU2); --vP46IMPCU2:=(-1)*vP46IMPCU2;
  END IF;
  vP46IMPCU3:=vComiTot-(vP46IMPCU1+vP46IMPCU2);
  IF vP46IMPCU3 < 0 THEN
     vP46IMPCU3:=ABS(vP46IMPCU3);
     vP46SIGCU3:='D';
  ELSE
     vP46SIGCU3:='C';
  END IF;
  PQMONPROC.InsLog(pIDproc,'M','Fin Procesando GetComisiones - Funtion Interna');
end;

BEGIN
  -- Inicio
  PQMONPROC.InsLog(pIDproc,'M','Procesando '||pCodArchivo||'(IDCLRLOAD='||pIDClrLoad||'|IDPROC='||pIDproc||')...');
  dbms_output.put_line ('Procesando '||pCodArchivo||'(IDCLRLOAD='||pIDClrLoad||'|IDPROC='||pIDproc||')...');
  -- CLR_EX8010
  IF pCodArchivo = 'EX8010' THEN
     PQMONPROC.InsLog(pIDproc,'M','Inicio procesando tabla:'||pCodArchivo);
     FOR r IN (SELECT ID_REGISTRO,
                      LONTAR_L02_ACTC P02LONTAR,
                      NUMTAR_P02_ACTC P02NUMTAR,
                      CODPRO_P03_ACTC P03CODPRO,
                      IMPTRA_P04_ACTC P04IMPTRA,
                      TIMLOC_P12_ACTC P12TIMLOC,
                      PUNSER_P22_ACTC P22PUNSER,
                      CODACT_P18_ACTC P18CODACT,
                      CODACT_P26_ACTC P26CODACT,
                      TO_DATE(SESION_P28_ACTC,'RRMMDD') P28SESION,
                      LPAD(NVL(CODSER_P40_ACTC,'0'),3,'0') P40CODSER,
                      LPAD(NVL(TIPCU1_P46_ACTC,0),2,0)||LPAD(NVL(SIGCU1_P46_ACTC,0),1,0)||LPAD(NVL(IMPCU1_P46_ACTC,0),10,0) P46TCUOT01, --8-- IPR 1334 Karina Rojas 16/07/2020
                      LPAD(NVL(TIPCU2_P46_ACTC,0),2,0)||LPAD(NVL(SIGCU2_P46_ACTC,0),1,0)||LPAD(NVL(IMPCU2_P46_ACTC,0),10,0) P46TCUOT02, --8-- IPR 1334 Karina Rojas 16/07/2020
                      LPAD(NVL(TIPCU3_P46_ACTC,0),2,0)||LPAD(NVL(SIGCU3_P46_ACTC,0),1,0)||LPAD(NVL(IMPCU3_P46_ACTC,0),10,0) P46TCUOT03, --8-- IPR 1334 Karina Rojas 16/07/2020
                      LPAD(NVL(TIPCU4_P46_ACTC,0),2,0)||LPAD(NVL(SIGCU4_P46_ACTC,0),1,0)||LPAD(NVL(IMPCU4_P46_ACTC,0),10,0) P46TCUOT04, --8-- IPR 1334 Karina Rojas 16/07/2020
                      TIPMOV_P48_ACTC P48TIPMOV,
                      TIPTRA_P48_ACTC P48TIPTRA,
                      DECODE(SUBSTR(IDEADQ_P32_ACTC,3,4),'0105','BM','0108','BP') COD_ENTADQ,
                      LPAD(vtapla_p48_actc,2,'0')||RPAD(SUBSTR(filler_p48_actc,3),11,' ')||LPAD(mcashb_p48_actc,10,'0')||LPAD(indpre_p48_actc,2,' ')||LPAD(NVL(SUBSTR(numgui_p48_actc,2,3),' '),3,' ') P48FILLER
                 FROM CLR_EX8010
                WHERE ID_CLRLOAD = pIDClrLoad
                  AND INLOTE_P29_ACTC = '516' order by p02numtar asc ) LOOP
         dbms_output.put_line ('OBTIENE COMISIONES');
         dbms_output.put_line ('******************');
         dbms_output.put_line ('ID_REGISTRO: '||r.ID_REGISTRO);
         dbms_output.put_line ('P02NUMTAR: '||r.P02NUMTAR);
         dbms_output.put_line ('P48TIPTRA: '||r.P48TIPTRA);
         -- Obtiene el IRD
         IF SUBSTR(r.P48TIPTRA,1,2)  = '10' THEN
            vIRD:=gIRDMCM;
         ELSE
            -- vIRD:=SF_GETMCIRD(pIDproc, r.P02NUMTAR,r.COD_ENTADQ,r.P12TIMLOC,r.P22PUNSER,r.P26CODACT);
            dbms_output.put_line ('P03CODPRO '||r.P03CODPRO);
            dbms_output.put_line ('P12TIMLOC '||r.P12TIMLOC);
            dbms_output.put_line ('P22PUNSER '||r.P22PUNSER);
            dbms_output.put_line ('P26CODACT '||r.P26CODACT);
            PQMONPROC.InsLog(pIDproc,'M','Inicio procesar: SF_GETMCIRD, NUMTAR:'||r.P02NUMTAR||',COD_ENTADQ:'||r.COD_ENTADQ||',P02LONTAR'||r.P02LONTAR||',P03CODPRO:'||r.P03CODPRO||',P12TIMLOC:'||r.P12TIMLOC||',P22PUNSER:'||r.P22PUNSER||',P26CODACT:'||r.P26CODACT||',P40CODSER:'||r.P40CODSER); /* Colocado por TsT 01/01/2021*/
            vIRD:=SF_GETMCIRD(pIDproc, r.P02NUMTAR,r.COD_ENTADQ,r.P02LONTAR,r.P03CODPRO,r.P12TIMLOC,r.P22PUNSER,r.P26CODACT,r.P40CODSER);
            PQMONPROC.InsLog(pIDproc,'M','vIRD_8010: '||vIRD||',NTARJ:'||r.P02NUMTAR||',ENTADQ'||r.COD_ENTADQ); /* Modificado 06/03/2018 */
            PQMONPROC.InsLog(pIDproc,'M','VARIABLES:'||vP46IMPCU1||','||vP46IMPCU2||','||vP46SIGCU3||','||vP46IMPCU3||',REG:'||r.ID_REGISTRO); /* Modificado 06/03/2018 */
            dbms_output.put_line ('vIRD_8010: '||vIRD);
         END IF;

         -- Obtiene la Comision del Comercio (Comision Total)
         PQMONPROC.InsLog(pIDproc,'M','Inicio procesar: GetComiEMI');
         vComiTot:=GetComiEMI(r.P46TCUOT01,r.P46TCUOT02)+GetComiADQ(r.P46TCUOT03, r.P46TCUOT04, r.P48FILLER);
         dbms_output.put_line ('vComiTot: '||vComiTot);
         -- Obtiene las Nuevas Comisiones
         /*
         dbms_output.put_line ('P28SESION: '||r.P28SESION);
         dbms_output.put_line ('P04IMPTRA: '||r.P04IMPTRA);
         dbms_output.put_line ('P46TCUOT01: '||r.P46TCUOT01);
         dbms_output.put_line ('P46TCUOT02: '||r.P46TCUOT02);
         dbms_output.put_line ('P48TIPTRA: '||r.P48TIPTRA);
         dbms_output.put_line ('P18CODACT: '||r.P18CODACT);
         dbms_output.put_line ('P48TIPMOV: '||r.P48TIPMOV);
         */
         PQMONPROC.InsLog(pIDproc,'M','Inicio procesar: GetComisiones'||', Tabla :'||pCodArchivo);
         GetComisiones(r.P28SESION,r.P04IMPTRA,r.P46TCUOT01,r.P46TCUOT02,r.P48TIPTRA,r.P18CODACT,r.P48TIPMOV);
         PQMONPROC.InsLog(pIDproc,'M','Fin procesar: GetComisiones'||', Tabla :'||pCodArchivo);
         /*
         dbms_output.put_line ('vP46IMPCU1: '||vP46IMPCU1);
         dbms_output.put_line ('vP46IMPCU2: '||vP46IMPCU2);
         dbms_output.put_line ('vP46SIGCU3: '||vP46SIGCU3);
         dbms_output.put_line ('vP46IMPCU3: '||vP46IMPCU3);
         */
        ---PQMONPROC.InsLog(pIDproc,'M','Inicio Actualizando CLR_EX8010'||',pIDClrLoad'||pIDClrLoad||', r.ID_REGISTRO:'||r.ID_REGISTRO);
        vx_registro:=r.ID_REGISTRO; /* cOLOCADO POR tst 06/03/2018*/
         -- Actualiza Campos de Comisiones
         --PQMONPROC.InsLog(pIDproc,'M','Inicio actualizando EX8010,vP46IMPCU1:'||TO_CHAR(vP46IMPCU1)||',vP46IMPCU2:'||TO_CHAR(vP46IMPCU2)||',vP46SIGCU3:'||TO_CHAR(vP46SIGCU3)||',vP46IMPCU3:'||TO_CHAR(vP46IMPCU3));
         UPDATE CLR_EX8010
            SET IMPCU1_P46_ACTC = vP46IMPCU1,
                IMPCU2_P46_ACTC = vP46IMPCU2,
                SIGCU3_P46_ACTC = vP46SIGCU3,
                IMPCU3_P46_ACTC = vP46IMPCU3
          WHERE ID_CLRLOAD = pIDClrLoad
            AND ID_REGISTRO = r.ID_REGISTRO;
         COMMIT;
         --PQMONPROC.InsLog(pIDproc,'M','Fin actualizando EX8010');
         
          ---PQMONPROC.InsLog(pIDproc,'M','Fin Actualizando CLR_EX8010'||',pIDClrLoad'||pIDClrLoad||', r.ID_REGISTRO:'||r.ID_REGISTRO);

         -- Contador
         vCont:=vCont+1;
         IF MOD(vCont,1000) = 0 THEN

            PQMONPROC.InsLog(pIDproc,'M','Registros Procesados: '||LTRIM(RTRIM(TO_CHAR(vCont,'999,999')))||' ...');
         END IF;

     END LOOP;
     PQMONPROC.InsLog(pIDproc,'M','Registros Procesados: '||LTRIM(RTRIM(TO_CHAR(vCont,'999,999'))));
  END IF;

  -- CLR_MX9898
  IF pCodArchivo = 'MX9898' THEN
     PQMONPROC.InsLog(pIDproc,'M','Inicio procesando tabla:'||pCodArchivo);
     FOR r IN (SELECT ID_REGISTRO,
                      LONTAR_L02_ACTC P02LONTAR,
                      NUMTAR_P02_ACTC P02NUMTAR,
                      CODPRO_P03_ACTC P03CODPRO,
                      IMPTRA_P04_ACTC P04IMPTRA,
                      TIMLOC_P12_ACTC P12TIMLOC,
                      PUNSER_P22_ACTC P22PUNSER,
                      CODACT_P18_ACTC P18CODACT,
                      CODACT_P26_ACTC P26CODACT,
                      TO_DATE(SESION_P28_ACTC,'RRMMDD') P28SESION,
                      LPAD(NVL(CODSER_P40_ACTC,'0'),3,'0') P40CODSER,
                      LPAD(NVL(TIPCU1_P46_ACTC,0),2,0)||LPAD(NVL(SIGCU1_P46_ACTC,0),1,0)||LPAD(NVL(IMPCU1_P46_ACTC,0),10,0) P46TCUOT01,--8-- IPR 1334 Karina Rojas 16/07/2020
                      LPAD(NVL(TIPCU2_P46_ACTC,0),2,0)||LPAD(NVL(SIGCU2_P46_ACTC,0),1,0)||LPAD(NVL(IMPCU2_P46_ACTC,0),10,0) P46TCUOT02,--8-- IPR 1334 Karina Rojas 16/07/2020
                      LPAD(NVL(TIPCU3_P46_ACTC,0),2,0)||LPAD(NVL(SIGCU3_P46_ACTC,0),1,0)||LPAD(NVL(IMPCU3_P46_ACTC,0),10,0) P46TCUOT03,--8-- IPR 1334 Karina Rojas 16/07/2020
                      LPAD(NVL(TIPCU4_P46_ACTC,0),2,0)||LPAD(NVL(SIGCU4_P46_ACTC,0),1,0)||LPAD(NVL(IMPCU4_P46_ACTC,0),10,0) P46TCUOT04,--8-- IPR 1334 Karina Rojas 16/07/2020
                      TIPMOV_P48_ACTC P48TIPMOV,
                      TIPTRA_P48_ACTC P48TIPTRA,
                      DECODE(SUBSTR(IDEADQ_P32_ACTC,3,4),'0105','BM','0108','BP') COD_ENTADQ,
                      LPAD(vtapla_p48_actc,2,'0')||RPAD(SUBSTR(filler_p48_actc,3),11,' ')||LPAD(mcashb_p48_actc,10,'0')||LPAD(indpre_p48_actc,2,' ')||LPAD(NVL(SUBSTR(numgui_p48_actc,2,3),' '),3,' ') P48FILLER
                 FROM CLR_MX9898
                WHERE ID_CLRLOAD = pIDClrLoad
                  AND INLOTE_P29_ACTC = '316' ) LOOP

         -- Obtiene el IRD
         IF SUBSTR(r.P48TIPTRA,1,2)  = '10' THEN
            vIRD:=gIRDMCM;
         ELSE
            -- vIRD:=SF_GETMCIRD(pIDproc, r.P02NUMTAR,r.COD_ENTADQ,r.P12TIMLOC,r.P22PUNSER,r.P26CODACT);
            --vIRD:=SF_GETMCIRD(pIDproc, r.P02NUMTAR,r.COD_ENTADQ,r.P03CODPRO,r.P12TIMLOC,r.P22PUNSER,r.P26CODACT);
            vIRD:=SF_GETMCIRD(pIDproc, r.P02NUMTAR,r.COD_ENTADQ,r.P02LONTAR,r.P03CODPRO,r.P12TIMLOC,r.P22PUNSER,r.P26CODACT,r.P40CODSER);
            PQMONPROC.InsLog(pIDproc,'M','vIRD: '||vIRD);
         END IF;

         -- Obtiene la Comision del Comercio (Comision Total)
         vComiTot:=GetComiEMI(r.P46TCUOT01,r.P46TCUOT02)+GetComiADQ(r.P46TCUOT03, r.P46TCUOT04, r.P48FILLER);

         -- Obtiene las Nuevas Comisiones
         GetComisiones(r.P28SESION,r.P04IMPTRA,r.P46TCUOT01,r.P46TCUOT02,r.P48TIPTRA,r.P18CODACT,r.P48TIPMOV);

         -- Actualiza Campos de Comisiones
         UPDATE CLR_MX9898
            SET IMPCU1_P46_ACTC = vP46IMPCU1,
                IMPCU2_P46_ACTC = vP46IMPCU2,
                SIGCU3_P46_ACTC = vP46SIGCU3,
                IMPCU3_P46_ACTC = vP46IMPCU3
          WHERE ID_CLRLOAD = pIDClrLoad
            AND ID_REGISTRO = r.ID_REGISTRO;

         -- Contador
         vCont:=vCont+1;
         IF MOD(vCont,1000) = 0 THEN
            PQMONPROC.InsLog(pIDproc,'M','Registros Procesados: '||LTRIM(RTRIM(TO_CHAR(vCont,'999,999')))||' ...');
         END IF;

     END LOOP;
     PQMONPROC.InsLog(pIDproc,'M','Registros Procesados: '||LTRIM(RTRIM(TO_CHAR(vCont,'999,999'))));
  END IF;

  -- CLR_MX9899
  IF pCodArchivo = 'MX9899' THEN
     PQMONPROC.InsLog(pIDproc,'M','Inicio procesando tabla:'||pCodArchivo);
     FOR r IN (SELECT ID_REGISTRO,
                      LONTAR_L02_ACTC P02LONTAR,
                      NUMTAR_P02_ACTC P02NUMTAR,
                      CODPRO_P03_ACTC P03CODPRO,
                      IMPTRA_P04_ACTC P04IMPTRA,
                      TIMLOC_P12_ACTC P12TIMLOC,
                      PUNSER_P22_ACTC P22PUNSER,
                      CODACT_P18_ACTC P18CODACT,
                      CODACT_P26_ACTC P26CODACT,
                      TO_DATE(SESION_P28_ACTC,'RRMMDD') P28SESION,
                      LPAD(NVL(CODSER_P40_ACTC,'0'),3,'0') P40CODSER,
                      LPAD(NVL(TIPCU1_P46_ACTC,0),2,0)||LPAD(NVL(SIGCU1_P46_ACTC,0),1,0)||LPAD(NVL(IMPCU1_P46_ACTC,0),10,0) P46TCUOT01,--8-- IPR 1334 Karina Rojas 16/07/2020
                      LPAD(NVL(TIPCU2_P46_ACTC,0),2,0)||LPAD(NVL(SIGCU2_P46_ACTC,0),1,0)||LPAD(NVL(IMPCU2_P46_ACTC,0),10,0) P46TCUOT02,--8-- IPR 1334 Karina Rojas 16/07/2020
                      LPAD(NVL(TIPCU3_P46_ACTC,0),2,0)||LPAD(NVL(SIGCU3_P46_ACTC,0),1,0)||LPAD(NVL(IMPCU3_P46_ACTC,0),10,0) P46TCUOT03,--8-- IPR 1334 Karina Rojas 16/07/2020
                      LPAD(NVL(TIPCU4_P46_ACTC,0),2,0)||LPAD(NVL(SIGCU4_P46_ACTC,0),1,0)||LPAD(NVL(IMPCU4_P46_ACTC,0),10,0) P46TCUOT04,--8-- IPR 1334 Karina Rojas 16/07/2020
                      TIPMOV_P48_ACTC P48TIPMOV,
                      TIPTRA_P48_ACTC P48TIPTRA,
                      DECODE(SUBSTR(IDEADQ_P32_ACTC,3,4),'0105','BM','0108','BP') COD_ENTADQ,
                      LPAD(vtapla_p48_actc,2,'0')||RPAD(SUBSTR(filler_p48_actc,3),11,' ')||LPAD(mcashb_p48_actc,10,'0')||LPAD(indpre_p48_actc,2,' ')||LPAD(NVL(SUBSTR(numgui_p48_actc,2,3),' '),3,' ') P48FILLER
                 FROM CLR_MX9899
                WHERE ID_CLRLOAD = pIDClrLoad
                  AND INLOTE_P29_ACTC = '316' ) LOOP

         -- Obtiene el IRD
         IF SUBSTR(r.P48TIPTRA,1,2)  = '10' THEN
            vIRD:=gIRDMCM;
         ELSE
            -- vIRD:=SF_GETMCIRD(pIDproc, r.P02NUMTAR,r.COD_ENTADQ,r.P12TIMLOC,r.P22PUNSER,r.P26CODACT);
            --vIRD:=SF_GETMCIRD(pIDproc, r.P02NUMTAR,r.COD_ENTADQ,r.P03CODPRO,r.P12TIMLOC,r.P22PUNSER,r.P26CODACT);
            vIRD:=SF_GETMCIRD(pIDproc, r.P02NUMTAR,r.COD_ENTADQ,r.P02LONTAR,r.P03CODPRO,r.P12TIMLOC,r.P22PUNSER,r.P26CODACT,r.P40CODSER);
         END IF;

         -- Obtiene la Comision del Comercio (Comision Total)
         vComiTot:=GetComiEMI(r.P46TCUOT01,r.P46TCUOT02)+GetComiADQ(r.P46TCUOT03, r.P46TCUOT04, r.P48FILLER);

         -- Obtiene las Nuevas Comisiones
         GetComisiones(r.P28SESION,r.P04IMPTRA,r.P46TCUOT01,r.P46TCUOT02,r.P48TIPTRA,r.P18CODACT,r.P48TIPMOV);

         -- Actualiza Campos de Comisiones
         UPDATE CLR_MX9899
            SET IMPCU1_P46_ACTC = vP46IMPCU1,
                IMPCU2_P46_ACTC = vP46IMPCU2,
                SIGCU3_P46_ACTC = vP46SIGCU3,
                IMPCU3_P46_ACTC = vP46IMPCU3
          WHERE ID_CLRLOAD = pIDClrLoad
            AND ID_REGISTRO = r.ID_REGISTRO;

         -- Contador
         vCont:=vCont+1;
         IF MOD(vCont,1000) = 0 THEN
            PQMONPROC.InsLog(pIDproc,'M','Registros Procesados: '||LTRIM(RTRIM(TO_CHAR(vCont,'999,999')))||' ...');
         END IF;

     END LOOP;
     PQMONPROC.InsLog(pIDproc,'M','Registros Procesados: '||LTRIM(RTRIM(TO_CHAR(vCont,'999,999'))));
  END IF;

  --- 20120912
  --- crosadof -> problema con las comisiones internacionales.... se agreg?????? el update a los archivos MX0105 y MX0108
  ---             con esto ya no van a haber problemas con las representaciones internacionales sin comisiones.....

-- CLR_MX0105
  IF pCodArchivo = 'MX0105' THEN
     PQMONPROC.InsLog(pIDproc,'M','Inicio procesando tabla:'||pCodArchivo);
     FOR r IN (SELECT ID_REGISTRO,
                      LONTAR_L02_ACTC P02LONTAR,
                      NUMTAR_P02_ACTC P02NUMTAR,
                      CODPRO_P03_ACTC P03CODPRO,
                      IMPTRA_P04_ACTC P04IMPTRA,
                      TIMLOC_P12_ACTC P12TIMLOC,
                      PUNSER_P22_ACTC P22PUNSER,
                      CODACT_P18_ACTC P18CODACT,
                      CODACT_P26_ACTC P26CODACT,
                      TO_DATE(SESION_P28_ACTC,'RRMMDD') P28SESION,
                      LPAD(NVL(CODSER_P40_ACTC,'0'),3,'0') P40CODSER,
                      LPAD(NVL(TIPCU1_P46_ACTC,0),2,0)||LPAD(NVL(SIGCU1_P46_ACTC,0),1,0)||LPAD(NVL(IMPCU1_P46_ACTC,0),10,0) P46TCUOT01,--8-- IPR 1334 Karina Rojas 16/07/2020
                      LPAD(NVL(TIPCU2_P46_ACTC,0),2,0)||LPAD(NVL(SIGCU2_P46_ACTC,0),1,0)||LPAD(NVL(IMPCU2_P46_ACTC,0),10,0) P46TCUOT02,--8-- IPR 1334 Karina Rojas 16/07/2020
                      LPAD(NVL(TIPCU3_P46_ACTC,0),2,0)||LPAD(NVL(SIGCU3_P46_ACTC,0),1,0)||LPAD(NVL(IMPCU3_P46_ACTC,0),10,0) P46TCUOT03,--8-- IPR 1334 Karina Rojas 16/07/2020
                      LPAD(NVL(TIPCU4_P46_ACTC,0),2,0)||LPAD(NVL(SIGCU4_P46_ACTC,0),1,0)||LPAD(NVL(IMPCU4_P46_ACTC,0),10,0) P46TCUOT04,--8-- IPR 1334 Karina Rojas 16/07/2020
                      TIPMOV_P48_ACTC P48TIPMOV,
                      TIPTRA_P48_ACTC P48TIPTRA,
                      DECODE(SUBSTR(IDEADQ_P32_ACTC,3,4),'0105','BM','0108','BP') COD_ENTADQ,
                      LPAD(vtapla_p48_actc,2,'0')||RPAD(SUBSTR(filler_p48_actc,3),11,' ')||LPAD(mcashb_p48_actc,10,'0')||LPAD(indpre_p48_actc,2,' ')||LPAD(NVL(SUBSTR(numgui_p48_actc,2,3),' '),3,' ') P48FILLER
                 FROM CLR_MX0105
                WHERE ID_CLRLOAD = pIDClrLoad
                  AND INLOTE_P29_ACTC = '316' ) LOOP

         -- Obtiene el IRD
         IF SUBSTR(r.P48TIPTRA,1,2)  = '10' THEN
            vIRD:=gIRDMCM;
         ELSE
            -- vIRD:=SF_GETMCIRD(pIDproc, r.P02NUMTAR,r.COD_ENTADQ,r.P12TIMLOC,r.P22PUNSER,r.P26CODACT);
            --vIRD:=SF_GETMCIRD(pIDproc, r.P02NUMTAR,r.COD_ENTADQ,r.P03CODPRO,r.P12TIMLOC,r.P22PUNSER,r.P26CODACT);
            vIRD:=SF_GETMCIRD(pIDproc, r.P02NUMTAR,r.COD_ENTADQ,r.P02LONTAR,r.P03CODPRO,r.P12TIMLOC,r.P22PUNSER,r.P26CODACT,r.P40CODSER);
         END IF;

         -- Obtiene la Comision del Comercio (Comision Total)
         vComiTot:=GetComiEMI(r.P46TCUOT01,r.P46TCUOT02)+GetComiADQ(r.P46TCUOT03, r.P46TCUOT04, r.P48FILLER);

         -- Obtiene las Nuevas Comisiones
         GetComisiones(r.P28SESION,r.P04IMPTRA,r.P46TCUOT01,r.P46TCUOT02,r.P48TIPTRA,r.P18CODACT,r.P48TIPMOV);

         -- Actualiza Campos de Comisiones
         UPDATE CLR_MX0105
            SET IMPCU1_P46_ACTC = vP46IMPCU1,
                IMPCU2_P46_ACTC = vP46IMPCU2,
                SIGCU3_P46_ACTC = vP46SIGCU3,
                IMPCU3_P46_ACTC = vP46IMPCU3
          WHERE ID_CLRLOAD = pIDClrLoad
            AND ID_REGISTRO = r.ID_REGISTRO;

         -- Contador
         vCont:=vCont+1;
         IF MOD(vCont,1000) = 0 THEN
            PQMONPROC.InsLog(pIDproc,'M','Registros Procesados: '||LTRIM(RTRIM(TO_CHAR(vCont,'999,999')))||' ...');
         END IF;

     END LOOP;
     PQMONPROC.InsLog(pIDproc,'M','Registros Procesados: '||LTRIM(RTRIM(TO_CHAR(vCont,'999,999'))));
  END IF;

-- CLR_MX0108
  IF pCodArchivo = 'MX0108' THEN
     PQMONPROC.InsLog(pIDproc,'M','Inicio procesando tabla:'||pCodArchivo);
     FOR r IN (SELECT ID_REGISTRO,
                      LONTAR_L02_ACTC P02LONTAR,
                      NUMTAR_P02_ACTC P02NUMTAR,
                      CODPRO_P03_ACTC P03CODPRO,
                      IMPTRA_P04_ACTC P04IMPTRA,
                      TIMLOC_P12_ACTC P12TIMLOC,
                      PUNSER_P22_ACTC P22PUNSER,
                      CODACT_P18_ACTC P18CODACT,
                      CODACT_P26_ACTC P26CODACT,
                      TO_DATE(SESION_P28_ACTC,'RRMMDD') P28SESION,
                      LPAD(NVL(CODSER_P40_ACTC,'0'),3,'0') P40CODSER,
                      LPAD(NVL(TIPCU1_P46_ACTC,0),2,0)||LPAD(NVL(SIGCU1_P46_ACTC,0),1,0)||LPAD(NVL(IMPCU1_P46_ACTC,0),10,0) P46TCUOT01,--8-- IPR 1334 Karina Rojas 16/07/2020
                      LPAD(NVL(TIPCU2_P46_ACTC,0),2,0)||LPAD(NVL(SIGCU2_P46_ACTC,0),1,0)||LPAD(NVL(IMPCU2_P46_ACTC,0),10,0) P46TCUOT02,--8-- IPR 1334 Karina Rojas 16/07/2020
                      LPAD(NVL(TIPCU3_P46_ACTC,0),2,0)||LPAD(NVL(SIGCU3_P46_ACTC,0),1,0)||LPAD(NVL(IMPCU3_P46_ACTC,0),10,0) P46TCUOT03,--8-- IPR 1334 Karina Rojas 16/07/2020
                      LPAD(NVL(TIPCU4_P46_ACTC,0),2,0)||LPAD(NVL(SIGCU4_P46_ACTC,0),1,0)||LPAD(NVL(IMPCU4_P46_ACTC,0),10,0) P46TCUOT04,--8-- IPR 1334 Karina Rojas 16/07/2020
                      TIPMOV_P48_ACTC P48TIPMOV,
                      TIPTRA_P48_ACTC P48TIPTRA,
                      DECODE(SUBSTR(IDEADQ_P32_ACTC,3,4),'0105','BM','0108','BP') COD_ENTADQ,
                      LPAD(vtapla_p48_actc,2,'0')||RPAD(SUBSTR(filler_p48_actc,3),11,' ')||LPAD(mcashb_p48_actc,10,'0')||LPAD(indpre_p48_actc,2,' ')||LPAD(NVL(SUBSTR(numgui_p48_actc,2,3),' '),3,' ') P48FILLER
                 FROM CLR_MX0108
                WHERE ID_CLRLOAD = pIDClrLoad
                  AND INLOTE_P29_ACTC = '316' ) LOOP

         -- Obtiene el IRD
         IF SUBSTR(r.P48TIPTRA,1,2)  = '10' THEN
            vIRD:=gIRDMCM;
         ELSE
            -- vIRD:=SF_GETMCIRD(pIDproc, r.P02NUMTAR,r.COD_ENTADQ,r.P12TIMLOC,r.P22PUNSER,r.P26CODACT);
            --vIRD:=SF_GETMCIRD(pIDproc, r.P02NUMTAR,r.COD_ENTADQ,r.P03CODPRO,r.P12TIMLOC,r.P22PUNSER,r.P26CODACT);
            vIRD:=SF_GETMCIRD(pIDproc, r.P02NUMTAR,r.COD_ENTADQ,r.P02LONTAR,r.P03CODPRO,r.P12TIMLOC,r.P22PUNSER,r.P26CODACT,r.P40CODSER);
         END IF;

         -- Obtiene la Comision del Comercio (Comision Total)
         vComiTot:=GetComiEMI(r.P46TCUOT01,r.P46TCUOT02)+GetComiADQ(r.P46TCUOT03, r.P46TCUOT04, r.P48FILLER);

         -- Obtiene las Nuevas Comisiones
         GetComisiones(r.P28SESION,r.P04IMPTRA,r.P46TCUOT01,r.P46TCUOT02,r.P48TIPTRA,r.P18CODACT,r.P48TIPMOV);

         -- Actualiza Campos de Comisiones
         UPDATE CLR_MX0108
            SET IMPCU1_P46_ACTC = vP46IMPCU1,
                IMPCU2_P46_ACTC = vP46IMPCU2,
                SIGCU3_P46_ACTC = vP46SIGCU3,
                IMPCU3_P46_ACTC = vP46IMPCU3
          WHERE ID_CLRLOAD = pIDClrLoad
            AND ID_REGISTRO = r.ID_REGISTRO;

         -- Contador
         vCont:=vCont+1;
         IF MOD(vCont,1000) = 0 THEN
            PQMONPROC.InsLog(pIDproc,'M','Registros Procesados: '||LTRIM(RTRIM(TO_CHAR(vCont,'999,999')))||' ...');
         END IF;

     END LOOP;
     PQMONPROC.InsLog(pIDproc,'M','Registros Procesados: '||LTRIM(RTRIM(TO_CHAR(vCont,'999,999'))));
  END IF;

  --
  RETURN '0';
EXCEPTION
  WHEN OTHERS THEN
       dbms_output.put_line (sqlerrm);
       vOraCode:=ABS(SQLCODE);
       ROLLBACK;
       PQMONPROC.InsLog(pIDproc,'E','E|Error de Base de Datos (ORA-'||LTRIM(LPAD(vOraCode,5,'0'))||')'||',REG:'||vx_registro||',idload:'||pIDClrLoad||',tabla:'||pCodArchivo);
       RETURN 'E|Error de Base de Datos (ORA-'||LTRIM(LPAD(vOraCode,5,'0'))||')';
END; -- UpdComIntMC


-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
-- FUNCTION UpdCOMINTMC
-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

FUNCTION UpdComIntMC (pFecSesion DATE, pHoraProc CHAR) RETURN CHAR
IS
vRet         VARCHAR2(512);
vRetMon      VARCHAR2(512);
vOraCode     NUMBER:=0;
vIDproc      NUMBER;
BEGIN
  vIDproc:=PQMONPROC.InsMonProc('CLRUPDCOMINTMC');
  PQMONPROC.InsLog(vIDproc,'M','INICIO | Fecha de Sesion: '||TO_CHAR(pFecSesion,'DD/MM/YYYY')||' / Hora de Proceso: '||pHoraProc||':00 hrs.');
  gIRDMCM:=RTRIM(STD.F_GETVALPAR('IRDMCMAESTRO'));
  PQMONPROC.InsLog(vIDproc,'M','IRD MasterCard Maestro: '||gIRDMCM);
  FOR r IN (SELECT COD_ARCHIVO,
                   ID_CLRLOAD
              FROM CTL_CLRLOAD
             WHERE FEC_SESION = pFecSesion
               AND HRA_PROCESO = pHoraProc
               AND EST_PROCESO = 'F'
               AND COD_ARCHIVO IN ('EX8010','EX9010','MX9898','MX9899', 'MX0105', 'MX0108')
             ORDER BY ID_CLRLOAD) LOOP
      vRet:=UpdComIntMCXID(r.COD_ARCHIVO,r.ID_CLRLOAD,vIDproc);
      IF SUBSTR(vRet,1,1) = 'E' THEN
         PQMONPROC.InsLog(vIDproc,'E','FIN ERROR | Fecha de Sesion: '||TO_CHAR(pFecSesion,'DD/MM/YYYY')||' / Hora de Proceso: '||pHoraProc||':00 hrs.');
         vRetMon:=PQMONPROC.UpdMonProc(vIDproc,'E');
         RETURN vRet;
      END IF;
  END LOOP;
  PQMONPROC.InsLog(vIDproc,'M','FIN OK | Fecha de Sesion: '||TO_CHAR(pFecSesion,'DD/MM/YYYY')||' / Hora de Proceso: '||pHoraProc||':00 hrs.');
  vRet:=PQMONPROC.UpdMonProc(vIDproc,'F');
  RETURN '0';
EXCEPTION
  WHEN OTHERS THEN
       vOraCode:=ABS(SQLCODE);
       ROLLBACK;
       PQMONPROC.InsLog(vIDproc,'E','FIN ERROR | Fecha de Sesion: '||TO_CHAR(pFecSesion,'DD/MM/YYYY')||' / Hora de Proceso: '||pHoraProc||':00 hrs.');
       vRet:=PQMONPROC.UpdMonProc(vIDproc,'E');
       RETURN 'E|Error de Base de Datos (ORA-'||LTRIM(LPAD(vOraCode,5,'0'))||')';
END; -- UpdComIntMC

-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
-- FUNCTION UpdNumTarXID
-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

FUNCTION UpdNumTarXID (pFecSesion DATE, pCodArchivo CHAR, pIDClrLoad NUMBER, pIDproc NUMBER) RETURN CHAR
IS

vOraCode    NUMBER:=0;
vCont       NUMBER:=0;
wkNumDia    CHAR:=TO_CHAR(pFecSesion,'DAY','NLS_DATE_LANGUAGE=''numeric date language'''); /* Modificado por TsT 09/11/2020*/

BEGIN
  -- Tabla de Control de Verificacion de Numero de Tarjeta
  PQMONPROC.InsLog(pIDproc,'M','Procesando '||pCodArchivo||'...');
  --PQMONPROC.InsLog(pIDproc,'M','DIA NOMBRADO:'||wkNumDia||', DIA:'||pFecSesion); /* Modificado por TsT 09/11/2020*/

  -- CLR_COPAE0105
  IF pCodArchivo = 'COPAE0105' THEN
     UPDATE CLR_COPAE0105
        SET NUMTAR_P02_ACCP = SEGVNZ.PKG_PCI_DATA_SEG.GETDATCLR(NUMTAR_P02_RAW, pFecSesion)
      WHERE ID_CLRLOAD = pIDClrLoad;
     vCont:=SQL%ROWCOUNT;
     PQMONPROC.InsLog(pIDproc,'M','Registros Procesados: '||LTRIM(RTRIM(TO_CHAR(vCont,'999,999'))));
  END IF;

  -- CLR_COPAE0108
  IF pCodArchivo = 'COPAE0108' THEN
     UPDATE CLR_COPAE0108
        SET NUMTAR_P02_ACCP = SEGVNZ.PKG_PCI_DATA_SEG.GETDATCLR(NUMTAR_P02_RAW, pFecSesion)
      WHERE ID_CLRLOAD = pIDClrLoad;
     vCont:=SQL%ROWCOUNT;
     PQMONPROC.InsLog(pIDproc,'M','Registros Procesados: '||LTRIM(RTRIM(TO_CHAR(vCont,'999,999'))));
  END IF;

  -- CLR_COPAE8001
  IF pCodArchivo = 'COPAE8001' THEN
     UPDATE CLR_COPAE8001
        SET NUMTAR_P02_ACCP = SEGVNZ.PKG_PCI_DATA_SEG.GETDATCLR(NUMTAR_P02_RAW, pFecSesion)
      WHERE ID_CLRLOAD = pIDClrLoad;
     vCont:=SQL%ROWCOUNT;
     PQMONPROC.InsLog(pIDproc,'M','Registros Procesados: '||LTRIM(RTRIM(TO_CHAR(vCont,'999,999'))));
  END IF;

  -- CLR_COPAE8010
  IF pCodArchivo = 'COPAE8010' THEN
     UPDATE CLR_COPAE8010
        SET NUMTAR_P02_ACCP = SEGVNZ.PKG_PCI_DATA_SEG.GETDATCLR(NUMTAR_P02_RAW, pFecSesion)
      WHERE ID_CLRLOAD = pIDClrLoad;
     vCont:=SQL%ROWCOUNT;
     PQMONPROC.InsLog(pIDproc,'M','Registros Procesados: '||LTRIM(RTRIM(TO_CHAR(vCont,'999,999'))));
  END IF;

---------IPR 1302------------INICIO-Fancisco Vasquez 17082020
 -- CLR_COPAE9001
  IF pCodArchivo = 'COPAE9001' THEN
     UPDATE CLR_COPAE9001
        SET NUMTAR_P02_ACCP = SEGVNZ.PKG_PCI_DATA_SEG.GETDATCLR(NUMTAR_P02_RAW, pFecSesion)
      WHERE ID_CLRLOAD = pIDClrLoad;
     vCont:=SQL%ROWCOUNT;
     PQMONPROC.InsLog(pIDproc,'M','Registros Ngta Procesados: '||LTRIM(RTRIM(TO_CHAR(vCont,'999,999'))));
  END IF;

  -- CLR_COPAE9010
  IF pCodArchivo = 'COPAE9010' THEN
     UPDATE CLR_COPAE9010
        SET NUMTAR_P02_ACCP = SEGVNZ.PKG_PCI_DATA_SEG.GETDATCLR(NUMTAR_P02_RAW, pFecSesion)
      WHERE ID_CLRLOAD = pIDClrLoad;
     vCont:=SQL%ROWCOUNT;
     PQMONPROC.InsLog(pIDproc,'M','Registros Ngta Procesados: '||LTRIM(RTRIM(TO_CHAR(vCont,'999,999'))));
  END IF;
---------IPR 1302------------FIN

  -- CLR_COPAE8020
  IF pCodArchivo = 'COPAE8020' THEN
     UPDATE CLR_COPAE8020
        SET NUMTAR_P02_ACCP = SEGVNZ.PKG_PCI_DATA_SEG.GETDATCLR(NUMTAR_P02_RAW, pFecSesion)
      WHERE ID_CLRLOAD = pIDClrLoad;
     vCont:=SQL%ROWCOUNT;
     PQMONPROC.InsLog(pIDproc,'M','Registros Procesados: '||LTRIM(RTRIM(TO_CHAR(vCont,'999,999'))));
  END IF;

  -- CLR_COPAM0105
  IF pCodArchivo = 'COPAM0105' THEN
     UPDATE CLR_COPAM0105
        SET NUMTAR_P02_ACCP = SEGVNZ.PKG_PCI_DATA_SEG.GETDATCLR(NUMTAR_P02_RAW, pFecSesion)
      WHERE ID_CLRLOAD = pIDClrLoad;
     vCont:=SQL%ROWCOUNT;
     PQMONPROC.InsLog(pIDproc,'M','Registros Procesados: '||LTRIM(RTRIM(TO_CHAR(vCont,'999,999'))));
  END IF;

  -- CLR_COPAM0108
  IF pCodArchivo = 'COPAM0108' THEN
     UPDATE CLR_COPAM0108
        SET NUMTAR_P02_ACCP = SEGVNZ.PKG_PCI_DATA_SEG.GETDATCLR(NUMTAR_P02_RAW, pFecSesion)
      WHERE ID_CLRLOAD = pIDClrLoad;
     vCont:=SQL%ROWCOUNT;
     PQMONPROC.InsLog(pIDproc,'M','Registros Procesados: '||LTRIM(RTRIM(TO_CHAR(vCont,'999,999'))));
  END IF;

  -- CLR_EX0105
  IF pCodArchivo = 'EX0105' THEN
     UPDATE CLR_EX0105
        SET NUMTAR_P02_ACTC = SEGVNZ.PKG_PCI_DATA_SEG.GETDATCLR(NUMTAR_P02_RAW, pFecSesion)
      WHERE ID_CLRLOAD = pIDClrLoad;
     vCont:=SQL%ROWCOUNT;
     PQMONPROC.InsLog(pIDproc,'M','Registros Procesados: '||LTRIM(RTRIM(TO_CHAR(vCont,'999,999'))));
  END IF;

  -- CLR_EX0108
  IF pCodArchivo = 'EX0108' THEN
     UPDATE CLR_EX0108
        SET NUMTAR_P02_ACTC = SEGVNZ.PKG_PCI_DATA_SEG.GETDATCLR(NUMTAR_P02_RAW, pFecSesion)
      WHERE ID_CLRLOAD = pIDClrLoad;
     vCont:=SQL%ROWCOUNT;
     PQMONPROC.InsLog(pIDproc,'M','Registros Procesados: '||LTRIM(RTRIM(TO_CHAR(vCont,'999,999'))));
  END IF;

  -- CLR_EX8001
  IF pCodArchivo = 'EX8001' THEN
     UPDATE CLR_EX8001
        SET NUMTAR_P02_ACTC = SEGVNZ.PKG_PCI_DATA_SEG.GETDATCLR(NUMTAR_P02_RAW, pFecSesion)
      WHERE ID_CLRLOAD = pIDClrLoad;
     vCont:=SQL%ROWCOUNT;
     PQMONPROC.InsLog(pIDproc,'M','Registros Procesados: '||LTRIM(RTRIM(TO_CHAR(vCont,'999,999'))));
  END IF;

  -- CLR_EX8010
  IF pCodArchivo = 'EX8010' THEN
     UPDATE CLR_EX8010
        SET NUMTAR_P02_ACTC = SEGVNZ.PKG_PCI_DATA_SEG.GETDATCLR(NUMTAR_P02_RAW, pFecSesion)
      WHERE ID_CLRLOAD = pIDClrLoad;
     vCont:=SQL%ROWCOUNT;
     PQMONPROC.InsLog(pIDproc,'M','Registros Procesados: '||LTRIM(RTRIM(TO_CHAR(vCont,'999,999'))));
  END IF;
---------IPR 1302------------INICIO-Fancisco Vasquez 17082020
-- CLR_EX9001
  IF pCodArchivo = 'EX9001' THEN
     UPDATE CLR_EX9001
        SET NUMTAR_P02_ACTC = SEGVNZ.PKG_PCI_DATA_SEG.GETDATCLR(NUMTAR_P02_RAW, pFecSesion)
      WHERE ID_CLRLOAD = pIDClrLoad;
     vCont:=SQL%ROWCOUNT;
     PQMONPROC.InsLog(pIDproc,'M','Registros Ngta Procesados: '||LTRIM(RTRIM(TO_CHAR(vCont,'999,999'))));
  END IF;

  -- CLR_EX9010
  IF pCodArchivo = 'EX9010' THEN
     UPDATE CLR_EX9010
        SET NUMTAR_P02_ACTC = SEGVNZ.PKG_PCI_DATA_SEG.GETDATCLR(NUMTAR_P02_RAW, pFecSesion)
      WHERE ID_CLRLOAD = pIDClrLoad;
     vCont:=SQL%ROWCOUNT;
     PQMONPROC.InsLog(pIDproc,'M','Registros Ngta Procesados: '||LTRIM(RTRIM(TO_CHAR(vCont,'999,999'))));
  END IF;
---------IPR 1302------------FIN

  -- CLR_EX8020
  IF pCodArchivo = 'EX8020' THEN
     UPDATE CLR_EX8020
        SET NUMTAR_P02_ACTC = SEGVNZ.PKG_PCI_DATA_SEG.GETDATCLR(NUMTAR_P02_RAW, pFecSesion)
      WHERE ID_CLRLOAD = pIDClrLoad;
     vCont:=SQL%ROWCOUNT;
     PQMONPROC.InsLog(pIDproc,'M','Registros Procesados: '||LTRIM(RTRIM(TO_CHAR(vCont,'999,999'))));
  END IF;

  -- CLR_ICOPAM8000
  IF pCodArchivo = 'ICOPAM8000' THEN
     UPDATE CLR_ICOPAM8000
        SET NUMTAR_P02_ACCP = SEGVNZ.PKG_PCI_DATA_SEG.GETDATCLR(NUMTAR_P02_RAW, pFecSesion)
      WHERE ID_CLRLOAD = pIDClrLoad;
     vCont:=SQL%ROWCOUNT;
     PQMONPROC.InsLog(pIDproc,'M','Registros Procesados: '||LTRIM(RTRIM(TO_CHAR(vCont,'999,999'))));
  END IF;

  -- CLR_MX0000
  IF pCodArchivo = 'MX0000' THEN
     UPDATE CLR_MX0000
        SET NUMTAR_P02_ACTC = SEGVNZ.PKG_PCI_DATA_SEG.GETDATCLR(NUMTAR_P02_RAW, pFecSesion)
      WHERE ID_CLRLOAD = pIDClrLoad;
     vCont:=SQL%ROWCOUNT;
     PQMONPROC.InsLog(pIDproc,'M','Registros Procesados: '||LTRIM(RTRIM(TO_CHAR(vCont,'999,999'))));
  END IF;

  -- CLR_MX0105
  IF pCodArchivo = 'MX0105' THEN
     UPDATE CLR_MX0105
        SET NUMTAR_P02_ACTC = SEGVNZ.PKG_PCI_DATA_SEG.GETDATCLR(NUMTAR_P02_RAW, pFecSesion)
      WHERE ID_CLRLOAD = pIDClrLoad;
     vCont:=SQL%ROWCOUNT;
     PQMONPROC.InsLog(pIDproc,'M','Registros Procesados: '||LTRIM(RTRIM(TO_CHAR(vCont,'999,999'))));
  END IF;

  -- CLR_MX0108
  IF pCodArchivo = 'MX0108' THEN
     UPDATE CLR_MX0108
        SET NUMTAR_P02_ACTC = SEGVNZ.PKG_PCI_DATA_SEG.GETDATCLR(NUMTAR_P02_RAW, pFecSesion)
      WHERE ID_CLRLOAD = pIDClrLoad;
     vCont:=SQL%ROWCOUNT;
     PQMONPROC.InsLog(pIDproc,'M','Registros Procesados: '||LTRIM(RTRIM(TO_CHAR(vCont,'999,999'))));
  END IF;

  -- CLR_MX1144
  IF pCodArchivo = 'MX1144' THEN
     UPDATE CLR_MX1144
        SET NUMTAR_P02_ACTC = SEGVNZ.PKG_PCI_DATA_SEG.GETDATCLR(NUMTAR_P02_RAW, pFecSesion)
      WHERE ID_CLRLOAD = pIDClrLoad;
     vCont:=SQL%ROWCOUNT;
     PQMONPROC.InsLog(pIDproc,'M','Registros Procesados: '||LTRIM(RTRIM(TO_CHAR(vCont,'999,999'))));
  END IF;

  -- CLR_MX8000
  IF pCodArchivo = 'MX8000' THEN
     UPDATE CLR_MX8000
        SET NUMTAR_P02_ACTC = SEGVNZ.PKG_PCI_DATA_SEG.GETDATCLR(NUMTAR_P02_RAW, pFecSesion)
      WHERE ID_CLRLOAD = pIDClrLoad;
     vCont:=SQL%ROWCOUNT;
     PQMONPROC.InsLog(pIDproc,'M','Registros Procesados: '||LTRIM(RTRIM(TO_CHAR(vCont,'999,999'))));
  END IF;

  -- CLR_MX8998
  IF pCodArchivo = 'MX8998' THEN
     UPDATE CLR_MX8998
        SET NUMTAR_P02_ACTC = SEGVNZ.PKG_PCI_DATA_SEG.GETDATCLR(NUMTAR_P02_RAW, pFecSesion)
      WHERE ID_CLRLOAD = pIDClrLoad;
     vCont:=SQL%ROWCOUNT;
     PQMONPROC.InsLog(pIDproc,'M','Registros Procesados: '||LTRIM(RTRIM(TO_CHAR(vCont,'999,999'))));
  END IF;

  -- CLR_MX9998
  IF pCodArchivo = 'MX9998' THEN
     UPDATE CLR_MX9998
        SET NUMTAR_P02_ACTC = SEGVNZ.PKG_PCI_DATA_SEG.GETDATCLR(NUMTAR_P02_RAW, pFecSesion)
      WHERE ID_CLRLOAD = pIDClrLoad;
     vCont:=SQL%ROWCOUNT;
     PQMONPROC.InsLog(pIDproc,'M','Registros Procesados: '||LTRIM(RTRIM(TO_CHAR(vCont,'999,999'))));
  END IF;

  -- CLR_MX9999
  IF pCodArchivo = 'MX9999' THEN
     UPDATE CLR_MX9999
        SET NUMTAR_P02_ACTC = SEGVNZ.PKG_PCI_DATA_SEG.GETDATCLR(NUMTAR_P02_RAW, pFecSesion)
      WHERE ID_CLRLOAD = pIDClrLoad;
     vCont:=SQL%ROWCOUNT;
     PQMONPROC.InsLog(pIDproc,'M','Registros Procesados: '||LTRIM(RTRIM(TO_CHAR(vCont,'999,999'))));
  END IF;

  -- CLR_MX9898
  IF pCodArchivo = 'MX9898' THEN
     UPDATE CLR_MX9898
        SET NUMTAR_P02_ACTC = SEGVNZ.PKG_PCI_DATA_SEG.GETDATCLR(NUMTAR_P02_RAW, pFecSesion)
      WHERE ID_CLRLOAD = pIDClrLoad;
     vCont:=SQL%ROWCOUNT;
     PQMONPROC.InsLog(pIDproc,'M','Registros Procesados: '||LTRIM(RTRIM(TO_CHAR(vCont,'999,999'))));
  END IF;

  -- CLR_MX9899
  IF pCodArchivo = 'MX9899' THEN
     UPDATE CLR_MX9899
        SET NUMTAR_P02_ACTC = SEGVNZ.PKG_PCI_DATA_SEG.GETDATCLR(NUMTAR_P02_RAW, pFecSesion)
      WHERE ID_CLRLOAD = pIDClrLoad;
     vCont:=SQL%ROWCOUNT;
     PQMONPROC.InsLog(pIDproc,'M','Registros Procesados: '||LTRIM(RTRIM(TO_CHAR(vCont,'999,999'))));
  END IF;

  -- CLR_MX9798
  IF pCodArchivo = 'MX9798' THEN
     UPDATE CLR_MX9798
        SET NUMTAR_P02_ACTC = SEGVNZ.PKG_PCI_DATA_SEG.GETDATCLR(NUMTAR_P02_RAW, pFecSesion)
      WHERE ID_CLRLOAD = pIDClrLoad;
     vCont:=SQL%ROWCOUNT;
     PQMONPROC.InsLog(pIDproc,'M','Registros Procesados: '||LTRIM(RTRIM(TO_CHAR(vCont,'999,999'))));
  END IF;

  --INICIO IPR 1068
    --FECHA DE CREACION : 26/10/2012
    --AUTOR : EDGAR MENA AZA??????ERO.
    --DESCRIPCION : Permite agregar Diners para BP.

    -- CLR_MX9799
    IF pCodArchivo = 'MX9799' THEN
        FOR r IN (SELECT ID_REGISTRO, NUMTAR_P02_RAW
                    FROM CLR_MX9799
                   WHERE ID_CLRLOAD = pIDClrLoad
                     AND IDEMEN_P00_ACTC IN (1244,1442,1444) )
        LOOP
            UPDATE CLR_MX9799
               SET NUMTAR_P02_ACTC = SEGVNZ.PKG_PCI_DATA_SEG.GETDATCLR(r.NUMTAR_P02_RAW, pFecSesion)
             WHERE ID_CLRLOAD = pIDClrLoad
               AND ID_REGISTRO = r.ID_REGISTRO;
            vCont:=vCont+1;
        END LOOP;
        PQMONPROC.InsLog(pIDproc,'M','Registros Procesados: '||LTRIM(RTRIM(TO_CHAR(vCont,'999,999'))));
    END IF;
    --FIN IPR 1068

  -- CLR_MX8999
  IF pCodArchivo = 'MX8999' THEN
     UPDATE CLR_MX8999
        SET NUMTAR_P02_ACTC = SEGVNZ.PKG_PCI_DATA_SEG.GETDATCLR(NUMTAR_P02_RAW, pFecSesion)
      WHERE ID_CLRLOAD = pIDClrLoad;
     vCont:=SQL%ROWCOUNT;
     PQMONPROC.InsLog(pIDproc,'M','Registros Procesados: '||LTRIM(RTRIM(TO_CHAR(vCont,'999,999'))));
  END IF;

  -- CLR_MX9799
  IF pCodArchivo = 'MX9799' THEN
     UPDATE CLR_MX9799
        SET NUMTAR_P02_ACTC = SEGVNZ.PKG_PCI_DATA_SEG.GETDATCLR(NUMTAR_P02_RAW, pFecSesion)
      WHERE ID_CLRLOAD = pIDClrLoad;
     vCont:=SQL%ROWCOUNT;
     PQMONPROC.InsLog(pIDproc,'M','Registros Procesados: '||LTRIM(RTRIM(TO_CHAR(vCont,'999,999'))));
  END IF;
  --
  COMMIT;
  RETURN '0';
EXCEPTION
  WHEN OTHERS THEN
       vOraCode:=ABS(SQLCODE);
       ROLLBACK;
       PQMONPROC.InsLog(pIDproc,'E','Error de Base de Datos (ORA-'||LTRIM(LPAD(vOraCode,5,'0'))||')');
       RETURN 'E';
END; -- UpdNumTarXID

-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
-- FUNCTION UpdTipDisXID
-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
FUNCTION UpdTipDisXID (pFecSesion DATE, pCodArchivo CHAR, pIDClrLoad NUMBER, pIDproc NUMBER) RETURN CHAR
IS

vOraCode    NUMBER:=0;
vCont       NUMBER:=0;
wkNumDia    CHAR:=TO_CHAR(pFecSesion,'DAY','NLS_DATE_LANGUAGE=''numeric date language'''); /* Modificado por TsT 09/11/2020*/

BEGIN
  -- Tabla de Control de Verificacion de Numero de Tarjeta
  PQMONPROC.InsLog(pIDproc,'M','Procesando '||pCodArchivo||'...');
  --PQMONPROC.InsLog(pIDproc,'M','DIA NOMBRADO:'||wkNumDia||', DIA:'||pFecSesion); /* Modificado por TsT 09/11/2020*/


  -- CLR_MX0000
  IF pCodArchivo = 'MX0000' THEN
     UPDATE CLR_MX0000
        SET TIPDIS_P55_ACTC = (select SUBSTR(emv.FFI_P55_ACTC,5,2) from CLR_DCEMVFULL_IPR1387 emv, CLR_MX0000 clr  
                                       where  clr.IDETRA_P11_ACTC = emv.IDETRA_P11_ACTC 
                                       and CLR.TIMLOC_P12_ACTC = emv.TIMLOC_P12_ACTC and  emv.FEC_SESION = pFecSesion)
        WHERE ID_CLRLOAD = pIDClrLoad;
     vCont:=SQL%ROWCOUNT;
     PQMONPROC.InsLog(pIDproc,'M','Registros Procesados: '||LTRIM(RTRIM(TO_CHAR(vCont,'999,999'))));
  END IF;

  -- CLR_MX0105
  IF pCodArchivo = 'MX0105' THEN
     UPDATE CLR_MX0105
        SET TIPDIS_P55_ACTC = (select SUBSTR(emv.FFI_P55_ACTC,5,2) from CLR_DCEMVFULL_IPR1387 emv, CLR_MX0105 clr  
                                       where  clr.IDETRA_P11_ACTC = emv.IDETRA_P11_ACTC 
                                       and CLR.TIMLOC_P12_ACTC = emv.TIMLOC_P12_ACTC and emv.FEC_SESION = pFecSesion)
        WHERE ID_CLRLOAD = pIDClrLoad;
     vCont:=SQL%ROWCOUNT;
     PQMONPROC.InsLog(pIDproc,'M','Registros Procesados: '||LTRIM(RTRIM(TO_CHAR(vCont,'999,999'))));
  END IF;

  -- CLR_MX0108
  IF pCodArchivo = 'MX0108' THEN
     UPDATE CLR_MX0108
        SET TIPDIS_P55_ACTC = (select SUBSTR(emv.FFI_P55_ACTC,5,2) from CLR_DCEMVFULL_IPR1387 emv, CLR_MX0108 clr  
                                       where  clr.IDETRA_P11_ACTC = emv.IDETRA_P11_ACTC 
                                       and CLR.TIMLOC_P12_ACTC = emv.TIMLOC_P12_ACTC and emv.FEC_SESION = pFecSesion)
        WHERE ID_CLRLOAD = pIDClrLoad;
     vCont:=SQL%ROWCOUNT;
     PQMONPROC.InsLog(pIDproc,'M','Registros Procesados: '||LTRIM(RTRIM(TO_CHAR(vCont,'999,999'))));
  END IF;

  -- CLR_MX1144
  IF pCodArchivo = 'MX1144' THEN
     UPDATE CLR_MX1144
        SET TIPDIS_P55_ACTC = (select SUBSTR(emv.FFI_P55_ACTC,5,2) from CLR_DCEMVFULL_IPR1387 emv, CLR_MX1144 clr  
                                       where  clr.IDETRA_P11_ACTC = emv.IDETRA_P11_ACTC 
                                       and CLR.TIMLOC_P12_ACTC = emv.TIMLOC_P12_ACTC and emv.FEC_SESION = pFecSesion)
        WHERE ID_CLRLOAD = pIDClrLoad;
     vCont:=SQL%ROWCOUNT;
     PQMONPROC.InsLog(pIDproc,'M','Registros Procesados: '||LTRIM(RTRIM(TO_CHAR(vCont,'999,999'))));
  END IF;

  -- CLR_MX8000
  IF pCodArchivo = 'MX8000' THEN
     UPDATE CLR_MX8000
        SET TIPDIS_P55_ACTC = (select SUBSTR(emv.FFI_P55_ACTC,5,2) from CLR_DCEMVFULL_IPR1387 emv, CLR_MX8000 clr  
                                       where  clr.IDETRA_P11_ACTC = emv.IDETRA_P11_ACTC 
                                       and CLR.TIMLOC_P12_ACTC = emv.TIMLOC_P12_ACTC and emv.FEC_SESION = pFecSesion)
        WHERE ID_CLRLOAD = pIDClrLoad;
     vCont:=SQL%ROWCOUNT;
     PQMONPROC.InsLog(pIDproc,'M','Registros Procesados: '||LTRIM(RTRIM(TO_CHAR(vCont,'999,999'))));
  END IF;

  -- CLR_MX8998
  IF pCodArchivo = 'MX8998' THEN
     UPDATE CLR_MX8998
        SET TIPDIS_P55_ACTC = (select SUBSTR(emv.FFI_P55_ACTC,5,2) from CLR_DCEMVFULL_IPR1387 emv, CLR_MX8998 clr  
                                       where  clr.IDETRA_P11_ACTC = emv.IDETRA_P11_ACTC 
                                       and CLR.TIMLOC_P12_ACTC = emv.TIMLOC_P12_ACTC and emv.FEC_SESION = pFecSesion)
        WHERE ID_CLRLOAD = pIDClrLoad;
     vCont:=SQL%ROWCOUNT;
     PQMONPROC.InsLog(pIDproc,'M','Registros Procesados: '||LTRIM(RTRIM(TO_CHAR(vCont,'999,999'))));
  END IF;

  -- CLR_MX9998
  IF pCodArchivo = 'MX9998' THEN
     UPDATE CLR_MX9998
        SET TIPDIS_P55_ACTC = (select SUBSTR(emv.FFI_P55_ACTC,5,2) from CLR_DCEMVFULL_IPR1387 emv, CLR_MX9998 clr  
                                       where  clr.IDETRA_P11_ACTC = emv.IDETRA_P11_ACTC 
                                       and CLR.TIMLOC_P12_ACTC = emv.TIMLOC_P12_ACTC and emv.FEC_SESION = pFecSesion)
        WHERE ID_CLRLOAD = pIDClrLoad;
     vCont:=SQL%ROWCOUNT;
     PQMONPROC.InsLog(pIDproc,'M','Registros Procesados: '||LTRIM(RTRIM(TO_CHAR(vCont,'999,999'))));
  END IF;

  -- CLR_MX9999
  IF pCodArchivo = 'MX9999' THEN
     UPDATE CLR_MX9999
        SET TIPDIS_P55_ACTC = (select SUBSTR(emv.FFI_P55_ACTC,5,2) from CLR_DCEMVFULL_IPR1387 emv, CLR_MX9999 clr  
                                       where  clr.IDETRA_P11_ACTC = emv.IDETRA_P11_ACTC 
                                       and CLR.TIMLOC_P12_ACTC = emv.TIMLOC_P12_ACTC and emv.FEC_SESION = pFecSesion)
        WHERE ID_CLRLOAD = pIDClrLoad;
     vCont:=SQL%ROWCOUNT;
     PQMONPROC.InsLog(pIDproc,'M','Registros Procesados: '||LTRIM(RTRIM(TO_CHAR(vCont,'999,999'))));
  END IF;

  -- CLR_MX9898
  IF pCodArchivo = 'MX9898' THEN
     UPDATE CLR_MX9898
        SET TIPDIS_P55_ACTC = (select SUBSTR(emv.FFI_P55_ACTC,5,2) from CLR_DCEMVFULL_IPR1387 emv, CLR_MX9898 clr  
                                       where  clr.IDETRA_P11_ACTC = emv.IDETRA_P11_ACTC 
                                       and CLR.TIMLOC_P12_ACTC = emv.TIMLOC_P12_ACTC and emv.FEC_SESION = pFecSesion)
        WHERE ID_CLRLOAD = pIDClrLoad;
     vCont:=SQL%ROWCOUNT;
     PQMONPROC.InsLog(pIDproc,'M','Registros Procesados: '||LTRIM(RTRIM(TO_CHAR(vCont,'999,999'))));
  END IF;

  -- CLR_MX9899
  IF pCodArchivo = 'MX9899' THEN
     UPDATE CLR_MX9899
        SET TIPDIS_P55_ACTC = (select SUBSTR(emv.FFI_P55_ACTC,5,2) from CLR_DCEMVFULL_IPR1387 emv, CLR_MX9899 clr  
                                       where  clr.IDETRA_P11_ACTC = emv.IDETRA_P11_ACTC 
                                       and CLR.TIMLOC_P12_ACTC = emv.TIMLOC_P12_ACTC and emv.FEC_SESION = pFecSesion)
        WHERE ID_CLRLOAD = pIDClrLoad;
     vCont:=SQL%ROWCOUNT;
     PQMONPROC.InsLog(pIDproc,'M','Registros Procesados: '||LTRIM(RTRIM(TO_CHAR(vCont,'999,999'))));
  END IF;

  -- CLR_MX9798
  IF pCodArchivo = 'MX9798' THEN
     UPDATE CLR_MX9798
        SET TIPDIS_P55_ACTC = (select SUBSTR(emv.FFI_P55_ACTC,5,2) from CLR_DCEMVFULL_IPR1387 emv, CLR_MX9798 clr  
                                       where  clr.IDETRA_P11_ACTC = emv.IDETRA_P11_ACTC 
                                       and CLR.TIMLOC_P12_ACTC = emv.TIMLOC_P12_ACTC and emv.FEC_SESION = pFecSesion)
        WHERE ID_CLRLOAD = pIDClrLoad;
     vCont:=SQL%ROWCOUNT;
     PQMONPROC.InsLog(pIDproc,'M','Registros Procesados: '||LTRIM(RTRIM(TO_CHAR(vCont,'999,999'))));
  END IF;


    -- CLR_MX9799
  IF pCodArchivo = 'MX9799' THEN
     UPDATE CLR_MX9799
        SET TIPDIS_P55_ACTC = (select SUBSTR(emv.FFI_P55_ACTC,5,2) from CLR_DCEMVFULL_IPR1387 emv, CLR_MX9799 clr  
                                       where  clr.IDETRA_P11_ACTC = emv.IDETRA_P11_ACTC 
                                       and CLR.TIMLOC_P12_ACTC = emv.TIMLOC_P12_ACTC and emv.FEC_SESION = pFecSesion)
        WHERE ID_CLRLOAD = pIDClrLoad;
     vCont:=SQL%ROWCOUNT;
     PQMONPROC.InsLog(pIDproc,'M','Registros Procesados: '||LTRIM(RTRIM(TO_CHAR(vCont,'999,999'))));
  END IF;


  -- CLR_MX8999
 IF pCodArchivo = 'MX8999' THEN
     UPDATE CLR_MX8999
        SET TIPDIS_P55_ACTC = (select SUBSTR(emv.FFI_P55_ACTC,5,2) from CLR_DCEMVFULL_IPR1387 emv, CLR_MX8999 clr  
                                       where  clr.IDETRA_P11_ACTC = emv.IDETRA_P11_ACTC 
                                       and CLR.TIMLOC_P12_ACTC = emv.TIMLOC_P12_ACTC and emv.FEC_SESION = pFecSesion)
        WHERE ID_CLRLOAD = pIDClrLoad;
     vCont:=SQL%ROWCOUNT;
     PQMONPROC.InsLog(pIDproc,'M','Registros Procesados: '||LTRIM(RTRIM(TO_CHAR(vCont,'999,999'))));
  END IF;
  --
  COMMIT;
  RETURN '0';
EXCEPTION
  WHEN OTHERS THEN
       vOraCode:=ABS(SQLCODE);
       ROLLBACK;
       PQMONPROC.InsLog(pIDproc,'E','Error de Base de Datos (ORA-'||LTRIM(LPAD(vOraCode,5,'0'))||')');
       RETURN 'E';
END; -- UpdTipDisXID



-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
-- FUNCTION UpdNumTar
-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

FUNCTION UpdNumTar (pFecSesion DATE, pHoraProc CHAR) RETURN CHAR
IS
vRet         VARCHAR2(512);
vOraCode     NUMBER:=0;
vIDproc      NUMBER;
BEGIN
  gNumERR := 0;
  vIDproc:=PQMONPROC.InsMonProc('CLRUPDNUMTAR');
  PQMONPROC.InsLog(vIDproc,'M','INICIO | Fecha de Sesion: '||TO_CHAR(pFecSesion,'DD/MM/YYYY')||' / Hora de Proceso: '||pHoraProc||':00 hrs.');
  FOR r IN (SELECT COD_ARCHIVO,
                   ID_CLRLOAD
              FROM CTL_CLRLOAD
             WHERE FEC_SESION = pFecSesion
               AND HRA_PROCESO = pHoraProc
               AND EST_PROCESO = 'F'
               AND COD_ARCHIVO IN ('COPAE0105', 'COPAE0108', 'COPAE8001', 'COPAE8010', 'COPAE9001', 'COPAE9010', 'COPAE8020', 'COPAM0105', 'COPAM0108', 'EX0105', 'EX0108',
                                   'EX8001', 'EX8010', 'EX8020', 'ICOPAM8000', 'MX0000', 'MX0105', 'MX0108', 'MX1144', 'MX8000', 'MX8998', 'MX8999',
                                   'MX9798', 'MX9898', 'MX9899', 'MX9998', 'MX9999', 'MX9799', 'EX9001', 'EX9010')
             ORDER BY ID_CLRLOAD) LOOP
      vRet:=UpdNumTarXID(pFecSesion, r.COD_ARCHIVO,r.ID_CLRLOAD,vIDproc);
      IF vRet = 'E' THEN
         gNumERR:=gNumERR+1;
         PQMONPROC.InsLog(vIDproc,'E','Error en la ejecuci?????????n de UpdNumTarXID');
      END IF;
  END LOOP;
  IF gNumERR = 0 THEN
     PQMONPROC.InsLog(vIDproc,'M','FIN OK | Fecha de Sesion: '||TO_CHAR(pFecSesion,'DD/MM/YYYY')||' / Hora de Proceso: '||pHoraProc||':00 hrs.');
     vRet:=PQMONPROC.UpdMonProc(vIDproc,'F');
     RETURN '0';
  ELSE
     PQMONPROC.InsLog(vIDproc,'M','FIN ERROR | Fecha de Sesion: '||TO_CHAR(pFecSesion,'DD/MM/YYYY')||' / Hora de Proceso: '||pHoraProc||':00 hrs.');
     vRet:=PQMONPROC.UpdMonProc(vIDproc,'E');
     RETURN 'E|ERROR en Actualizacion de Numero de Tarjeta. Revisar Monitor de Procesos.~';
  END IF;
EXCEPTION
  WHEN OTHERS THEN
       vOraCode:=ABS(SQLCODE);
       ROLLBACK;
       PQMONPROC.InsLog(vIDproc,'M','FIN ERROR | Fecha de Sesion: '||TO_CHAR(pFecSesion,'DD/MM/YYYY')||' / Hora de Proceso: '||pHoraProc||':00 hrs.');
       vRet:=PQMONPROC.UpdMonProc(vIDproc,'E');
       RETURN 'E|ERROR de Base de Datos (ORA-'||LTRIM(LPAD(vOraCode,5,'0'))||')~';
END; -- UpdNumTar

-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
-- FUNCTION UpdTipDis  --Tipo de Dispositivo - IPR 1387 FJVG 12/2022
-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

FUNCTION UpdTipDis (pFecSesion DATE, pHoraProc CHAR) RETURN CHAR
IS
vRet         VARCHAR2(512);
vOraCode     NUMBER:=0;
vIDproc      NUMBER;
BEGIN
  gNumERR := 0;
  vIDproc:=PQMONPROC.InsMonProc('CLRUPDTIPDIS');
  PQMONPROC.InsLog(vIDproc,'M','INICIO | Fecha de Sesion: '||TO_CHAR(pFecSesion,'DD/MM/YYYY')||' / Hora de Proceso: '||pHoraProc||':00 hrs.');
  FOR r IN (SELECT COD_ARCHIVO,
                   ID_CLRLOAD
              FROM CTL_CLRLOAD
             WHERE FEC_SESION = pFecSesion
               AND HRA_PROCESO = pHoraProc
               AND EST_PROCESO = 'F'
               AND COD_ARCHIVO IN ('MX0000', 'MX0105', 'MX0108', 'MX1144', 'MX8000', 'MX8998', 'MX8999',
                                   'MX9798', 'MX9898', 'MX9899', 'MX9998', 'MX9999', 'MX9799')
             ORDER BY ID_CLRLOAD) LOOP
      vRet:=UpdTipDisXID(pFecSesion, r.COD_ARCHIVO,r.ID_CLRLOAD,vIDproc);
      IF vRet = 'E' THEN
         gNumERR:=gNumERR+1;
         PQMONPROC.InsLog(vIDproc,'E','Error en la ejecucin de UpdTipDisXID');
      END IF;
  END LOOP;
  IF gNumERR = 0 THEN
     PQMONPROC.InsLog(vIDproc,'M','FIN OK | Fecha de Sesion: '||TO_CHAR(pFecSesion,'DD/MM/YYYY')||' / Hora de Proceso: '||pHoraProc||':00 hrs.');
     vRet:=PQMONPROC.UpdMonProc(vIDproc,'F');
     RETURN '0';
  ELSE
     PQMONPROC.InsLog(vIDproc,'M','FIN ERROR | Fecha de Sesion: '||TO_CHAR(pFecSesion,'DD/MM/YYYY')||' / Hora de Proceso: '||pHoraProc||':00 hrs.');
     vRet:=PQMONPROC.UpdMonProc(vIDproc,'E');
     RETURN 'E|ERROR en Actualizacion de Tipo De Dispositivo. Revisar Monitor de Procesos.~';
  END IF;
EXCEPTION
  WHEN OTHERS THEN
       vOraCode:=ABS(SQLCODE);
       ROLLBACK;
       PQMONPROC.InsLog(vIDproc,'M','FIN ERROR | Fecha de Sesion: '||TO_CHAR(pFecSesion,'DD/MM/YYYY')||' / Hora de Proceso: '||pHoraProc||':00 hrs.');
       vRet:=PQMONPROC.UpdMonProc(vIDproc,'E');
       RETURN 'E|ERROR de Base de Datos (ORA-'||LTRIM(LPAD(vOraCode,5,'0'))||')~';
END; -- UpdNumTar

-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
-- FUNCTION UpdImpProvXID
-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

FUNCTION UpdImpProvXID (pFecSesion DATE, pCodArchivo CHAR, pIDClrLoad NUMBER, pIDproc NUMBER) RETURN CHAR
IS

vOraCode    NUMBER:=0;
vCont       NUMBER:=0;

BEGIN
  -- Tabla de Control de Verificacion de Importe de Provimilla
  PQMONPROC.InsLog(pIDproc,'M','Procesando '||pCodArchivo||'...');

  -- CLR_MX8998
  IF pCodArchivo = 'MX8998' THEN
     FOR r IN (SELECT ID_REGISTRO
                 FROM CLR_MX8998
                WHERE ID_CLRLOAD = pIDClrLoad
                  AND IDEMEN_P00_ACTC IN (1244,1442,1444)
                  AND INDPRE_P48_ACTC = '04'
                  AND SUBSTR(FILLER_P48_ACTC,11,1) = '2') LOOP
         UPDATE CLR_MX8998
            SET IMPTRA_P04_ACTC = IMPTRA_P04_ACTC*NVL(TO_NUMBER(TRIM(SUBSTR(NUMGUI_P48_ACTC,2,3)))/100,0)
          WHERE ID_CLRLOAD = pIDClrLoad
            AND ID_REGISTRO = r.ID_REGISTRO;
         vCont:=vCont+1;
         IF MOD(vCont,1000) = 0 THEN
            PQMONPROC.InsLog(pIDproc,'M','Registros Procesados: '||LTRIM(RTRIM(TO_CHAR(vCont,'999,999')))||' ...');
         END IF;
     END LOOP;
     PQMONPROC.InsLog(pIDproc,'M','Registros Procesados: '||LTRIM(RTRIM(TO_CHAR(vCont,'999,999'))));
  END IF;

  -- CLR_MX9998
  IF pCodArchivo = 'MX9998' THEN
     FOR r IN (SELECT ID_REGISTRO
                 FROM CLR_MX9998
                WHERE ID_CLRLOAD = pIDClrLoad
                  AND IDEMEN_P00_ACTC IN (1244,1442,1444)
                  AND INDPRE_P48_ACTC = '04'
                  AND SUBSTR(FILLER_P48_ACTC,11,1) = '2') LOOP
         UPDATE CLR_MX9998
            SET IMPTRA_P04_ACTC = IMPTRA_P04_ACTC*NVL(TO_NUMBER(TRIM(SUBSTR(NUMGUI_P48_ACTC,2,3)))/100,0)
          WHERE ID_CLRLOAD = pIDClrLoad
            AND ID_REGISTRO = r.ID_REGISTRO;
         vCont:=vCont+1;
         IF MOD(vCont,1000) = 0 THEN
            PQMONPROC.InsLog(pIDproc,'M','Registros Procesados: '||LTRIM(RTRIM(TO_CHAR(vCont,'999,999')))||' ...');
         END IF;
     END LOOP;
     PQMONPROC.InsLog(pIDproc,'M','Registros Procesados: '||LTRIM(RTRIM(TO_CHAR(vCont,'999,999'))));
  END IF;

  -- CLR_MX9999
  IF pCodArchivo = 'MX9999' THEN
     FOR r IN (SELECT ID_REGISTRO
                 FROM CLR_MX9999
                WHERE ID_CLRLOAD = pIDClrLoad
                  AND IDEMEN_P00_ACTC IN (1244,1442,1444)
                  AND INDPRE_P48_ACTC = '04'
                  AND SUBSTR(FILLER_P48_ACTC,11,1) = '2') LOOP
         UPDATE CLR_MX9999
            SET IMPTRA_P04_ACTC = IMPTRA_P04_ACTC*NVL(TO_NUMBER(TRIM(SUBSTR(NUMGUI_P48_ACTC,2,3)))/100,0)
          WHERE ID_CLRLOAD = pIDClrLoad
            AND ID_REGISTRO = r.ID_REGISTRO;
         vCont:=vCont+1;
         IF MOD(vCont,1000) = 0 THEN
            PQMONPROC.InsLog(pIDproc,'M','Registros Procesados: '||LTRIM(RTRIM(TO_CHAR(vCont,'999,999')))||' ...');
         END IF;
     END LOOP;
     PQMONPROC.InsLog(pIDproc,'M','Registros Procesados: '||LTRIM(RTRIM(TO_CHAR(vCont,'999,999'))));
  END IF;

  -- CLR_MX9898
  IF pCodArchivo = 'MX9898' THEN
     FOR r IN (SELECT ID_REGISTRO
                 FROM CLR_MX9898
                WHERE ID_CLRLOAD = pIDClrLoad
                  AND IDEMEN_P00_ACTC IN (1244,1442,1444)
                  AND INDPRE_P48_ACTC = '04'
                  AND SUBSTR(FILLER_P48_ACTC,11,1) = '2') LOOP
         UPDATE CLR_MX9898
            SET IMPTRA_P04_ACTC = IMPTRA_P04_ACTC*NVL(TO_NUMBER(TRIM(SUBSTR(NUMGUI_P48_ACTC,2,3)))/100,0)
          WHERE ID_CLRLOAD = pIDClrLoad
            AND ID_REGISTRO = r.ID_REGISTRO;
         vCont:=vCont+1;
         IF MOD(vCont,1000) = 0 THEN
            PQMONPROC.InsLog(pIDproc,'M','Registros Procesados: '||LTRIM(RTRIM(TO_CHAR(vCont,'999,999')))||' ...');
         END IF;
     END LOOP;
     PQMONPROC.InsLog(pIDproc,'M','Registros Procesados: '||LTRIM(RTRIM(TO_CHAR(vCont,'999,999'))));
  END IF;

  -- CLR_MX9899
  IF pCodArchivo = 'MX9899' THEN
     FOR r IN (SELECT ID_REGISTRO
                 FROM CLR_MX9899
                WHERE ID_CLRLOAD = pIDClrLoad
                  AND IDEMEN_P00_ACTC IN (1244,1442,1444)
                  AND INDPRE_P48_ACTC = '04'
                  AND SUBSTR(FILLER_P48_ACTC,11,1) = '2') LOOP
         UPDATE CLR_MX9899
            SET IMPTRA_P04_ACTC = IMPTRA_P04_ACTC*NVL(TO_NUMBER(TRIM(SUBSTR(NUMGUI_P48_ACTC,2,3)))/100,0)
          WHERE ID_CLRLOAD = pIDClrLoad
            AND ID_REGISTRO = r.ID_REGISTRO;
         vCont:=vCont+1;
         IF MOD(vCont,1000) = 0 THEN
            PQMONPROC.InsLog(pIDproc,'M','Registros Procesados: '||LTRIM(RTRIM(TO_CHAR(vCont,'999,999')))||' ...');
         END IF;
     END LOOP;
     PQMONPROC.InsLog(pIDproc,'M','Registros Procesados: '||LTRIM(RTRIM(TO_CHAR(vCont,'999,999'))));
  END IF;

  -- CLR_MX9798
  IF pCodArchivo = 'MX9798' THEN
     FOR r IN (SELECT ID_REGISTRO
                 FROM CLR_MX9798
                WHERE ID_CLRLOAD = pIDClrLoad
                  AND IDEMEN_P00_ACTC IN (1244,1442,1444)
                  AND INDPRE_P48_ACTC = '04'
                  AND SUBSTR(FILLER_P48_ACTC,11,1) = '2') LOOP
         UPDATE CLR_MX9798
            SET IMPTRA_P04_ACTC = IMPTRA_P04_ACTC*NVL(TO_NUMBER(TRIM(SUBSTR(NUMGUI_P48_ACTC,2,3)))/100,0)
          WHERE ID_CLRLOAD = pIDClrLoad
            AND ID_REGISTRO = r.ID_REGISTRO;
         vCont:=vCont+1;
         IF MOD(vCont,1000) = 0 THEN
            PQMONPROC.InsLog(pIDproc,'M','Registros Procesados: '||LTRIM(RTRIM(TO_CHAR(vCont,'999,999')))||' ...');
         END IF;
     END LOOP;
     PQMONPROC.InsLog(pIDproc,'M','Registros Procesados: '||LTRIM(RTRIM(TO_CHAR(vCont,'999,999'))));
  END IF;

    --INICIO IPR 1068
    --FECHA DE CREACION : 26/10/2012
    --AUTOR : EDGAR MENA AZA??????ERO.
    --DESCRIPCION : Permite agregar Diners para BP.

    -- CLR_MX9799
    IF pCodArchivo = 'MX9799' THEN
        FOR r IN (SELECT ID_REGISTRO
                    FROM CLR_MX9799
                   WHERE ID_CLRLOAD = pIDClrLoad
                     AND IDEMEN_P00_ACTC IN (1244,1442,1444)
                     AND INDPRE_P48_ACTC = '04'
                     AND SUBSTR(FILLER_P48_ACTC,11,1) = '2')
        LOOP
            UPDATE CLR_MX9799
               SET IMPTRA_P04_ACTC = IMPTRA_P04_ACTC*NVL(TO_NUMBER(TRIM(SUBSTR(NUMGUI_P48_ACTC,2,3)))/100,0)
             WHERE ID_CLRLOAD = pIDClrLoad
               AND ID_REGISTRO = r.ID_REGISTRO;
            vCont:=vCont+1;
        END LOOP;
        PQMONPROC.InsLog(pIDproc,'M','Registros Procesados: '||LTRIM(RTRIM(TO_CHAR(vCont,'999,999'))));
    END IF;
    --FIN IPR 1068


  -- CLR_MX8999
  IF pCodArchivo = 'MX8999' THEN
     FOR r IN (SELECT ID_REGISTRO
                 FROM CLR_MX8999
                WHERE ID_CLRLOAD = pIDClrLoad
                  AND IDEMEN_P00_ACTC IN (1244,1442,1444)
                  AND INDPRE_P48_ACTC = '04'
                  AND SUBSTR(FILLER_P48_ACTC,11,1) = '2') LOOP
         UPDATE CLR_MX8999
            SET IMPTRA_P04_ACTC = IMPTRA_P04_ACTC*NVL(TO_NUMBER(TRIM(SUBSTR(NUMGUI_P48_ACTC,2,3)))/100,0)
          WHERE ID_CLRLOAD = pIDClrLoad
            AND ID_REGISTRO = r.ID_REGISTRO;
         vCont:=vCont+1;
         IF MOD(vCont,1000) = 0 THEN
            PQMONPROC.InsLog(pIDproc,'M','Registros Procesados: '||LTRIM(RTRIM(TO_CHAR(vCont,'999,999')))||' ...');
         END IF;
     END LOOP;
     PQMONPROC.InsLog(pIDproc,'M','Registros Procesados: '||LTRIM(RTRIM(TO_CHAR(vCont,'999,999'))));
  END IF;

  -- CLR_EX0108
  IF pCodArchivo = 'EX0108' THEN
     FOR r IN (SELECT ID_REGISTRO
                 FROM CLR_EX0108
                WHERE ID_CLRLOAD = pIDClrLoad
                  AND IDEMEN_P00_ACTC IN (1240,1442,1440)
                  AND INDPRE_P48_ACTC = '04'
                  AND SUBSTR(FILLER_P48_ACTC,11,1) = '2') LOOP
         UPDATE CLR_EX0108
            SET IMPTRA_P04_ACTC = IMPTRA_P04_ACTC*NVL(TO_NUMBER(TRIM(SUBSTR(NUMGUI_P48_ACTC,2,3)))/100,0)
          WHERE ID_CLRLOAD = pIDClrLoad
            AND ID_REGISTRO = r.ID_REGISTRO;
         vCont:=vCont+1;
         IF MOD(vCont,1000) = 0 THEN
            PQMONPROC.InsLog(pIDproc,'M','Registros Procesados: '||LTRIM(RTRIM(TO_CHAR(vCont,'999,999')))||' ...');
         END IF;
     END LOOP;
     PQMONPROC.InsLog(pIDproc,'M','Registros Procesados: '||LTRIM(RTRIM(TO_CHAR(vCont,'999,999'))));
  END IF;

  -- CLR_EX0105
  IF pCodArchivo = 'EX0105' THEN
     FOR r IN (SELECT ID_REGISTRO
                 FROM CLR_EX0105
                WHERE ID_CLRLOAD = pIDClrLoad
                  AND IDEMEN_P00_ACTC IN (1240,1442,1440)
                  AND INDPRE_P48_ACTC = '04'
                  AND SUBSTR(FILLER_P48_ACTC,11,1) = '2') LOOP
         UPDATE CLR_EX0105
            SET IMPTRA_P04_ACTC = IMPTRA_P04_ACTC*NVL(TO_NUMBER(TRIM(SUBSTR(NUMGUI_P48_ACTC,2,3)))/100,0)
          WHERE ID_CLRLOAD = pIDClrLoad
            AND ID_REGISTRO = r.ID_REGISTRO;
         vCont:=vCont+1;
         IF MOD(vCont,1000) = 0 THEN
            PQMONPROC.InsLog(pIDproc,'M','Registros Procesados: '||LTRIM(RTRIM(TO_CHAR(vCont,'999,999')))||' ...');
         END IF;
     END LOOP;
     PQMONPROC.InsLog(pIDproc,'M','Registros Procesados: '||LTRIM(RTRIM(TO_CHAR(vCont,'999,999'))));
  END IF;

  -- CLR_EX8001
  IF pCodArchivo = 'EX8001' THEN
     FOR r IN (SELECT ID_REGISTRO
                 FROM CLR_EX8001
                WHERE ID_CLRLOAD = pIDClrLoad
                  AND IDEMEN_P00_ACTC IN (1240,1442,1440)
                  AND INDPRE_P48_ACTC = '04'
                  AND SUBSTR(FILLER_P48_ACTC,11,1) = '2') LOOP
         UPDATE CLR_EX8001
            SET IMPTRA_P04_ACTC = IMPTRA_P04_ACTC*NVL(TO_NUMBER(TRIM(SUBSTR(NUMGUI_P48_ACTC,2,3)))/100,0)
          WHERE ID_CLRLOAD = pIDClrLoad
            AND ID_REGISTRO = r.ID_REGISTRO;
         vCont:=vCont+1;
         IF MOD(vCont,1000) = 0 THEN
            PQMONPROC.InsLog(pIDproc,'M','Registros Procesados: '||LTRIM(RTRIM(TO_CHAR(vCont,'999,999')))||' ...');
         END IF;
     END LOOP;
     PQMONPROC.InsLog(pIDproc,'M','Registros Procesados: '||LTRIM(RTRIM(TO_CHAR(vCont,'999,999'))));
  END IF;

  -- CLR_EX8010
  IF pCodArchivo = 'EX8010' THEN
     FOR r IN (SELECT ID_REGISTRO
                 FROM CLR_EX8010
                WHERE ID_CLRLOAD = pIDClrLoad
                  AND IDEMEN_P00_ACTC IN (1240,1442,1440)
                  AND INDPRE_P48_ACTC = '04'
                  AND SUBSTR(FILLER_P48_ACTC,11,1) = '2') LOOP
         UPDATE CLR_EX8010
            SET IMPTRA_P04_ACTC = IMPTRA_P04_ACTC*NVL(TO_NUMBER(TRIM(SUBSTR(NUMGUI_P48_ACTC,2,3)))/100,0)
          WHERE ID_CLRLOAD = pIDClrLoad
            AND ID_REGISTRO = r.ID_REGISTRO;
         vCont:=vCont+1;
         IF MOD(vCont,1000) = 0 THEN
            PQMONPROC.InsLog(pIDproc,'M','Registros Procesados: '||LTRIM(RTRIM(TO_CHAR(vCont,'999,999')))||' ...');
         END IF;
     END LOOP;
     PQMONPROC.InsLog(pIDproc,'M','Registros Procesados: '||LTRIM(RTRIM(TO_CHAR(vCont,'999,999'))));
  END IF;
  --
  RETURN '0';
EXCEPTION
  WHEN OTHERS THEN
       vOraCode:=ABS(SQLCODE);
       ROLLBACK;
       PQMONPROC.InsLog(pIDproc,'E','Error de Base de Datos (ORA-'||LTRIM(LPAD(vOraCode,5,'0'))||')');
       RETURN 'E';
END; -- UpdImpProvXID

-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
-- FUNCTION UpdImpProv
-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

FUNCTION UpdImpProv (pFecSesion DATE, pHoraProc CHAR) RETURN CHAR
IS
vRet         VARCHAR2(512);
vOraCode     NUMBER:=0;
vIDproc      NUMBER;
BEGIN
  gNumERR := 0;
  vIDproc:=PQMONPROC.InsMonProc('CLRUPDIMPPROV');
  PQMONPROC.InsLog(vIDproc,'M','INICIO | Fecha de Sesion: '||TO_CHAR(pFecSesion,'DD/MM/YYYY')||' / Hora de Proceso: '||pHoraProc||':00 hrs.');
  FOR r IN (SELECT COD_ARCHIVO,
                   ID_CLRLOAD
              FROM CTL_CLRLOAD
             WHERE FEC_SESION = pFecSesion
               AND HRA_PROCESO = pHoraProc
               AND EST_PROCESO = 'F'
               AND COD_ARCHIVO IN ('MX9998','MX9999','MX9898','MX9899','MX9798','MX9799','MX8998','MX8999','EX0108','EX0105','EX8001','EX8010','EX9001','EX9010')
             ORDER BY ID_CLRLOAD) LOOP
      vRet:=UpdImpProvXID(pFecSesion, r.COD_ARCHIVO,r.ID_CLRLOAD,vIDproc);
      IF vRet = 'E' THEN
         gNumERR:=gNumERR+1;
         PQMONPROC.InsLog(vIDproc,'E','Error en la ejecuci??????n de UpdImpProvXID');
      END IF;
  END LOOP;
  IF gNumERR = 0 THEN
     PQMONPROC.InsLog(vIDproc,'M','FIN OK | Fecha de Sesion: '||TO_CHAR(pFecSesion,'DD/MM/YYYY')||' / Hora de Proceso: '||pHoraProc||':00 hrs.');
     vRet:=PQMONPROC.UpdMonProc(vIDproc,'F');
     RETURN '0';
  ELSE
     PQMONPROC.InsLog(vIDproc,'M','FIN ERROR | Fecha de Sesion: '||TO_CHAR(pFecSesion,'DD/MM/YYYY')||' / Hora de Proceso: '||pHoraProc||':00 hrs.');
     vRet:=PQMONPROC.UpdMonProc(vIDproc,'E');
     RETURN 'E|ERROR en Actualizacion de Importe de Provimilla. Revisar Monitor de Procesos.~';
  END IF;
EXCEPTION
  WHEN OTHERS THEN
       vOraCode:=ABS(SQLCODE);
       ROLLBACK;
       PQMONPROC.InsLog(vIDproc,'M','FIN ERROR | Fecha de Sesion: '||TO_CHAR(pFecSesion,'DD/MM/YYYY')||' / Hora de Proceso: '||pHoraProc||':00 hrs.');
       vRet:=PQMONPROC.UpdMonProc(vIDproc,'E');
       RETURN 'E|ERROR de Base de Datos (ORA-'||LTRIM(LPAD(vOraCode,5,'0'))||')~';
END; -- UpdImpProv

-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
-- FUNCTION f_LoadLiqLote - IPR 1044
-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

FUNCTION f_LoadLiqLote (pFecSesion DATE, pHoraProc CHAR) RETURN CHAR
IS
    vRet         VARCHAR2(512);
    vOraCode     NUMBER:=0;
    vIDproc      NUMBER;
BEGIN
    -- ID DE PROCESO
    vIDproc:=PQMONPROC.InsMonProc('LIQLOTE');
    -- PROCEDIMIENTO
    gNumERR := 0;
    PQMONPROC.InsLog(vIDproc,'M','Fecha de Sesion: '||TO_CHAR(pFecSesion,'DD/MM/YYYY')||' | Hora de Proceso: '||pHoraProc||':00 hrs.');
    FOR r IN (SELECT COD_ARCHIVO,
                     ID_CLRLOAD
                FROM CTL_CLRLOAD
               WHERE FEC_SESION = pFecSesion
                 AND HRA_PROCESO = pHoraProc
                 AND COD_ARCHIVO IN ('MX9998','MX9999','MX9898','MX9899','MX9798','MX8998','MX8999','MX9799')
               ORDER BY ID_CLRLOAD)
    LOOP
        vRet:=f_LoadLiqLoteXID(pFecSesion,r.COD_ARCHIVO,r.ID_CLRLOAD,vIDproc);
        IF vRet = 'E' THEN
            gNumERR:=gNumERR+1;
            PQMONPROC.InsLog(vIDproc,'E','Error en la ejecuci??????n de f_LoadLiqLoteXID');
        END IF;
    END LOOP;
    IF gNumERR = 0 THEN
        PQMONPROC.InsLog(vIDproc,'M','FIN OK | Fecha de Sesion: '||TO_CHAR(pFecSesion,'DD/MM/YYYY')||' / Hora de Proceso: '||pHoraProc||':00 hrs.');
        vRet:=PQMONPROC.UpdMonProc(vIDproc,'F');
        RETURN '0';
    ELSE
        PQMONPROC.InsLog(vIDproc,'M','FIN ERROR | Fecha de Sesion: '||TO_CHAR(pFecSesion,'DD/MM/YYYY')||' / Hora de Proceso: '||pHoraProc||':00 hrs.');
        vRet:=PQMONPROC.UpdMonProc(vIDproc,'E');
        RETURN 'E|ERROR en Carga de la Tabla LIQ_LOTE. Revisar Monitor de Procesos.~';
    END IF;
EXCEPTION
    WHEN OTHERS THEN
         vOraCode:=ABS(SQLCODE);
         ROLLBACK;
         PQMONPROC.InsLog(vIDproc,'M','FIN ERROR | Fecha de Sesion: '||TO_CHAR(pFecSesion,'DD/MM/YYYY')||' / Hora de Proceso: '||pHoraProc||':00 hrs.');
         vRet:=PQMONPROC.UpdMonProc(vIDproc,'E');
         RETURN 'E|ERROR de Base de Datos (ORA-'||LTRIM(LPAD(vOraCode,5,'0'))||')~';
END; -- f_LoadLiqLote

-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
-- FUNCTION f_LoadLiqLoteXID - IPR 1044
-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

FUNCTION f_LoadLiqLoteXID (pFecSesion DATE, pCodArchivo CHAR, pIDClrLoad NUMBER, pIDproc NUMBER) RETURN CHAR
IS
    vOraCode    NUMBER:=0;
    vCont       NUMBER:=0;
    vContLote   NUMBER:=0;
BEGIN
    -- Tabla de Control de Carga de Lotes
    PQMONPROC.InsLog(pIDproc,'M','Procesando '||pCodArchivo||'...');

    -- CLR_MX9998
    IF pCodArchivo = 'MX9998' THEN
        FOR r IN (SELECT DISTINCT IDEEST_P42_ACTC, IDETER_P41_ACTC, SUBSTR(DATREF_P37_ACTC,5,3) DATREF_P37_ACTC
                    FROM CLR_MX9998
                   WHERE ID_CLRLOAD = pIDClrLoad
                     AND IDEMEN_P00_ACTC IN (1244,1442,1444)
                     AND nvl(substr(NUMGUI_P48_ACTC,5,1),' ') = '1' /* comercios por lotes */)
        LOOP
            vContLote:=GetIDLIQLOTE(pFecSesion,r.IDEEST_P42_ACTC,r.IDETER_P41_ACTC,r.DATREF_P37_ACTC);
            if vContLote = 0 THEN
                INSERT INTO LIQ_LOTE
                VALUES(pFecSesion, NULL, r.IDEEST_P42_ACTC, r.IDETER_P41_ACTC, r.DATREF_P37_ACTC,'0');
                vCont:=vCont+1;
            END IF;
        END LOOP;
        PQMONPROC.InsLog(pIDproc,'M','Registros Procesados: '||LTRIM(RTRIM(TO_CHAR(vCont,'999,999'))));
    END IF;

    -- CLR_MX9999
    IF pCodArchivo = 'MX9999' THEN
        FOR r IN (SELECT DISTINCT IDEEST_P42_ACTC, IDETER_P41_ACTC, SUBSTR(DATREF_P37_ACTC,5,3) DATREF_P37_ACTC
                    FROM CLR_MX9999
                   WHERE ID_CLRLOAD = pIDClrLoad
                     AND IDEMEN_P00_ACTC IN (1244,1442,1444)
                     AND nvl(substr(NUMGUI_P48_ACTC,5,1),' ') = '1' /* comercios por lotes */)
        LOOP
            vContLote:=GetIDLIQLOTE(pFecSesion,r.IDEEST_P42_ACTC,r.IDETER_P41_ACTC,r.DATREF_P37_ACTC);
            if vContLote = 0 THEN
                INSERT INTO LIQ_LOTE
                VALUES(pFecSesion, NULL, r.IDEEST_P42_ACTC, r.IDETER_P41_ACTC, r.DATREF_P37_ACTC,'0');
                vCont:=vCont+1;
            END IF;
        END LOOP;
        PQMONPROC.InsLog(pIDproc,'M','Registros Procesados: '||LTRIM(RTRIM(TO_CHAR(vCont,'999,999'))));
    END IF;

    -- CLR_MX9898
    IF pCodArchivo = 'MX9898' THEN
        FOR r IN (SELECT DISTINCT IDEEST_P42_ACTC, IDETER_P41_ACTC, SUBSTR(DATREF_P37_ACTC,5,3) DATREF_P37_ACTC
                    FROM CLR_MX9898
                   WHERE ID_CLRLOAD = pIDClrLoad
                     AND IDEMEN_P00_ACTC IN (1244,1442,1444)
                     AND nvl(substr(NUMGUI_P48_ACTC,5,1),' ') = '1' /* comercios por lotes */)
        LOOP
            vContLote:=GetIDLIQLOTE(pFecSesion,r.IDEEST_P42_ACTC,r.IDETER_P41_ACTC,r.DATREF_P37_ACTC);
            if vContLote = 0 THEN
                INSERT INTO LIQ_LOTE
                VALUES(pFecSesion, NULL, r.IDEEST_P42_ACTC, r.IDETER_P41_ACTC, r.DATREF_P37_ACTC,'0');
                vCont:=vCont+1;
            END IF;
        END LOOP;
        PQMONPROC.InsLog(pIDproc,'M','Registros Procesados: '||LTRIM(RTRIM(TO_CHAR(vCont,'999,999'))));
    END IF;

    -- CLR_MX9899
    IF pCodArchivo = 'MX9899' THEN
        FOR r IN (SELECT DISTINCT IDEEST_P42_ACTC, IDETER_P41_ACTC, SUBSTR(DATREF_P37_ACTC,5,3) DATREF_P37_ACTC
                    FROM CLR_MX9899
                   WHERE ID_CLRLOAD = pIDClrLoad
                     AND IDEMEN_P00_ACTC IN (1244,1442,1444)
                     AND nvl(substr(NUMGUI_P48_ACTC,5,1),' ') = '1' /* comercios por lotes */)
        LOOP
            vContLote:=GetIDLIQLOTE(pFecSesion,r.IDEEST_P42_ACTC,r.IDETER_P41_ACTC,r.DATREF_P37_ACTC);
            if vContLote = 0 THEN
                INSERT INTO LIQ_LOTE
                VALUES(pFecSesion, NULL, r.IDEEST_P42_ACTC, r.IDETER_P41_ACTC, r.DATREF_P37_ACTC,'0');
                vCont:=vCont+1;
            END IF;
        END LOOP;
        PQMONPROC.InsLog(pIDproc,'M','Registros Procesados: '||LTRIM(RTRIM(TO_CHAR(vCont,'999,999'))));
    END IF;

    -- CLR_MX9798
    IF pCodArchivo = 'MX9798' THEN
        FOR r IN (SELECT DISTINCT IDEEST_P42_ACTC, IDETER_P41_ACTC, SUBSTR(DATREF_P37_ACTC,5,3) DATREF_P37_ACTC
                    FROM CLR_MX9798
                   WHERE ID_CLRLOAD = pIDClrLoad
                     AND IDEMEN_P00_ACTC IN (1244,1442,1444)
                     AND nvl(substr(NUMGUI_P48_ACTC,5,1),' ') = '1' /* comercios por lotes */)
        LOOP
            vContLote:=GetIDLIQLOTE(pFecSesion,r.IDEEST_P42_ACTC,r.IDETER_P41_ACTC,r.DATREF_P37_ACTC);
            if vContLote = 0 THEN
                INSERT INTO LIQ_LOTE
                VALUES(pFecSesion, NULL, r.IDEEST_P42_ACTC, r.IDETER_P41_ACTC, r.DATREF_P37_ACTC,'0');
                vCont:=vCont+1;
            END IF;
        END LOOP;
        PQMONPROC.InsLog(pIDproc,'M','Registros Procesados: '||LTRIM(RTRIM(TO_CHAR(vCont,'999,999'))));
    END IF;

    -- CLR_MX8998
    IF pCodArchivo = 'MX8998' THEN
        FOR r IN (SELECT DISTINCT IDEEST_P42_ACTC, IDETER_P41_ACTC, SUBSTR(DATREF_P37_ACTC,5,3) DATREF_P37_ACTC
                    FROM CLR_MX8998
                   WHERE ID_CLRLOAD = pIDClrLoad
                     AND IDEMEN_P00_ACTC IN (1244,1442,1444)
                     AND nvl(substr(NUMGUI_P48_ACTC,5,1),' ') = '1' /* comercios por lotes */)
        LOOP
            vContLote:=GetIDLIQLOTE(pFecSesion,r.IDEEST_P42_ACTC,r.IDETER_P41_ACTC,r.DATREF_P37_ACTC);
            if vContLote = 0 THEN
                INSERT INTO LIQ_LOTE
                VALUES(pFecSesion, NULL, r.IDEEST_P42_ACTC, r.IDETER_P41_ACTC, r.DATREF_P37_ACTC,'0');
                vCont:=vCont+1;
            END IF;
        END LOOP;
        PQMONPROC.InsLog(pIDproc,'M','Registros Procesados: '||LTRIM(RTRIM(TO_CHAR(vCont,'999,999'))));
    END IF;

    -- CLR_MX8999
    IF pCodArchivo = 'MX8999' THEN
        FOR r IN (SELECT DISTINCT IDEEST_P42_ACTC, IDETER_P41_ACTC, SUBSTR(DATREF_P37_ACTC,5,3) DATREF_P37_ACTC
                    FROM CLR_MX8999
                   WHERE ID_CLRLOAD = pIDClrLoad
                     AND IDEMEN_P00_ACTC IN (1244,1442,1444)
                     AND nvl(substr(NUMGUI_P48_ACTC,5,1),' ') = '1' /* comercios por lotes */)
        LOOP
            vContLote:=GetIDLIQLOTE(pFecSesion,r.IDEEST_P42_ACTC,r.IDETER_P41_ACTC,r.DATREF_P37_ACTC);
            if vContLote = 0 THEN
                INSERT INTO LIQ_LOTE
                VALUES(pFecSesion, NULL, r.IDEEST_P42_ACTC, r.IDETER_P41_ACTC, r.DATREF_P37_ACTC,'0');
                vCont:=vCont+1;
            END IF;
        END LOOP;
        PQMONPROC.InsLog(pIDproc,'M','Registros Procesados: '||LTRIM(RTRIM(TO_CHAR(vCont,'999,999'))));
    END IF;
/*
    -- CLR_MX9799
    IF pCodArchivo = 'MX9799' THEN
        FOR r IN (SELECT DISTINCT IDEEST_P42_ACTC, IDETER_P41_ACTC, SUBSTR(DATREF_P37_ACTC,5,3) DATREF_P37_ACTC
                    FROM CLR_MX9799
                   WHERE ID_CLRLOAD = pIDClrLoad
                     AND IDEMEN_P00_ACTC IN (1244,1442,1444)
                     AND nvl(substr(NUMGUI_P48_ACTC,5,1),' ') = '1' )
        LOOP
            vContLote:=GetIDLIQLOTE(pFecSesion,r.IDEEST_P42_ACTC,r.IDETER_P41_ACTC,r.DATREF_P37_ACTC);
            if vContLote = 0 THEN
                INSERT INTO LIQ_LOTE
                VALUES(pFecSesion, NULL, r.IDEEST_P42_ACTC, r.IDETER_P41_ACTC, r.DATREF_P37_ACTC,'0');
                vCont:=vCont+1;
            END IF;
        END LOOP;
        PQMONPROC.InsLog(pIDproc,'M','Registros Procesados: '||LTRIM(RTRIM(TO_CHAR(vCont,'999,999'))));
    END IF;
    */
    RETURN '0';
EXCEPTION
    WHEN OTHERS THEN
         vOraCode:=ABS(SQLCODE);
         ROLLBACK;
         PQMONPROC.InsLog(pIDproc,'E','Error de Base de Datos (ORA-'||LTRIM(LPAD(vOraCode,5,'0'))||')');
         RETURN 'E';
END; -- f_LoadLiqLoteXID

-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
-- FUNCTION f_UpdateLiqLote - IPR 1044
-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

FUNCTION f_UpdateLiqLote (pFecSesion DATE, pHraProceso CHAR) RETURN CHAR
IS
    vOraCode     NUMBER:=0;
    vMsgErr        VARCHAR2(256);
BEGIN
    FOR R IN (SELECT NUMEST_P42_ACTC, NUMTER_P41_ACTC, NUMLOTE_CIERRE_ACTC
        FROM CLR_AX1520 X, CTL_CLRLOAD C
        WHERE X.ID_CLRLOAD  = C.ID_CLRLOAD
        AND   X.FEC_SESION  = TO_CHAR(pFecSesion,'YYYYMMDD')
        AND   C.HRA_PROCESO = pHraProceso)
    LOOP
        UPDATE LIQ_LOTE
        SET ESTADO = '1',
            FEC_CIERRE = pFecSesion
        WHERE  COD_COMERCIO = R.NUMEST_P42_ACTC AND
            NRO_SERIE = R.NUMTER_P41_ACTC AND
            NUM_LOTE = R.NUMLOTE_CIERRE_ACTC AND
            ESTADO = '0' AND
            FEC_CIERRE IS NULL;
    END LOOP;
    RETURN '0';
EXCEPTION
    WHEN OTHERS THEN
         vOraCode:=ABS(SQLCODE);
         ROLLBACK;
         vMsgErr := 'E|ERROR de Base de Datos (ORA-'||LTRIM(LPAD(vOraCode,5,'0'))||')~';
         PQMONPROC.InsLOG(0,'E',vMsgErr);
         RETURN vMsgErr;
END; -- f_UpdateLiqLote


-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
END; -- PQPCLRLOAD_IPR1387
/