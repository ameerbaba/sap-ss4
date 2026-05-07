*&---------------------------------------------------------------------*
***INCLUDE           ZCOR_PROJTASK_LABOR_TEMP_TOP
*&---------------------------------------------------------------------*
* Developer: Ameer Patnam
* Date : 02/02/2021
* Defect # - 46 - Getting "Unauthorized" message when using ZPR1
* WorkFront ID 199414: Changed the table from bseg to acdoca
*---------------------------------------------------------------------*
* Developer: Davisraja Pious
* Date : 03/23/2021
* Transport Request : SD1K906792
* Userstory STRY0437607 - Performance issue in Tcode ZRP1
* Fetching data from Database view COVP is omitted and fetched it from CDS view V_COVP_WOTP
*STSK0066200:UAT Issue  : Getting  time out dump while executing T code  ZRP1_ALL
*BABAA on 06/02/2023
***********************************************************************
TABLES: aufk,
        csks,
        cskt,
        coep,
        covp,
        *covp,
        coift,
        pa0002,
        pa0001,
        tcn7t,
        prps,
        jest,
        *proj,
        proj,
        usr01,
        bseg,
        acdoca.

TYPE-POOLS : slis, rsds.

*----------------------------------------------------------------------*
* ALV related data declaration
*----------------------------------------------------------------------*
DATA: gt_fieldcat         TYPE slis_t_fieldcat_alv,
      gs_layout           TYPE slis_layout_alv,
      gt_events           TYPE slis_t_event,
      gt_sort             TYPE slis_t_sortinfo_alv,
      wa_sort             TYPE slis_sortinfo_alv,
      gt_list_top_of_page TYPE slis_t_listheader,
      gv_pos              TYPE sy-cucol,
      repname             LIKE rsvar-report,
      g_save(1)           TYPE c,
      g_exit(1)           TYPE c,
      g_variant           LIKE disvariant,
      gx_variant          LIKE disvariant.

FIELD-SYMBOLS: <field>.
FIELD-SYMBOLS: <break>.
FIELD-SYMBOLS: <break1>.
RANGES:        vk FOR csks-kostl.

DATA: gv_col.
DATA: f1(20).
DATA: f2(20).
DATA: number(8)     TYPE n.
DATA: type.
DATA: oldind(1)     TYPE c.
DATA: pflg(1)       TYPE c.
DATA: hold_stat     LIKE jest-stat.
DATA: cctr_chk(22)  TYPE c.
DATA: projchk(10)   TYPE c.
DATA: busachk(4)    TYPE c.
DATA: auth_ind(1)   TYPE c.
DATA: level         TYPE p.
DATA: hold_fkstl    LIKE prps-fkstl.
DATA: hold_mgrna    LIKE pa0001-ename.
DATA: sublevel2     TYPE p DECIMALS 2.
DATA: subtotal      TYPE p DECIMALS 2.
DATA: total         TYPE p DECIMALS 2.
DATA: hrs           TYPE p DECIMALS 2.
DATA: method        TYPE i.
DATA: wbselem(20)   TYPE c.
DATA: project(1)    TYPE c.
DATA: char          LIKE covp-objnr.
DATA: found         TYPE c.
DATA: page1         TYPE i.
DATA: page2         TYPE i.
DATA: rpt_type      TYPE i.
DATA: area(30).
DATA: area2(30).
DATA: desc(30).
DATA: l_kostl       LIKE cskt-kostl.

DATA: BEGIN OF as_hlp_kostl OCCURS 0.
        INCLUDE STRUCTURE csks.
      DATA: END OF as_hlp_kostl.

DATA: BEGIN OF tab_values OCCURS 50.
        INCLUDE STRUCTURE ccsel.
      DATA: END OF tab_values.

DATA: BEGIN OF postab OCCURS 0.
        INCLUDE STRUCTURE covp.
      DATA: END OF postab.

DATA: BEGIN OF lt_postab OCCURS 0.
        INCLUDE STRUCTURE covp.
      DATA: END OF lt_postab.

DATA: BEGIN OF lt_covp11 OCCURS 0.
        INCLUDE STRUCTURE covp.
      DATA: END OF lt_covp11.

DATA: BEGIN OF lt_covp_stat OCCURS 0.
*Begin of modification by Davisraja Pious on 03/22/2021 C #STRY0437607
DATA: kokrs    TYPE coep-kokrs,
      belnr    TYPE coep-belnr,
      buzei    TYPE coep-buzei,
      perio    TYPE coep-perio,
      mbgbtr   TYPE coep-mbgbtr,
      lednr    TYPE coep-lednr,
      objnr    TYPE coep-objnr,
      gjahr    TYPE coep-gjahr,
      wrttp    TYPE coep-wrttp,
      versn    TYPE coep-versn,
      pernr    TYPE coep-pernr,
      bukrs    TYPE coep-bukrs,
      refbz_fi TYPE coep-refbz_fi,
      zname2   TYPE coep-zname2,
      refbn    TYPE cobk-refbn.
*End of modification by Davisraja Pious on 03/22/2021 C #STRY0437607
DATA: END OF lt_covp_stat.

DATA: BEGIN OF gt_bseg OCCURS 0,
        bukrs LIKE bseg-bukrs,
        belnr LIKE bseg-belnr,
        gjahr LIKE bseg-gjahr,
        buzei LIKE bseg-buzei,
        zuonr LIKE bseg-zuonr,
        pernr LIKE bseg-pernr,
        kostl LIKE bseg-kostl,
        hkont LIKE bseg-hkont.
DATA: END OF gt_bseg.

DATA: BEGIN OF gt_acdoca OCCURS 0,
        rbukrs LIKE acdoca-rbukrs,
        belnr  LIKE acdoca-belnr,
        gjahr  LIKE acdoca-gjahr,
        buzei  LIKE acdoca-buzei,
        zuonr  LIKE acdoca-zuonr,
        pernr  LIKE acdoca-pernr,
        ukostl LIKE acdoca-ukostl,
        racct  LIKE acdoca-racct.
DATA: END OF gt_acdoca.

DATA: BEGIN OF gt_acdoca_range OCCURS 0,
        rbukrs LIKE acdoca-rbukrs,
        belnr  LIKE acdoca-belnr,
        gjahr  LIKE acdoca-gjahr,
        buzei  LIKE acdoca-buzei.
DATA: END OF gt_acdoca_range.

DATA: BEGIN OF gt_prps OCCURS 0,
        pspnr LIKE prps-pspnr,
        posid LIKE prps-posid,
        objnr LIKE prps-objnr,
        psphi LIKE prps-psphi.
DATA: END OF gt_prps.

DATA: BEGIN OF work OCCURS 10.
DATA: budat        LIKE covp-budat,
      kstar        LIKE covp-kstar,
      pernr        LIKE covp-pernr,
      belnr        LIKE covp-belnr,
      area(20),
      desc(30),
      kostl        LIKE pa0001-kostl,
      pohrs        LIKE covp-wtgbtr,
      bldat        LIKE coift-endda,
      cpudt        LIKE coift-endda,
      blart        LIKE covp-blart,
      name(80),
      type,
      aflag,
      ansvh        LIKE pa0001-ansvh,
      fkstl        LIKE pa0001-kostl,
      wbscc        LIKE pa0001-kostl,
      mgrna        LIKE pa0001-ename,
      vernr        LIKE prps-vernr,
      invoicer     LIKE prps-cont_invoicer,
      analyst      LIKE prps-yyanlystr,
      prart        LIKE prps-prart,            "Project Type
      zps_disc     LIKE prps-zps_disc,         "Discount
      zps_cbug     LIKE prps-zps_cbug,         "Core S/W Bug
      zps_qre      LIKE prps-zps_qre,          "Qualified QRE
      zps_unbill   LIKE prps-zps_unbill,       "Unbillable
      usr02        LIKE prps-usr02,            "Customer Type
      zps_pkgnum   LIKE prps-zps_pkgnum,       "Package Number
      catgdesc(17),
      usr03        LIKE prps-usr03,
      zps_sh_tskid LIKE prps-zps_sh_tskid,
      zps_wrk_type LIKE prps-zps_wrk_type.
DATA: END OF work.

DATA: BEGIN OF work1 OCCURS 10.
DATA: budat      LIKE covp-budat,
      kstar      LIKE covp-kstar,
      pernr      LIKE covp-pernr,
      belnr      LIKE covp-belnr,
      area(20),
      desc(30),
      kostl      LIKE pa0001-kostl,
      pohrs      LIKE covp-wtgbtr,
      bldat      LIKE coift-endda,
      cpudt      LIKE coift-endda,
      blart      LIKE covp-blart,
      name(80),
      type,
      aflag,
      ansvh      LIKE pa0001-ansvh,
      fkstl      LIKE pa0001-kostl,
      wbscc      LIKE pa0001-kostl,
      mgrna      LIKE pa0001-ename,
      vernr      LIKE prps-vernr,
      invoicer   LIKE prps-cont_invoicer,
      analyst    LIKE prps-yyanlystr,
      prart      LIKE prps-prart,            "Project Type
      zps_disc   LIKE prps-zps_disc,         "Discount
      zps_cbug   LIKE prps-zps_cbug,         "Core S/W Bug
      zps_qre    LIKE prps-zps_qre,          "Qualified QRE
      zps_unbill LIKE prps-zps_unbill,       "Unbillable
      usr02      LIKE prps-usr02,            "Customer Type
      zps_pkgnum LIKE prps-zps_pkgnum,       "Package Number
      catgdesc   LIKE zco_catg-catg1desc.
DATA: END OF work1.

DATA: BEGIN OF it_pa0001 OCCURS 0,
        pernr LIKE pa0001-pernr,
        ename LIKE pa0001-ename,
        ansvh LIKE pa0001-ansvh,
        gsber LIKE pa0001-gsber,
      END OF it_pa0001.

DATA: BEGIN OF data_tab OCCURS 10,
        text01(60),
        text02(60),
        text03(60),
        text04(60),
        text05(60),
        text06(60),
        text07(60),
        text08(60),
        text09(60),
        text10(60),
        text11(60),
        text12(60),
        text13(60),
        text14(60),
        text15(60),
        text16(60),
        text17(60),
        text18(60),
        text19(60),
        text20(60),
        text21(20),
        text22(20),
        text23(20),
      END OF data_tab.

DATA: BEGIN OF name_tab OCCURS 20,
        text(60),
      END OF name_tab.

DATA: indicator   LIKE zco_catg-direct_ind,
      catgy1      LIKE zco_catg-category1,
      catg1desc   LIKE zco_catg-catg1desc,
      catgy2      LIKE zco_catg-category2,
      catg2desc   LIKE zco_catg-catg2desc,
      busarea     LIKE zco_catg-cross_ba,
      costctr     LIKE csks-kostl,
      order       LIKE aufk-aufnr,
      c_area      LIKE csks-kokrs,
      lv_refbz_fi LIKE covp-refbz_fi,
      lv_mbgbtr   LIKE covp-mbgbtr.

DATA BEGIN OF tab_return OCCURS 0.
INCLUDE STRUCTURE bapiret2.
DATA END OF tab_return.

DATA: datehdr(71),
      datea(10),
      dateb(10).

DATA: gt_gbl_employees    LIKE STANDARD TABLE OF pa0001,
      gt_gbl_wbs_elements LIKE STANDARD TABLE OF prps,
      gt_gbl_int_orders   LIKE STANDARD TABLE OF aufk,
      gt_gbl_cost_centers LIKE STANDARD TABLE OF csks.

DATA: gt_etc_global LIKE STANDARD TABLE OF zetc_global,
      wa_global     LIKE zetc_global.

DATA: lv_buzei     LIKE covp-buzei,
      lv_posid     LIKE prps-posid,
      lv_posid_in  LIKE prps-posid,
      lv_posid_out LIKE prps-posid,
      lv_cnt       TYPE i.

CONSTANTS: gc_reg_time LIKE zetc_global-lgart VALUE '00RG'.

RANGES: gr_stat_orders FOR aufk-auart.

RANGES: r_objnr_prps FOR prps-objnr,
        r_bukrs_bseg FOR bseg-bukrs,
        r_belnr_bseg FOR bseg-belnr,
        r_gjahr_bseg FOR bseg-gjahr,
        r_buzei_bseg FOR bseg-buzei,
        r_belnr      FOR covp-belnr,
        r_zname2     FOR covp-zname2,
        r_buzei      FOR covp-buzei,
        r_posid_prps FOR prps-posid,
        r_objnr_stat FOR prps-objnr.

DEFINE wbs_int_format.

  CALL FUNCTION 'CONVERSION_EXIT_ABPSP_INPUT'
    EXPORTING
      input     = &1
    IMPORTING
      output    = &2
    EXCEPTIONS
      not_found = 1
      OTHERS    = 2.

  IF sy-subrc <> 0.
* MESSAGE ID SY-MSGID TYPE SY-MSGTY NUMBER SY-MSGNO
*         WITH SY-MSGV1 SY-MSGV2 SY-MSGV3 SY-MSGV4.
  ENDIF.

END-OF-DEFINITION.
