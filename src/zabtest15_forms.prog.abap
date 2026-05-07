*----------------------------------------------------------------------*
***INCLUDE ZCOR_PROJTASK_LABOR_TEMP_FORMS.
*----------------------------------------------------------------------*
* Developer: Ameer Patnam
* Date : 02/02/2021
* Defect # - 46 - Getting "Unauthorized" message when using ZPR1
* WorkFront ID 199414: Changed the table from bseg to acdoca
*--------------------------------------------------------------*
* Developer: Davisraja Pious
* Date : 03/23/2021
* Transport Request : SD1K906792
* Userstory STRY0437607 - Performance issue in Tcode ZRP1
* Fetching data from Database view COVP is omitted and fetched it from CDS view V_COVP_WOTP
*STSK0066200:UAT Issue  : Getting  time out dump while executing T code  ZRP1_ALL
*BABAA on 06/02/2023
*----------------------------------------------------------------------*
*BABAA on 11/27/2023 STSK0070517 Add document date to the ZRP1 report
*----------------------------------------------------------------------*

FORM cc_filter_work.

  DATA: work_idx TYPE i,
        cc_len   TYPE i,
        work_cc  LIKE pa0001-kostl.

* Loop through the detail and check the employee's cost center
* against the department selection values
  LOOP AT work.
    work_idx = sy-tabix.
    CLEAR: work_cc.
    cc_len = strlen( work-kostl ).
    IF cc_len = 4.
      CONCATENATE '000000' work-kostl INTO work_cc.
    ELSE.
      work_cc = work-kostl.
    ENDIF.
    IF work_cc NOT IN dept1.
      DELETE work INDEX work_idx.
    ENDIF.
  ENDLOOP.

ENDFORM.

*&----------------------------------------------------------------------
*&  Form AUTH_FILTER_WORK
*&----------------------------------------------------------------------
FORM auth_filter_work.

  DATA: work_idx    TYPE i,
        work_cnt    TYPE i,
        dele_cnt    TYPE i,
        cc_len      TYPE i,
        emparea(16) TYPE c,
        empauth(01) TYPE c,
        objarea(16) TYPE c,
        objauth(01) TYPE c,
        prjarea(16) TYPE c,
        badarea(16) TYPE c,
        authmsg(50) TYPE c,
        dispcnt(07) TYPE c.

* Loop through the detail and check the employee's cost center
* and the object cost center against the user's K_CCA permissions using
* the new style check of just the resparea.

  LOOP AT work.
    work_idx = sy-tabix.
    CLEAR: emparea,
           empauth,
           objarea,
           objauth.
    PERFORM f_get_area USING work-kostl CHANGING emparea.

    AUTHORITY-CHECK OBJECT 'K_CCA'
      ID 'CO_ACTION' FIELD ''
      ID 'KSTAR' FIELD ''
      ID 'RESPAREA' FIELD emparea.
    IF sy-subrc <> 0.
      empauth = 'N'.
    ENDIF.
    IF work-fkstl IS INITIAL.
      SELECT SINGLE *
        FROM aufk
       WHERE aufnr = work-area.
      IF sy-subrc = 0.
        CONCATENATE 'KS0001' aufk-kostv INTO objarea.
      ELSE.
        PERFORM f_get_area USING work-area CHANGING objarea.
      ENDIF.
    ELSE.
      CONCATENATE 'KS0001' work-fkstl INTO objarea.
      CONCATENATE work-area(1)
                  work-area+2(5)
             INTO prjarea.
    ENDIF.
    IF objarea IS NOT INITIAL.
      AUTHORITY-CHECK OBJECT 'K_CCA'
        ID 'CO_ACTION' FIELD ''
        ID 'KSTAR' FIELD ''
        ID 'RESPAREA' FIELD objarea.
      IF sy-subrc <> 0.
        objauth = 'N'.
      ELSE.
        CLEAR objauth.
      ENDIF.
      IF objauth = 'N' AND
         work-wbscc IS NOT INITIAL.
        CONCATENATE 'KS0001' work-wbscc INTO objarea.
        AUTHORITY-CHECK OBJECT 'K_CCA'
          ID 'CO_ACTION' FIELD ''
          ID 'KSTAR' FIELD ''
          ID 'RESPAREA' FIELD objarea.
        IF sy-subrc <> 0.
          objauth = 'N'.
        ELSE.
          CLEAR objauth.
        ENDIF.
      ENDIF.
      IF objauth = 'N' AND
         aufk-objnr IS NOT INITIAL.
      ELSEIF objauth = 'N' AND
             prjarea IS NOT INITIAL.
        AUTHORITY-CHECK OBJECT 'ZPROJECT'
          ID 'ACTVT'   FIELD '03'
          ID 'PROJECT' FIELD prjarea(10).
        IF sy-subrc = 0.
          CLEAR objauth.
        ENDIF.
      ENDIF.
    ENDIF.
    IF empauth = 'N' AND objauth = 'N'.
      IF badarea IS INITIAL.
        badarea = objarea.
      ENDIF.
      DELETE work INDEX work_idx.
      dele_cnt = dele_cnt + 1.
    ENDIF.
    work_cnt = work_cnt + 1.
  ENDLOOP.
  IF dele_cnt > 0.
    AUTHORITY-CHECK OBJECT 'K_CCA'
      ID 'CO_ACTION' FIELD ''
      ID 'KSTAR' FIELD ''
      ID 'RESPAREA' FIELD badarea.
    WRITE dele_cnt TO dispcnt.
    CONCATENATE dispcnt 'of'
           INTO authmsg
      SEPARATED BY space.
    WRITE work_cnt TO dispcnt.
    CONCATENATE authmsg dispcnt 'records unauthorized'
           INTO authmsg
      SEPARATED BY space.
    MESSAGE i105(z1) WITH authmsg.
  ENDIF.

ENDFORM.

*&---------------------------------------------------------------------*
*&         CHECK_OBJECT_SELECTION
*&---------------------------------------------------------------------*
FORM check_object_selection.

  IF posnr1 IS INITIAL.
    IF gsber IS INITIAL.
      IF mgrcc IS INITIAL AND rptcc IS INITIAL.
        PERFORM check_kostl.
      ELSE.
        PERFORM setup_cctrproj_select.
      ENDIF.
    ELSE.
      PERFORM setup_busarea_select.
    ENDIF.
    SELECT pspnr
           posid
           objnr
           psphi
    FROM   prps
      INTO CORRESPONDING FIELDS OF TABLE gt_prps
         WHERE ( posid LIKE 'PSO%' OR posid LIKE 'PSM%' )
           AND belkz = 'X'
           AND xstat = 'X'.

    LOOP AT gt_prps.

      r_objnr_stat-sign   = 'I'.
      r_objnr_stat-option = 'EQ'.
      r_objnr_stat-low    = gt_prps-objnr.

      COLLECT r_objnr_stat.
      CLEAR r_objnr_stat.

    ENDLOOP.

    CLEAR gt_prps[].
    CLEAR gt_prps.
  ELSE.
    LOOP AT posnr1.
      IF posnr1-low CA '.'.
        project = 'Y'.
        REPLACE ALL OCCURRENCES OF '.' IN posnr1-low WITH space.
      ENDIF.
      CLEAR wbselem.
      IF posnr1-high CA '.'.
        REPLACE ALL OCCURRENCES OF '.' IN posnr1-high WITH space.
      ENDIF.
      IF posnr1-high IS INITIAL AND posnr1-option = 'EQ'.
        IF NOT posnr1 CS '*'.
          CONCATENATE posnr1 '*' INTO posnr1.
          posnr1-option = 'CP'.
        ENDIF.
      ENDIF.
      MODIFY posnr1.
    ENDLOOP.
    PERFORM setup_wbs_select.
    IF project IS INITIAL.
      PERFORM setup_order_select.
    ENDIF.
  ENDIF.

  PERFORM f_setup_employee.

ENDFORM.

*&---------------------------------------------------------------------*
*&      Form  CHECK_KOSTL
*&---------------------------------------------------------------------*
FORM check_kostl.

  CLEAR vk[].
  LOOP AT dept1.
    MOVE-CORRESPONDING dept1 TO vk.
    APPEND vk.
  ENDLOOP.
  CLEAR dept1[].
  SELECT *
    FROM csks INTO TABLE as_hlp_kostl
   WHERE kostl IN vk.
  LOOP AT as_hlp_kostl.
    IF gsber IS NOT INITIAL.
      CHECK as_hlp_kostl-gsber IN gsber.
      IF as_hlp_kostl-datbi < date1-high.
        CONTINUE.
      ENDIF.
    ENDIF.
    found = 'X'.
    CLEAR dept1-high.
    dept1-sign   = 'I'.
    dept1-option = 'EQ'.
    dept1-low    = as_hlp_kostl-kostl.
    COLLECT dept1.
    CLEAR tab_values.
    tab_values-field  = 'OBJNR'.
    tab_values-sign   = 'I'.
    tab_values-option = 'EQ'.
    IF method = 1.
      SELECT *
        FROM pa0001
       WHERE kostl = as_hlp_kostl-kostl
       ORDER BY pernr.
        CONCATENATE 'KL0001' as_hlp_kostl-kostl pa0001-pernr+3(5)
                  INTO tab_values-low.
        COLLECT tab_values.
      ENDSELECT.
    ELSE.
      CONCATENATE 'KS0001' as_hlp_kostl-kostl
             INTO tab_values-low.
      COLLECT tab_values.
    ENDIF.
  ENDLOOP.

ENDFORM.

*&---------------------------------------------------------------------*
*&         SETUP_WBS_SELECT
*&---------------------------------------------------------------------*
FORM setup_wbs_select.

  SELECT *
    FROM prps
   WHERE posid IN posnr1.
    IF gsber IS NOT INITIAL.
      CHECK prps-pgsbr IN gsber.
    ENDIF.
    CLEAR hold_stat.
    SELECT *
      FROM jest
     WHERE objnr = prps-objnr
       AND inact = ' '.
      IF jest-stat(1) = 'E'.
        hold_stat = jest-stat.
      ENDIF.
    ENDSELECT.
    IF activ IS INITIAL.
      CHECK hold_stat <> 'E0003'.
    ENDIF.
    IF tecod IS INITIAL.
      CHECK hold_stat <> 'E0006'.
    ENDIF.
    IF closd IS INITIAL.
      CHECK hold_stat <> 'E0004'.
    ENDIF.
    found = 'X'.
    tab_values-field  = 'OBJNR'.
    tab_values-sign   = 'I'.
    tab_values-option = 'EQ'.
    tab_values-low    = prps-objnr.
    APPEND tab_values.
  ENDSELECT.

ENDFORM.

*&---------------------------------------------------------------------*
*&         SETUP_ORDER_SELECT
*&---------------------------------------------------------------------*
FORM setup_order_select.

  DATA: ord_auth(1) TYPE c.

  SELECT *
    FROM aufk
   WHERE aufnr IN posnr1.
    found = 'X'.
    tab_values-field  = 'OBJNR'.
    tab_values-sign   = 'I'.
    tab_values-option = 'EQ'.
    tab_values-low    = 'OR'.
    tab_values-low+2  = aufk-aufnr.
    APPEND tab_values.
  ENDSELECT.

ENDFORM.

*&---------------------------------------------------------------------*
*&         SETUP_BUSAREA_SELECT
*&---------------------------------------------------------------------*
FORM setup_busarea_select.

  SELECT *
    FROM prps
   WHERE pgsbr IN gsber.
    CLEAR hold_stat.
    SELECT *
      FROM jest
     WHERE objnr = prps-objnr
       AND inact = ' '.
      IF jest-stat(1) = 'E'.
        hold_stat = jest-stat.
      ENDIF.
    ENDSELECT.
    IF activ IS INITIAL.
      CHECK hold_stat <> 'E0003'.
    ENDIF.
    IF tecod IS INITIAL.
      CHECK hold_stat <> 'E0006'.
    ENDIF.
    IF closd IS INITIAL.
      CHECK hold_stat <> 'E0004'.
    ENDIF.
    found = 'X'.
    tab_values-field  = 'OBJNR'.
    tab_values-sign   = 'I'.
    tab_values-option = 'EQ'.
    tab_values-low    = prps-objnr.
    APPEND tab_values.
  ENDSELECT.

  SELECT *
    FROM aufk
   WHERE gsber IN gsber.
    found = 'X'.
    tab_values-field  = 'OBJNR'.
    tab_values-sign   = 'I'.
    tab_values-option = 'EQ'.
    tab_values-low    = 'OR'.
    tab_values-low+2  = aufk-aufnr.
    APPEND tab_values.
  ENDSELECT.

  SELECT *
    FROM csks
   WHERE gsber IN gsber.
    IF csks-datbi < date1-high.
      CONTINUE.
    ENDIF.
    CONCATENATE 'KS0001' csks-kostl
          INTO cctr_chk.
    found = 'X'.
    tab_values-field  = 'OBJNR'.
    tab_values-sign   = 'I'.
    tab_values-option = 'EQ'.
    tab_values-low    = cctr_chk.
    COLLECT tab_values.
  ENDSELECT.

ENDFORM.

*&---------------------------------------------------------------------*
*&         SETUP_CCTRPROJ_SELECT
*&---------------------------------------------------------------------*
FORM setup_cctrproj_select.

  IF mgrcc IS INITIAL.
    SELECT *
      FROM prps
     WHERE akstl IN rptcc.
      found = 'X'.
      tab_values-field  = 'OBJNR'.
      tab_values-sign   = 'I'.
      tab_values-option = 'EQ'.
      tab_values-low    = prps-objnr.
      APPEND tab_values.
    ENDSELECT.
  ELSEIF rptcc IS INITIAL.
    SELECT *
      FROM prps
     WHERE fkstl IN mgrcc.
      found = 'X'.
      tab_values-field  = 'OBJNR'.
      tab_values-sign   = 'I'.
      tab_values-option = 'EQ'.
      tab_values-low    = prps-objnr.
      APPEND tab_values.
    ENDSELECT.
  ELSE.
    SELECT *
      FROM prps
     WHERE akstl IN rptcc
       AND fkstl IN mgrcc.
      found = 'X'.
      tab_values-field  = 'OBJNR'.
      tab_values-sign   = 'I'.
      tab_values-option = 'EQ'.
      tab_values-low    = prps-objnr.
      APPEND tab_values.
    ENDSELECT.
  ENDIF.

ENDFORM.

*&---------------------------------------------------------------------*
*&    FORM  WRITE_REPORT
*&---------------------------------------------------------------------*
FORM write_report.

  rpt_type = 1.
  CLEAR: hold_fkstl,
         hold_mgrna,
         area,
         subtotal,
         total,
         level,
         sublevel2,
         area2.

  LOOP AT work.
    IF work-area <> area AND area IS NOT INITIAL.
      PERFORM subtotal.
      IF paging IS NOT INITIAL AND area NA '.'.
        NEW-PAGE.
      ENDIF.
    ENDIF.
    IF work-area+0(1) = 'P'.
      IF work-area(10) <> area2 AND area2 CS '.'.
        PERFORM sublevel2.
        IF paging IS NOT INITIAL.
          NEW-PAGE.
        ENDIF.
      ENDIF.
    ELSEIF work-area+0(1) = 'S'.
      IF work-area(13) <> area2 AND area2 CS '.'.
        PERFORM sublevel2.
        IF paging IS NOT INITIAL.
          NEW-PAGE.
        ENDIF.
      ENDIF.
    ELSE.
      IF work-area(7) <> area2 AND area2 CS '.'.
        PERFORM sublevel2.
        IF paging IS NOT INITIAL.
          NEW-PAGE.
        ENDIF.
      ENDIF.
    ENDIF.

    IF sort2 = 'X'.
      IF work-fkstl <> hold_fkstl.
        NEW-PAGE.
        hold_fkstl = work-fkstl.
      ENDIF.
    ENDIF.
    IF sort3 = 'X'.
      IF work-mgrna <> hold_mgrna.
        NEW-PAGE.
        hold_mgrna = work-mgrna.
      ENDIF.
    ENDIF.
    type = work-type.
    area = work-area.
    IF work-area+0(1) = 'S'.
      area2 = work-area+0(13).
    ELSEIF work-area+0(1) = 'P'.
      area2 = work-area+0(10).
    ELSE.
      area2 = work-area(7).
    ENDIF.
    desc = work-desc.

    PERFORM f_color.

    IF category = 'X'.
      WRITE: /001    work-catgdesc.
      WRITE:  020    work-area.
      WRITE:  038    work-desc(30).
      WRITE:  070    work-pernr.
      WRITE:  080    work-ansvh.
      WRITE:  083    work-name(25).
      hrs = work-pohrs. "#EC CI_FLDEXT_OK[2610650] Kumara 01/09/2020 INC1482
      WRITE:  110(11) hrs.
      subtotal = subtotal + hrs.
      WRITE:  122    work-kostl.
      WRITE:  127    work-aflag.
      WRITE:  129    work-blart.

      IF detail IS INITIAL.
        WRITE: 132   work-budat.
        WRITE: 143   work-bldat.
        WRITE: 155   work-cpudt MM/DD/YYYY.
      ENDIF.

    ELSE.
      WRITE: /006     work-area.
      WRITE:  028     work-desc(30).
      WRITE:  057     work-pernr.
      WRITE:  067     work-ansvh.
      WRITE:  070     work-name(25).
      hrs = work-pohrs. "#EC CI_FLDEXT_OK[2610650] Kumara 01/09/2020 INC1483
      WRITE:  097(11) hrs.
      subtotal = subtotal + hrs.
      WRITE:  109     work-kostl.
      WRITE:  114     work-aflag.
      WRITE:  116     work-blart.
      IF detail IS INITIAL.
        WRITE: 119   work-budat.
        WRITE: 130   work-bldat.
        WRITE: 141   work-cpudt.
        WRITE:  152  work-usr03.
        WRITE:  163  work-zps_sh_tskid.
        WRITE:  174  work-zps_wrk_type.
      ENDIF.
    ENDIF.
  ENDLOOP.
  PERFORM total.
ENDFORM.

*---------------------------------------------------------------------*
*       FORM SUBTOTAL
*---------------------------------------------------------------------*
FORM subtotal.
  IF category = 'X'.
    WRITE: /006 ' '.
    ULINE 110(011).
    FORMAT COLOR COL_TOTAL INTENSIFIED OFF.
    WRITE: /006     area.
    WRITE:  028     desc.
    WRITE:  110(11) subtotal.
    sublevel2 = sublevel2 + subtotal.
    total = total + subtotal.
    subtotal = 0.
    level = level + 1.
    SKIP.

  ELSE.
    WRITE: /006 ' '.
    ULINE 097(011).
    FORMAT COLOR COL_TOTAL INTENSIFIED OFF.
    WRITE: /006     area.
    WRITE:  028     desc.
    WRITE:  097(11) subtotal.
    sublevel2 = sublevel2 + subtotal.
    total = total + subtotal.
    subtotal = 0.
    level = level + 1.
    SKIP.
  ENDIF.
ENDFORM.


*---------------------------------------------------------------------*
*       FORM TOTAL
*---------------------------------------------------------------------*
FORM total.
  PERFORM subtotal.
  PERFORM sublevel2.
  IF category = 'X'.
    WRITE: /006    ' '.
    WRITE AT 110    '==========='.
    FORMAT COLOR COL_TOTAL INTENSIFIED ON.
    WRITE: /006    'Total'.
    WRITE: 110(11) total.
  ELSE.
    WRITE: /006    ' '.
    WRITE AT 97    '==========='.
    FORMAT COLOR COL_TOTAL INTENSIFIED ON.
    WRITE: /006    'Total'.
    WRITE: 097(11) total.
  ENDIF.
ENDFORM.

*---------------------------------------------------------------------*
*       FORM SUBLEVEL2
*---------------------------------------------------------------------*
FORM sublevel2.
  IF type = '1'.
    FORMAT COLOR COL_TOTAL INTENSIFIED ON.

    WRITE: /006 area2.

    CALL FUNCTION 'CONVERSION_EXIT_KONPD_INPUT'
      EXPORTING
        input     = area2
      IMPORTING
        output    = number
        projwa    = *proj
      EXCEPTIONS
        not_found = 1
        OTHERS    = 2.

    IF sy-subrc = 0.
      WRITE: 028 *proj-post1.
    ENDIF.
    IF category = 'X'.
      WRITE:  110(11) sublevel2.
      FORMAT COLOR OFF.
      ULINE /006(191).
    ELSE.
      WRITE: 097(11) sublevel2.
      FORMAT COLOR OFF.
      ULINE /006(177).
    ENDIF.

  ENDIF.
  sublevel2 = 0.
  level = 0.

ENDFORM.


*&---------------------------------------------------------------------*
*&      Form  WRITE_REPORT1
*&---------------------------------------------------------------------*
FORM write_report1.
*SR5085 -- Additional request: Reset new report selection to 0.
  sy-lsind = 0.

  rpt_type = 2.
  CLEAR: total, subtotal, area.
  ASSIGN (<field>) TO <break>.
  LOOP AT work.
    IF area <> <break> AND area IS NOT INITIAL.

      WRITE: /006 ' '.
      IF category = 'X'.
        WRITE AT 110 '-----------'.
        FORMAT COLOR COL_TOTAL INTENSIFIED OFF.
        WRITE: /110(11) subtotal.
      ELSE.
        WRITE AT 97 '-----------'.
        FORMAT COLOR COL_TOTAL INTENSIFIED OFF.
        WRITE: /097(11) subtotal.
      ENDIF.

      SKIP.
      total = total + subtotal.
      CLEAR subtotal.
    ENDIF.
    area = <break>.

    PERFORM f_color.

    IF category = 'X'.
      WRITE: /001    work-catgdesc.
      WRITE:  020    work-area.
      WRITE:  038    work-desc(30).

      WRITE:  070     work-pernr.
      WRITE:  080     work-ansvh.
      WRITE:  083     work-name(25).
      hrs = work-pohrs. "#EC CI_FLDEXT_OK[2610650] Kumara 01/09/2020 INC1480
      WRITE:  110(11) hrs.
      subtotal = subtotal + hrs.
      WRITE:  122     work-kostl.
      WRITE:  127     work-aflag.
      WRITE:  129     work-blart.
      IF detail IS INITIAL.
        WRITE: 132      work-budat.
        WRITE: 143      work-bldat.
        WRITE: 155      work-cpudt MM/DD/YYYY.
      ENDIF.
      WRITE:  166     work-usr03.
      WRITE:  177     work-zps_sh_tskid.
      WRITE:  188     work-zps_wrk_type.
    ELSE.
      WRITE: /006     work-area.
      WRITE:  021     work-desc(30).
      WRITE:  057     work-pernr.
      WRITE:  067     work-ansvh.
      WRITE:  070     work-name(25).
      hrs = work-pohrs. "#EC CI_FLDEXT_OK[2610650] Kumara 01/09/2020 INC2033
      WRITE:  097(11) hrs.
      subtotal = subtotal + hrs.
      WRITE:  109     work-kostl.
      WRITE:  114     work-aflag.
      WRITE:  116     work-blart.
      IF detail IS INITIAL.
        WRITE: 119   work-budat.
        WRITE: 130   work-bldat.
        WRITE: 141   work-cpudt.
      ENDIF.
      WRITE:  152     work-usr03.
      WRITE:  163     work-zps_sh_tskid.
      WRITE:  174     work-zps_wrk_type.
    ENDIF.
  ENDLOOP.

  IF category = 'X'.
    IF area IS NOT INITIAL.
      WRITE: /006    ' '.
      WRITE AT 110    '-----------'.
      FORMAT COLOR COL_TOTAL INTENSIFIED OFF.
      WRITE: /006    ''.
      WRITE: 110(11) subtotal.
      total = total + subtotal.
    ENDIF.
    WRITE: /006    ' '.
    WRITE AT 110   '==========='.
    FORMAT COLOR COL_TOTAL INTENSIFIED ON.
    WRITE: /006    'Total'.
    WRITE: 110(11) total.

  ELSE.
    IF area IS NOT INITIAL.
      WRITE: /006    ' '.
      WRITE AT 97    '-----------'.
      FORMAT COLOR COL_TOTAL INTENSIFIED OFF.
      WRITE: /006    ''.
      WRITE: 097(11) subtotal.
      total = total + subtotal.
    ENDIF.
    WRITE: /006    ' '.
    WRITE AT 97    '==========='.
    FORMAT COLOR COL_TOTAL INTENSIFIED ON.
    WRITE: /006    'Total'.
    WRITE: 097(11) total.
  ENDIF.

ENDFORM.

*&----------------------------------------------------------------------
*&   F_EXPORT DATA
*&----------------------------------------------------------------------
FORM f_export_data.

  DATA filen(128) TYPE c.

  DATA: lv_len       TYPE i,
        lv_last_char.

  CLEAR: data_tab[], name_tab[].
  CLEAR: data_tab, name_tab, lv_len, lv_last_char.

  IF category = 'X'.
    name_tab-text = 'Charge Category'.
    APPEND name_tab.
  ENDIF.
  name_tab-text = 'Charge Object'.
  APPEND name_tab.
  name_tab-text = 'Description'.
  APPEND name_tab.
  name_tab-text = 'Emp Nbr'.
  APPEND name_tab.
  name_tab-text = 'LC'.
  APPEND name_tab.
  name_tab-text = 'Emp Name'.
  APPEND name_tab.
  name_tab-text = 'Hours'.
  APPEND name_tab.
  name_tab-text = 'Emp CC'.
  APPEND name_tab.
  name_tab-text = 'Adjust Ind'.
  APPEND name_tab.
  name_tab-text = 'Doc Type'.
  APPEND name_tab.
  name_tab-text = 'Post Date'.
  APPEND name_tab.
  name_tab-text = 'Doc Date'.
  APPEND name_tab.
  name_tab-text = 'Created'.
  APPEND name_tab.
  name_tab-text = 'Task Id'.
  APPEND name_tab.
  name_tab-text = 'Shared Task Id'.
  APPEND name_tab.
  name_tab-text = 'Work Type'.
  APPEND name_tab.

  LOOP AT work.
    IF category = 'X'.
      data_tab-text01 = work-catgdesc.
      data_tab-text02 = work-area.
      data_tab-text03 = work-desc.
      WRITE work-pernr TO data_tab-text04.
      data_tab-text05 = work-ansvh.
      data_tab-text06 = work-name.
      WRITE work-pohrs TO data_tab-text07 DECIMALS 2.
      data_tab-text08 = work-kostl.
      data_tab-text09 = work-aflag.
      data_tab-text10 = work-blart.
      WRITE work-budat TO data_tab-text11.
      WRITE work-bldat TO data_tab-text12.
      WRITE work-cpudt TO data_tab-text13.
      WRITE work-usr03 TO data_tab-text14.
      WRITE work-zps_sh_tskid TO data_tab-text15.
      WRITE work-zps_wrk_type TO data_tab-text16.
      CONDENSE: data_tab-text01,
                data_tab-text02.
      APPEND data_tab.
    ELSE.
      data_tab-text01 = work-area.
      data_tab-text02 = work-desc.
      WRITE work-pernr TO data_tab-text03.
      data_tab-text04 = work-ansvh.
      data_tab-text05 = work-name.
      WRITE work-pohrs TO data_tab-text06 DECIMALS 2.
      data_tab-text07 = work-kostl.
      data_tab-text08 = work-aflag.
      data_tab-text09 = work-blart.
      WRITE work-budat TO data_tab-text10.
      WRITE work-bldat TO data_tab-text11.
      WRITE work-cpudt TO data_tab-text12.
      WRITE work-usr03 TO data_tab-text13.
      WRITE work-zps_sh_tskid TO data_tab-text14.
      WRITE work-zps_wrk_type TO data_tab-text15.
      CONDENSE: data_tab-text01,
                data_tab-text02.
      APPEND data_tab.
    ENDIF.
  ENDLOOP.

*-------------------------------------------------------------------*
* If excel export directory name doesn't have a backslash - add it
*-------------------------------------------------------------------*
  lv_len = strlen( expdir ). lv_len = lv_len - 1.
  lv_last_char = expdir+lv_len(1).

  IF lv_last_char NE '\'.
    CONCATENATE expdir '\' INTO expdir.
  ENDIF.

  CONCATENATE expdir 'LABOR' INTO filen.
  CALL FUNCTION 'MS_EXCEL_OLE_STANDARD_DAT'
    EXPORTING
      file_name                 = filen
    TABLES
      data_tab                  = data_tab
      fieldnames                = name_tab
    EXCEPTIONS
      file_not_exist            = 1
      filename_expected         = 2
      communication_error       = 3
      ole_object_method_error   = 4
      ole_object_property_error = 5
      invalid_pivot_fields      = 6
      download_problem          = 7
      OTHERS                    = 8.

ENDFORM.

*---------------------------------------------------------------------*
*       FORM WRITE_PROJECT_HEADER
*---------------------------------------------------------------------*
FORM write_project_header.

  DATA: mgrname LIKE pa0001-ename,
        anlname LIKE pa0001-ename,
        invname LIKE pa0001-ename.

  CALL FUNCTION 'CONVERSION_EXIT_KONPR_INPUT'
    EXPORTING
      input     = area2
    IMPORTING
      prpswa    = prps
    EXCEPTIONS
      not_found = 1
      OTHERS    = 2.

  IF sy-subrc = 0.
    SELECT SINGLE *
      FROM proj
     WHERE pspnr = prps-psphi.
    SELECT SINGLE *
      FROM pa0001
     WHERE pernr  = prps-vernr
       AND begda <= sy-datum
       AND endda >= sy-datum.
    IF sy-subrc = 0.
      mgrname = pa0001-ename.
    ENDIF.
    SELECT SINGLE *
      FROM pa0001
     WHERE pernr  = prps-cont_invoicer
       AND begda <= sy-datum
       AND endda >= sy-datum.
    IF sy-subrc = 0.
      invname = pa0001-ename.
    ENDIF.
    SELECT SINGLE *
      FROM pa0001
     WHERE pernr  = prps-yyanlystr
       AND begda <= sy-datum
       AND endda >= sy-datum.
    IF sy-subrc = 0.
      anlname = pa0001-ename.
    ENDIF.
    SELECT SINGLE *
      FROM tcn7t
     WHERE langu = sy-langu
       AND nprio = prps-pspri.
    IF sy-subrc <> 0.
      CLEAR tcn7t.
    ENDIF.
    IF category = 'X'.
      PERFORM write_category_header.
    ELSE.
      WRITE /006 'Project Mgr: '.
      WRITE  019 mgrname.
      WRITE  098 'Proj Title : '.
      WRITE  111 prps-post1.
      WRITE /006 'Analyst    : '.
      WRITE  019 anlname.
      WRITE  098 'Priority   : '.
      WRITE  111 tcn7t-ktext.
      WRITE /006 'Invoicer   : '.
      WRITE  019 invname.
      WRITE  098 'Cont Start : '.
      WRITE  111 proj-plfaz.
      WRITE /006 'Mgr CCtr   : '.
      WRITE  019 prps-fkstl.
      WRITE  098 'Cont End   : '.
      WRITE  111 proj-plsez.
      ULINE /006(145).

    ENDIF.

  ENDIF.

ENDFORM.

*&---------------------------------------------------------------------*
*&      Form  WRITE_CATEGORY_HEADER
*&---------------------------------------------------------------------*
FORM write_category_header.
  WRITE: /001  'Charging',
         020   'Charging'.

  WRITE /001 'Category'.
  WRITE  020 'Object'.
  WRITE  038 'Description'.
  WRITE  070 'Emp Nbr'.
  WRITE  080 'LC'.
  WRITE  083 'Name'.
  WRITE  110 '     Hours '.
  WRITE  122 'Dept'.
  WRITE  127 'A'.
  WRITE  129 'DT'.
  WRITE  132 'Post Date'.
  WRITE  143 'Doc Date'.
  WRITE  155 'Created On'.
  WRITE  166 'Task Id'.
  WRITE  177 'Sha Tsk Id'.
  WRITE  188 'Work Type'.
  FORMAT RESET.
  ULINE /001(197).

ENDFORM.

*&---------------------------------------------------------------------*
*&      Form  GET_CHARGE_OBJECT_CATEGORY
*&---------------------------------------------------------------------*
FORM get_charge_object_category USING control_area
                                      wbs
                                      order
                                      costcenter
                                      emp_ba
                                      pdate
                                CHANGING indicator
                                         catg1
                                         catg1desc
                                         catg2
                                         catg2desc
                                         busarea.

  CALL FUNCTION 'Z_GET_CHARGE_OBJECT_CATEGORY'
    EXPORTING
      controlling_area       = control_area
      wbs_element_charged    = wbs
      internal_order_charged = order
      cost_center_charged    = costcenter
      employee_bus_area      = emp_ba
      post_date              = pdate
    IMPORTING
      indicator              = indicator
      category1              = catg1
      category1_desc         = catg1desc
      category2              = catg2
      category2_desc         = catg2desc
      cross_ba_ind           = busarea
    TABLES
      return                 = tab_return.

ENDFORM.

*&---------------------------------------------------------------------*
*&  Form  FORMAT_REPORT_HEADING
*&---------------------------------------------------------------------*
FORM format_report_heading.

  CALL FUNCTION 'Z_ESRI_HEADING'
    EXPORTING
      line_size = sy-linsz
      heading1  = 'Project and Task Labor Report '
      heading2  = datehdr.

ENDFORM.

*&---------------------------------------------------------------------*
*&      Form  GET_BUSAREA_COSTCENTER
*&---------------------------------------------------------------------*
FORM get_busarea_costcenter.
  CLEAR dept1.
  CLEAR dept1[].
  SELECT * FROM pa0001
  WHERE gsber IN empba
   AND begda LE date1-low
   AND endda GE date1-low.

    dept1-sign   = 'I'.
    dept1-option = 'EQ'.
    dept1-low    = pa0001-kostl.

    COLLECT dept1.
  ENDSELECT.

ENDFORM.

*---------------------------------------------------------------------*
*       FORM KCCA_AUTH_CHECK
*---------------------------------------------------------------------*
FORM kcca_auth_check.

  auth_ind = 'Y'.
  CALL FUNCTION 'COBE_REPO_AUTHORITY_CHECK'
    EXPORTING
      kokrs               = '0001'
      objnr               = cctr_chk
      kstar               = '0000600500'
      actvt               = '28'
    EXCEPTIONS
      user_not_authorized = 1.
  IF sy-subrc <> 0.
    CALL FUNCTION 'COBE_REPO_AUTHORITY_CHECK'
      EXPORTING
        kokrs               = '0001'
        objnr               = cctr_chk
        kstar               = '0000600500'
        actvt               = '27'
      EXCEPTIONS
        user_not_authorized = 1.
    IF sy-subrc <> 0.
      auth_ind = 'N'.
    ENDIF.
  ENDIF.

ENDFORM.

*---------------------------------------------------------------------*
*       FORM ORDER_AUTH_CHECK
*---------------------------------------------------------------------*
FORM order_auth_check.

  auth_ind = 'Y'.
  CALL FUNCTION 'COBE_REPO_AUTHORITY_CHECK'
    EXPORTING
      kokrs               = '0001'
      objnr               = cctr_chk
      kstar               = '0000600500'
      actvt               = '28'
    EXCEPTIONS
      user_not_authorized = 1.
  IF sy-subrc <> 0.
    CALL FUNCTION 'COBE_REPO_AUTHORITY_CHECK'
      EXPORTING
        kokrs               = '0001'
        objnr               = cctr_chk
        kstar               = '0000600500'
        actvt               = '27'
      EXCEPTIONS
        user_not_authorized = 1.
    IF sy-subrc <> 0.
      auth_ind = 'N'.
    ENDIF.
  ENDIF.

ENDFORM.

*---------------------------------------------------------------------*
*       FORM PRPS_AUTH_CHECK
*---------------------------------------------------------------------*
FORM prps_auth_check.

  auth_ind = 'N'.
  AUTHORITY-CHECK OBJECT 'C_PRPS_VNR'
     ID 'PS_VERNR' FIELD prps-vernr
     ID 'PS_ACTVT' FIELD '27'.
  IF sy-subrc = 0.
    auth_ind = 'Y'.
  ELSE.
    AUTHORITY-CHECK OBJECT 'C_PRPS_VNR'
       ID 'PS_VERNR' FIELD prps-vernr
       ID 'PS_ACTVT' FIELD '28'.
    IF sy-subrc = 0.
      auth_ind = 'Y'.
    ENDIF.
  ENDIF.
  IF auth_ind = 'N'.
    AUTHORITY-CHECK OBJECT 'C_PRPS_KST'
       ID 'PS_FKOKR' FIELD '0001'
       ID 'PS_FKSTL' FIELD prps-fkstl
       ID 'PS_ACTVT' FIELD '27'.
    IF sy-subrc = 0.
      auth_ind = 'Y'.
    ELSE.
      AUTHORITY-CHECK OBJECT 'C_PRPS_KST'
         ID 'PS_FKOKR' FIELD '0001'
         ID 'PS_FKSTL' FIELD prps-fkstl
         ID 'PS_ACTVT' FIELD '28'.
      IF sy-subrc = 0.
        auth_ind = 'Y'.
      ENDIF.
    ENDIF.
  ENDIF.
  IF auth_ind = 'Y'.
    AUTHORITY-CHECK OBJECT 'C_PRPS_ART'
       ID 'PS_PRART' FIELD prps-prart
       ID 'PS_ACTVT' FIELD '27'.
    IF sy-subrc <> 0.
      AUTHORITY-CHECK OBJECT 'C_PRPS_ART'
         ID 'PS_PRART' FIELD prps-prart
         ID 'PS_ACTVT' FIELD '28'.
      IF sy-subrc <> 0.
        auth_ind = 'N'.
      ENDIF.
    ENDIF.
  ENDIF.
  IF auth_ind = 'N'.
    projchk = prps-posid(6).
    AUTHORITY-CHECK OBJECT 'ZPROJECT'
       ID 'ACTVT'   FIELD '03'
       ID 'PROJECT' FIELD projchk.
    IF sy-subrc = 0.
      auth_ind = 'Y'.
    ENDIF.
  ENDIF.

ENDFORM.

*&-------------------------------------------------------------------*
*&      Form  SAVE_DATA_TO_DB
*&-------------------------------------------------------------------*
FORM save_data_to_db.
  DATA: it_lbr TYPE zps_actual_labor OCCURS 0,
        wa_lbr LIKE LINE OF it_lbr.

  LOOP AT work.
    wa_lbr-zvariant = sy-slset.
    wa_lbr-seqnr    = sy-tabix.
    WRITE work-area TO wa_lbr-chrgobj.
    wa_lbr-descrip  = work-desc.
    WRITE work-pernr TO wa_lbr-pernr.
    wa_lbr-ansvh    = work-ansvh.
    wa_lbr-ename    = work-name.
    wa_lbr-lbrhrs   = work-pohrs. "#EC CI_FLDEXT_OK[2610650] KUmara 01/09/2020 INC1481
* Avoid leading zeros for cost center (Cherwell Incident Number 109595)
    CALL FUNCTION 'CONVERSION_EXIT_ALPHA_OUTPUT'
      EXPORTING
        input  = work-kostl
      IMPORTING
        output = wa_lbr-kostl.
    wa_lbr-adjind         = work-aflag.
    wa_lbr-blart          = work-blart.
    wa_lbr-budat          = work-budat.
    wa_lbr-bldat          = work-bldat.
    wa_lbr-cpudt          = work-cpudt.
    wa_lbr-erdat          = sy-datum.
    wa_lbr-erzet          = sy-uzeit.
    wa_lbr-ernam          = sy-uname.
    wa_lbr-chrcategory    = work-catgdesc.
    wa_lbr-usr03          = work-usr03.
    wa_lbr-zps_sh_tskid   = work-zps_sh_tskid.
    wa_lbr-zps_wrk_type   = work-zps_wrk_type.
    APPEND wa_lbr TO it_lbr.
  ENDLOOP.

*-- Delete existing data from ZPS_ACTUAL_LABOR
  DELETE FROM zps_actual_labor WHERE zvariant = sy-slset.

*-- Insert data into ZPS_ACTUAL_LABOR
  INSERT zps_actual_labor FROM TABLE it_lbr.

*-- Commit Work
  COMMIT WORK AND WAIT.

ENDFORM.

*&---------------------------------------------------------------------*
*&      Form  F_AT_SELECTION_SCREEN
*&---------------------------------------------------------------------*
FORM f_at_selection_screen.

  IF date1 IS INITIAL AND s_bldat IS INITIAL.
    MESSAGE e105(z1) WITH 'Payroll Date Must be entered.'.
  ELSEIF s_bldat IS NOT INITIAL AND date1 IS INITIAL.
    date1-low = s_bldat-low.
    date1-high = s_bldat-high.
  ENDIF.
  sy-tvar0       = date1-low+4(2).
  sy-tvar0+2     = '/'.
  sy-tvar0+3     = date1-low+6(2).
  sy-tvar0+5     = '/'.
  sy-tvar0+6     = date1-low+2(2).
  sy-tvar0+9     = 'to'.
  sy-tvar0+12    = date1-high+4(2).
  sy-tvar0+14    = '/'.
  sy-tvar0+15    = date1-high+6(2).
  sy-tvar0+17    = '/'.
  sy-tvar0+18    = date1-high+2(2).

  IF empba IS NOT INITIAL.
    IF pernr1 IS INITIAL AND
       dept1  IS INITIAL AND
       posnr1 IS INITIAL AND
       mgrcc  IS INITIAL AND
       gsber  IS INITIAL AND
       rptcc  IS INITIAL.
      PERFORM get_busarea_costcenter.
    ENDIF.
  ENDIF.

  IF empba  IS INITIAL AND
     pernr1 IS INITIAL AND
     gsber  IS INITIAL AND
     dept1  IS INITIAL AND
     posnr1 IS INITIAL AND
     mgrcc  IS INITIAL AND
     rptcc  IS INITIAL.
    MESSAGE e105(z1) WITH 'Please enter some report limits.'.
  ENDIF.

  IF pernr1 IS NOT INITIAL.
    CLEAR dept1.
    CLEAR dept1[].
    SELECT kostl
      INTO pa0001-kostl
      FROM pa0001
     WHERE pernr IN pernr1.
      dept1-sign   = 'I'.
      dept1-option = 'EQ'.
      dept1-low    = pa0001-kostl.
      COLLECT dept1.
    ENDSELECT.
  ENDIF.

ENDFORM.

*&---------------------------------------------------------------------*
*&      Form  F_AT_SELECTION_SCREEN_OUTPUT
*&---------------------------------------------------------------------*
FORM f_at_selection_screen_output.
* Defect # - 46 - Getting "Unauthorized" message when using ZPR1
  AUTHORITY-CHECK OBJECT 'ZPGM_ACT'
       ID 'REPID' FIELD 'ZCOR_PROJTASK_LABOR_TEMP'
       ID 'ACTVT' FIELD '03'.
  IF sy-subrc NE 0.
    LOOP AT SCREEN.
      IF screen-name = 'P_SAVE' OR
         screen-name = '%_P_SAVE_%_APP_%-TEXT'.
        screen-input = 0.
        screen-invisible = 1.
        MODIFY SCREEN.
      ENDIF.
    ENDLOOP.
  ENDIF.

ENDFORM.

*&---------------------------------------------------------------------*
*&      Form  F_TOP_OF_PAGE
*&---------------------------------------------------------------------*
FORM f_top_of_page.

  CLEAR: datea, dateb, datehdr.
  IF category = 'X'.
    sy-linsz = '197'.
  ELSE.
    sy-linsz = '182'.
  ENDIF.
  WRITE: date1-low  MM/DD/YYYY TO datea.
  WRITE: date1-high MM/DD/YYYY TO dateb.

  CONCATENATE 'Payroll Date ' datea 'to' dateb
  INTO datehdr SEPARATED BY space.

  PERFORM format_report_heading.

  IF rpt_type = 1 AND paging = 'X'.
    PERFORM write_project_header.
  ENDIF.
  WRITE /001 '     '.
  FORMAT COLOR 1 INTENSIFIED ON.

  IF category = 'X'.
    PERFORM write_category_header.
  ELSE.
    WRITE  006 'WBS/Int. Order'.
    WRITE  028 'Description'.
    WRITE  057 'Emp Nbr'.
    WRITE  067 'LC'.
    WRITE  070 'Name'.
    WRITE  097 '     Hours '.
    WRITE  109 'EmCC'.
    WRITE  114 'A'.
    WRITE  116 'DT'.
    WRITE  119 'Post Date'.
    WRITE  130 'Doc Date'.
    WRITE  141 'Created On'.
    WRITE  152 'Task Id'.
    WRITE  163 'Sha Tsk Id'.
    WRITE  174 'Work Type'.
    FORMAT RESET.
    ULINE /006(177).
  ENDIF.
  page1 = page1 + 1.

ENDFORM.

*&---------------------------------------------------------------------*
*&      Form  F_TOP_OF_PAGE_LINE_SELECT
*&---------------------------------------------------------------------*
FORM f_top_of_page_line_select.

  CLEAR: datea, dateb, datehdr.

  WRITE: date1-low  MM/DD/YYYY TO datea.
  WRITE: date1-high MM/DD/YYYY TO dateb.

  CONCATENATE 'Payroll Date ' datea 'to' dateb
  INTO datehdr SEPARATED BY space.

  PERFORM format_report_heading.

  WRITE /001 '     '.
  FORMAT COLOR 1 INTENSIFIED ON.

  IF category = 'X'.
    PERFORM write_category_header.
  ELSE.
    WRITE  006 'WBS/Int. Order'.
    WRITE  028 'Description'.
    WRITE  057 'Emp Nbr'.
    WRITE  067 'LC'.
    WRITE  070 'Name'.
    WRITE  097 '     Hours '.
    WRITE  109 'EmCC'.
    WRITE  114 'A'.
    WRITE  116 'DT'.
    WRITE  119 'Post Date'.
    WRITE  130 'Doc Date'.
    WRITE  141 'Created On'.
    WRITE  152 'Task Id'.
    WRITE  163 'Sha Tsk Id'.
    WRITE  174 'Work Type'.
    FORMAT RESET.
    ULINE /006(177).
  ENDIF.
  page2 = page2 + 1.

ENDFORM.

*&---------------------------------------------------------------------*
*&      Form  F_INIT_ONE
*&---------------------------------------------------------------------*
FORM f_init_one.

  SET PF-STATUS 'LISTGUI'.
  page1  = 1.
  oldind = ' '.
*   1. SELECT DATA USING OLD LABOR POSTING METHOD
  CLEAR tab_values[].
  CLEAR tab_values.
  IF date1-low < '20030101'.
    oldind = 'X'.
  ENDIF.
  tab_values-field  = 'GJAHR'.
  tab_values-sign   = 'I'.
  IF date1-low(4) = date1-high(4).
    tab_values-option = 'EQ'.
  ELSE.
    tab_values-option = 'BT'.
    tab_values-high   = date1-high(4).
  ENDIF.
  tab_values-low    = date1-low(4).
  APPEND tab_values.
  CLEAR tab_values.
  tab_values-field  = 'LEDNR'.
  tab_values-sign   = 'I'.
  tab_values-option = 'EQ'.
  tab_values-low    = '00'.
  APPEND tab_values.
  tab_values-field  = 'VERSN'.
  tab_values-sign   = 'I'.
  tab_values-option = 'EQ'.
  tab_values-low    = '000'.
  APPEND tab_values.
  tab_values-field  = 'WRTTP'.
  tab_values-sign   = 'I'.
  tab_values-option = 'EQ'.
  tab_values-low    = '04'.
  APPEND tab_values.

  IF NOT ( posnr1 IS INITIAL AND gsber IS INITIAL ).
    tab_values-field  = 'WRTTP'.
    tab_values-sign   = 'I'.
    tab_values-option = 'EQ'.
    tab_values-low    = '11'.
    APPEND tab_values.
  ENDIF.

*BABAA on 11/27/2023 STSK0070517 Add document date to the ZRP1 report
  IF s_bldat[] IS NOT INITIAL.
    IF s_bldat-high IS INITIAL.
      tab_values-field  = 'BLDAT'.
      tab_values-sign   = 'I'.
      tab_values-option = 'EQ'.
      tab_values-low    = s_bldat-low.
      tab_values-high   = s_bldat-low.
      APPEND tab_values.
    ELSE.
      tab_values-field  = 'BLDAT'.
      tab_values-sign   = 'I'.
      tab_values-option = 'BT'.
      tab_values-low    = s_bldat-low.
      tab_values-high   = s_bldat-high.
      APPEND tab_values.
    ENDIF.
  ENDIF.

  tab_values-field  = 'KSTAR'.
  tab_values-sign   = 'I'.
  tab_values-option = 'BT'.
  tab_values-low    = '0000600100'.
  tab_values-high   = '0000600103'.
  APPEND tab_values.
  CLEAR tab_values.
  CLEAR found.

ENDFORM.

*&---------------------------------------------------------------------*
*&      Form  f_process_method_one
*&---------------------------------------------------------------------*
FORM f_process_method_one.

  method = 1.

  DATA: lv_subrc TYPE sy-subrc.
  CLEAR lv_subrc.

  PERFORM check_object_selection.

  IF found <> 'X'.
    MESSAGE e105(z1) WITH 'No valid or authorized object supplied'.
  ENDIF.
  CLEAR postab[].

  CALL FUNCTION 'Z_COVP_READ_MULTI_NEW'
    TABLES
      it_cosel = tab_values
      et_covp  = postab.

  IF postab[] IS NOT INITIAL.
    SELECT pernr ansvh ename gsber
      FROM pa0001
      INTO CORRESPONDING FIELDS OF TABLE it_pa0001
      FOR ALL ENTRIES IN postab
         WHERE pernr    EQ postab-pernr
           AND endda    GE postab-budat
           AND begda    LE postab-budat.
  ENDIF.
  SORT it_pa0001 BY pernr.
  LOOP AT postab.
    CHECK postab-bukrs IN comp.
    IF gsber IS NOT INITIAL.
      CHECK postab-gsber IN gsber.
    ENDIF.

    CHECK postab-mbgbtr <> 0.
    CLEAR work. CLEAR lv_subrc.

    MOVE-CORRESPONDING postab TO work.
    CHECK work-budat IN date1.
    work-kostl = postab-uspob+5(11).
    IF postab-belnr LT '0060000000' OR
       postab-belnr GE '0070000000'.
      IF postab-pernr = 0.
        postab-pernr = postab-uspob+15(5).
        work-pernr = postab-pernr.
        work-aflag = 'X'.
      ELSE.
        IF postab-belnr LT '0900000000'.
          work-aflag = 'X'.
        ELSE.
          work-aflag = ' '.
        ENDIF.
      ENDIF.
      IF trans <> 'X'.
        CHECK work-aflag = ' '.
      ENDIF.
      IF postab-pernr IS NOT INITIAL.
        READ TABLE it_pa0001 WITH KEY pernr = postab-pernr BINARY SEARCH.
        IF sy-subrc = 0.
          IF empba IS NOT INITIAL.
            CHECK it_pa0001-gsber IN empba.
          ENDIF.
          work-name  = it_pa0001-ename.
          work-ansvh = it_pa0001-ansvh.
        ENDIF.
      ELSE.
        IF empba IS NOT INITIAL.
          CHECK 1 = 2.
        ENDIF.
      ENDIF.

      CHECK postab-pernr IN pernr1.

      IF posnr1 IS INITIAL AND
         gsber  IS INITIAL AND
         mgrcc  IS INITIAL AND
         rptcc  IS INITIAL.
        IF postab-objnr_n1 IS NOT INITIAL.
          work-area = postab-objnr_n1.

          PERFORM f_objnr_dependent_data_01 USING postab-objnr_n1(2)
                                               postab-objnr_n1+2(8)
                                               postab-objnr_n1+2(10)
                                               postab-objnr_n1+6(10)
                                               postab-budat
                                          CHANGING lv_subrc.
        ELSE.
          postab-buzei = postab-buzei - 1.
          SELECT SINGLE objnr INTO coep-objnr FROM coep
           WHERE kokrs   = postab-kokrs
             AND belnr   = postab-belnr
             AND buzei   = postab-buzei.

          PERFORM f_objnr_dependent_data_01 USING coep-objnr(2)
                                               coep-objnr+2(8)
                                               coep-objnr+2(10)
                                               coep-objnr+6(10)
                                               postab-budat
                                         CHANGING lv_subrc.
        ENDIF.
        work-pohrs = postab-mbgbtr * -1. "#EC CI_FLDEXT_OK[2610650] KUmara 01/09/2020 INC2035
        APPEND work.
      ELSE.
        PERFORM f_objnr_dependent_data_01 USING postab-objnr(2)
                                             postab-objnr+2(8)
                                             postab-objnr+2(10)
                                             postab-objnr+6(10)
                                             postab-budat
                                          CHANGING lv_subrc.

        postab-buzei = postab-buzei + 1.
        SELECT SINGLE * FROM coep
         WHERE kokrs     = postab-kokrs
           AND belnr     = postab-belnr
           AND buzei     = postab-buzei.
        work-pohrs = coep-mbgbtr * -1. "#EC CI_FLDEXT_OK[2610650] KUmara 01/09/2020 INC1484
        APPEND work.
      ENDIF.
    ENDIF.
  ENDLOOP.

ENDFORM.

*&---------------------------------------------------------------------*
*&      Form  F_INIT_TWO
*&---------------------------------------------------------------------*
FORM f_init_two.

*   2. SELECT DATA USING NEW LABOR POSTING METHOD
  CLEAR tab_values[].
  CLEAR tab_values.
  tab_values-field  = 'GJAHR'.
  tab_values-sign   = 'I'.
  IF date1-low(4) = date1-high(4).
    tab_values-option = 'EQ'.
  ELSE.
    tab_values-option = 'BT'.
    tab_values-high   = date1-high(4).
  ENDIF.
  tab_values-low    = date1-low(4).
  APPEND tab_values.
  CLEAR tab_values.
  tab_values-field  = 'LEDNR'.
  tab_values-sign   = 'I'.
  tab_values-option = 'EQ'.
  tab_values-low    = '00'.
  APPEND tab_values.
  tab_values-field  = 'VERSN'.
  tab_values-sign   = 'I'.
  tab_values-option = 'EQ'.
  tab_values-low    = '000'.
  APPEND tab_values.
  tab_values-field  = 'WRTTP'.
  tab_values-sign   = 'I'.
  tab_values-option = 'EQ'.
  tab_values-low    = '04'.
  APPEND tab_values.
  IF NOT ( posnr1 IS INITIAL AND gsber IS INITIAL ).
    tab_values-field  = 'WRTTP'.
    tab_values-sign   = 'I'.
    tab_values-option = 'EQ'.
    tab_values-low    = '11'.
    APPEND tab_values.
  ENDIF.

*BABAA on 11/27/2023 STSK0070517 Add document date to the ZRP1 report
  IF s_bldat[] IS NOT INITIAL.
    IF s_bldat-high IS INITIAL.
      tab_values-field  = 'BLDAT'.
      tab_values-sign   = 'I'.
      tab_values-option = 'EQ'.
      tab_values-low    = s_bldat-low.
      tab_values-high   = s_bldat-low.
      APPEND tab_values.
    ELSE.
      tab_values-field  = 'BLDAT'.
      tab_values-sign   = 'I'.
      tab_values-option = 'BT'.
      tab_values-low    = s_bldat-low.
      tab_values-high   = s_bldat-high.
      APPEND tab_values.
    ENDIF.
  ENDIF.

  IF date1-low+0(4) LE '2012' AND
     date1-high+0(4) LE '2012'.
    tab_values-field  = 'KSTAR'.
    tab_values-sign   = 'I'.
    tab_values-option = 'BT'.
    tab_values-low    = '0000510000'.
    tab_values-high   = '0000510099'.
    APPEND tab_values.

    tab_values-low    = '0000511000'.
    tab_values-high   = '0000511000'.
    APPEND tab_values.
  ELSE.
    tab_values-field  = 'KSTAR'.
    tab_values-sign   = 'I'.
    tab_values-option = 'BT'.
    tab_values-low    = '0000500000'.
    tab_values-high   = '0000510099'.
    APPEND tab_values.

    tab_values-low    = '0000511000'.
    tab_values-high   = '0000511010'.
    APPEND tab_values.
  ENDIF.
  tab_values-low    = '0000600500'.
  tab_values-high   = '0000600600'.
  APPEND tab_values.
  CLEAR tab_values.

ENDFORM.

*&---------------------------------------------------------------------*
*&      Form  F_PROCESS_METHOD_TWO
*&---------------------------------------------------------------------*
FORM f_process_method_two.

  method = 2.

  DATA: lv_subrc TYPE sy-subrc.
  CLEAR lv_subrc.

  PERFORM check_object_selection.

  IF found <> 'X'.
    MESSAGE e105(z1) WITH 'No valid or authorized object supplied'.
  ENDIF.

  CLEAR postab[].

  CALL FUNCTION 'Z_COVP_READ_MULTI_NEW'
    TABLES
      it_cosel = tab_values
      et_covp  = postab.

  DELETE postab WHERE NOT bukrs IN comp.
  DELETE postab WHERE NOT pernr IN pernr1.

  lt_postab[] = postab[].

  DELETE lt_postab WHERE zname2 IS NOT INITIAL.

  IF postab[] IS NOT INITIAL.

*Begin of modification by Davisraja Pious on 03/22/2021 C #STRY0437607
    SELECT kokrs, belnr, buzei, perio, mbgbtr, lednr, objnr, gjahr,
           wrttp, versn, pernr, bukrs, refbz_fi, zname2, refbn
      FROM v_covp_wotp_view
      INTO TABLE @lt_covp_stat
      FOR ALL ENTRIES IN @postab
      WHERE kokrs  EQ @postab-kokrs
       AND  belnr  EQ @postab-belnr
       AND  perio  EQ @postab-perio
       AND  lednr  EQ @postab-lednr
       AND  objnr  IN @r_objnr_stat
       AND  gjahr  EQ @postab-gjahr
       AND  wrttp  EQ '11'
       AND  versn  EQ @postab-versn
       AND  pernr  EQ @postab-pernr
       AND  bukrs  EQ @postab-bukrs
       AND  zname2 EQ @postab-zname2
       AND  refbn  EQ @postab-refbn.
*End of modification by Davisraja Pious on 03/22/2021 C #STRY0437607
    SORT lt_covp_stat BY kokrs belnr perio lednr gjahr wrttp pernr bukrs refbz_fi zname2 refbn.

  ENDIF.

  IF lt_postab[] IS NOT INITIAL.

    LOOP AT lt_postab.

      IF lt_postab-zname2 IS INITIAL.

        r_belnr_bseg-sign   = 'I'.
        r_belnr_bseg-option = 'EQ'.
        r_belnr_bseg-low    = lt_postab-refbn.
        gt_acdoca_range-belnr = lt_postab-refbn.
        COLLECT r_belnr_bseg.
        CLEAR r_belnr_bseg.

        r_bukrs_bseg-sign   = 'I'.
        r_bukrs_bseg-option = 'EQ'.
        r_bukrs_bseg-low    = lt_postab-bukrs.
        gt_acdoca_range-rbukrs = lt_postab-bukrs.

        COLLECT r_bukrs_bseg.
        CLEAR r_bukrs_bseg.

        r_gjahr_bseg-sign   = 'I'.
        r_gjahr_bseg-option = 'EQ'.
        r_gjahr_bseg-low    = lt_postab-gjahr.
        gt_acdoca_range-gjahr = lt_postab-gjahr.

        COLLECT r_gjahr_bseg.
        CLEAR r_gjahr_bseg.

        r_buzei_bseg-sign   = 'I'.
        r_buzei_bseg-option = 'EQ'.
        r_buzei_bseg-low    = lt_postab-refbz_fi.
        gt_acdoca_range-buzei = lt_postab-refbz_fi.

        COLLECT r_buzei_bseg.
        CLEAR r_buzei_bseg.
        APPEND gt_acdoca_range.
        CLEAR gt_acdoca_range.
        IF lt_postab-objnr+0(2) = 'PR'.

          r_objnr_prps-sign   = 'I'.
          r_objnr_prps-option = 'EQ'.
          r_objnr_prps-low    = lt_postab-objnr.

          COLLECT r_objnr_prps.
          CLEAR r_objnr_prps.
        ENDIF.

      ENDIF.

    ENDLOOP.

  ENDIF.

  IF r_objnr_prps[] IS NOT INITIAL.

    SELECT pspnr
           posid
           objnr
           psphi
     FROM  prps
      INTO CORRESPONDING FIELDS OF TABLE gt_prps
      WHERE objnr IN r_objnr_prps.

  ENDIF.

  IF r_belnr_bseg[] IS NOT INITIAL.
* start of WorkFront ID 199414 Ameer 11/06/2020
    SELECT rbukrs
           belnr
           gjahr
           buzei
           zuonr
           pernr
           ukostl
           racct
       FROM acdoca
   INTO CORRESPONDING FIELDS OF TABLE gt_acdoca
FOR ALL ENTRIES IN gt_acdoca_range
      WHERE rbukrs EQ gt_acdoca_range-rbukrs
        AND belnr  EQ gt_acdoca_range-belnr
        AND gjahr  EQ gt_acdoca_range-gjahr
        AND buzei  EQ gt_acdoca_range-buzei.

  ENDIF.

  LOOP AT gt_acdoca.

    IF gt_acdoca-zuonr+0(1) = 'P' OR gt_acdoca-zuonr+0(1) = 'S' OR gt_acdoca-zuonr+0(1) = 'C'.

      lv_cnt = strlen( gt_acdoca-zuonr ).

      IF gt_acdoca-zuonr IS NOT INITIAL AND lv_cnt GT 7.

        lv_posid_in = gt_acdoca-zuonr.

        CALL FUNCTION 'CONVERSION_EXIT_ABPSN_INPUT'
          EXPORTING
            input  = lv_posid_in
          IMPORTING
            output = lv_posid_out.

        r_posid_prps-sign   = 'I'.
        r_posid_prps-option = 'EQ'.
        r_posid_prps-low    = lv_posid_out.

        COLLECT r_posid_prps.
        CLEAR: r_posid_prps, lv_posid_out, lv_posid_in.

      ENDIF.

    ENDIF.

  ENDLOOP.
* end of WorkFront ID 199414 Ameer 11/06/2020

  CLEAR: lv_cnt.

  IF r_posid_prps[] IS NOT INITIAL.

    SELECT pspnr
           posid
           objnr
           psphi
     FROM  prps
     APPENDING CORRESPONDING FIELDS OF TABLE gt_prps
      WHERE posid IN r_posid_prps.

  ENDIF.

* start of WorkFront ID 199414 Ameer 11/06/2020
  SORT gt_acdoca BY rbukrs belnr gjahr buzei pernr racct.
* end of WorkFront ID 199414 Ameer 11/06/2020

  SORT gt_prps BY posid.

  DELETE ADJACENT DUPLICATES FROM gt_prps COMPARING posid.


  LOOP AT postab.

    IF gsber IS NOT INITIAL.
      CHECK postab-gsber IN gsber.
    ENDIF.

    CHECK postab-stflg  = ' '.
    CHECK postab-stokz  = ' '.
    CHECK postab-mbgbtr <> 0.
    CLEAR work. CLEAR lv_subrc.

    MOVE-CORRESPONDING postab TO work.
    CHECK work-budat IN date1.

    IF postab-blart <> 'HR'.
      work-aflag = 'X'.
    ENDIF.

    IF trans <> 'X'.
      CHECK work-aflag = ' '.
    ENDIF.

    IF postab-pernr IS NOT INITIAL.
      SELECT SINGLE ansvh ename gsber
        INTO (pa0001-ansvh,pa0001-ename,pa0001-gsber)
        FROM  pa0001
       WHERE  pernr    =  postab-pernr
         AND  endda    GE postab-budat
         AND  begda    LE postab-budat.
      IF sy-subrc = 0.
        IF empba IS NOT INITIAL.
          CHECK pa0001-gsber IN empba.
        ENDIF.
        work-name  = pa0001-ename.
        work-ansvh = pa0001-ansvh.
      ENDIF.
    ELSE.
      IF empba IS NOT INITIAL.
        CHECK 1 = 2.
      ENDIF.
    ENDIF.

    CHECK postab-pernr IN pernr1.

    IF posnr1 IS INITIAL AND
       gsber  IS INITIAL AND
       mgrcc  IS INITIAL AND
       rptcc  IS INITIAL.
*-----------------------------------------------------------------------*
*     Skip debits docs when data is selected by cost center
*     unless the sgtxt field is 'X' indicating a negative hour posting.
*-----------------------------------------------------------------------*
      IF ( postab-beknz = 'H' AND NOT postab-sgtxt(1) = 'X' ) OR
         ( postab-beknz = 'S' AND     postab-sgtxt(1) = 'X' ).
        CHECK 1 = 1.
        CLEAR: lv_refbz_fi.
        lv_refbz_fi = postab-refbz_fi + 1.
        READ TABLE lt_covp_stat WITH KEY kokrs = postab-kokrs
                                         belnr = postab-belnr
                                         perio = postab-perio
                                         lednr = postab-lednr
                                         gjahr = postab-gjahr
                                         wrttp = '11'
                                         pernr = postab-pernr
                                         bukrs = postab-bukrs
                                         refbz_fi = lv_refbz_fi
                                         zname2 = postab-zname2
                                         refbn  = postab-refbn BINARY SEARCH.

        IF sy-subrc = 0.

          CLEAR: lv_mbgbtr.
          lv_mbgbtr = postab-mbgbtr * -1.

          IF lv_mbgbtr = lt_covp_stat-mbgbtr.
            postab-zname2 = lt_covp_stat-objnr.
          ENDIF.

        ENDIF.

      ELSE.
        CHECK 1 = 2.
      ENDIF.

      work-kostl = postab-objnr+6(10).

      IF postab-zname2 IS INITIAL.

* start of WorkFront ID 199414 Ameer 11/06/2020
        READ TABLE gt_acdoca WITH KEY rbukrs = postab-bukrs
                                      belnr = postab-refbn
                                      gjahr = postab-gjahr
                                      buzei = postab-refbz_fi
                                      pernr = postab-pernr
                                      racct = postab-kstar BINARY SEARCH.
        IF sy-subrc = 0.

          CLEAR: lv_posid.

          lv_posid = gt_acdoca-zuonr.

          CALL FUNCTION 'CONVERSION_EXIT_ABPSN_INPUT'
            EXPORTING
              input  = lv_posid
            IMPORTING
              output = lv_posid.

          READ TABLE gt_prps WITH KEY posid = lv_posid BINARY SEARCH.

          IF sy-subrc = 0.
            postab-zname2 = gt_prps-objnr.
          ELSE.
            lv_cnt = strlen( gt_acdoca-zuonr ).
            IF lv_cnt = 6.
              CONCATENATE 'OR' gt_acdoca-zuonr INTO postab-zname2.
            ELSE.
              CONCATENATE 'KS0001' gt_acdoca-zuonr INTO postab-zname2.
            ENDIF.
          ENDIF.

        ENDIF.

      ENDIF.

      PERFORM f_objnr_dependent_data_01 USING postab-zname2(2)
                                              postab-zname2+2(8)
                                              postab-zname2+2(10)
                                              postab-zname2+6(10)
                                              postab-budat
                                     CHANGING lv_subrc.

      work-pohrs = postab-mbgbtr * -1. "#EC CI_FLDEXT_OK[2610650] Kumara 01/09/2020 INC2034
      APPEND work.
    ELSE.
      PERFORM f_objnr_dependent_data_02 USING postab-objnr(2)
                                               postab-objnr+2(8)
                                               postab-objnr+2(10)
                                               postab-objnr+6(10)
                                               postab-budat
                                        CHANGING lv_subrc.

      IF lv_subrc IS INITIAL.
        work-kostl = postab-yyname1.
        work-pohrs = postab-mbgbtr. "#EC CI_FLDEXT_OK[2610650] KUmara 01/09/2020 INC2032
        APPEND work.
      ENDIF.
    ENDIF.
  ENDLOOP.

ENDFORM.

*&---------------------------------------------------------------------*
*&      Form  F_PROCESS_COMBINED_DATA
*&---------------------------------------------------------------------*
FORM f_process_combined_data.

  DELETE work WHERE NOT vernr      IN mgremp.
  DELETE work WHERE NOT analyst    IN anlemp.
  DELETE work WHERE NOT invoicer   IN invemp.
  DELETE work WHERE NOT prart      IN prart.
  DELETE work WHERE NOT usr02      IN custtyp.
  DELETE work WHERE NOT zps_pkgnum IN pkgnum.

  PERFORM f_process_wbs_attrib_selection.

  PERFORM cc_filter_work.
  PERFORM auth_filter_work.

  IF detail IS NOT INITIAL.
    PERFORM f_summarize_by_employee.
  ENDIF.

  PERFORM f_sort_report.

  IF p_save IS NOT INITIAL.
    PERFORM save_data_to_db.
  ENDIF.
ENDFORM.

*&---------------------------------------------------------------------*
*&      Form  F_OBJNR_PR
*&---------------------------------------------------------------------*
FORM f_objnr_pr USING p_posnr CHANGING p_subrc.

  coift-posnr       = p_posnr.
  WRITE coift-posnr TO work-area.
  work-type = '1'.

  SELECT SINGLE * FROM prps WHERE pspnr = coift-posnr AND
                                  pbukr IN comp       AND
                                  pgsbr IN gsber      AND
                                  akstl IN rptcc      AND
                                  fkstl IN mgrcc.
  IF sy-subrc = 0.
*------------------------------------------------------------------------*
* Move PRPS Data to 'Work' work area
*------------------------------------------------------------------------*
    PERFORM f_move_prps_to_work USING prps CHANGING work.

    SELECT SINGLE * FROM prps WHERE psphi = prps-psphi AND stufe = 1.
    work-fkstl = prps-fkstl.

*------------------------------------------------------------------------*
* Get WBS element charge object category description
*------------------------------------------------------------------------*
    CLEAR: order, costctr.
    PERFORM f_get_charge_obj_category_desc USING prps-posid order costctr.

    SELECT SINGLE ename INTO work-mgrna FROM pa0001
     WHERE pernr  = prps-vernr
       AND endda  GE sy-datum
       AND begda  LE sy-datum.
  ELSE.
    p_subrc = 4.
    work-desc = 'Unknown'.
    work-catgdesc = 'Cross BA Indirect'.
  ENDIF.

ENDFORM.

*&---------------------------------------------------------------------*
*&      Form  F_OBJNR_OR
*&---------------------------------------------------------------------*
FORM f_objnr_or USING p_area CHANGING p_subrc.

  work-area = p_area.
  work-type = '2'.

  SELECT SINGLE * FROM aufk WHERE aufnr = work-area AND
                                  bukrs IN comp     AND
                                  gsber IN gsber.
  IF sy-subrc = 0.
    work-desc = aufk-ktext.
    CLEAR: work-fkstl, work-wbscc, work-mgrna.

*------------------------------------------------------------------------*
* Get WBS element charge object category description
*------------------------------------------------------------------------*
    PERFORM f_get_charge_obj_category_desc USING '' aufk-aufnr ''.

  ELSE.
    p_subrc = 4.
    work-desc = 'Unknown'.
    work-catgdesc = 'Cross BA Indirect'.
  ENDIF.

ENDFORM.

*&---------------------------------------------------------------------*
*&      Form  F_OBJNR_OTHERS
*&---------------------------------------------------------------------*
FORM f_objnr_others USING p_kostl p_budat CHANGING p_subrc.

  DATA: lv_kostl LIKE csks-kostl,
        lv_text  LIKE cskt-ltext.

  CLEAR: lv_kostl, lv_text.

  l_kostl = p_kostl.
  WRITE p_kostl TO work-area.
  SHIFT work-area LEFT DELETING LEADING '0'.
  work-type = '3'.

  SELECT SINGLE a~kostl b~ltext INTO (lv_kostl, lv_text)
    FROM csks AS a INNER JOIN cskt AS b
    ON b~kokrs = a~kokrs AND
       b~kostl = a~kostl AND
       b~datbi = a~datbi
    WHERE a~kostl = l_kostl  AND
          a~datbi GE p_budat AND
          a~bukrs IN comp    AND
          a~gsber IN gsber   AND
          b~spras = sy-langu.

  IF sy-subrc = 0.
    work-desc = lv_text.
    CLEAR: work-fkstl, work-wbscc, work-mgrna.

*------------------------------------------------------------------------*
* Get WBS element charge object category description
*------------------------------------------------------------------------*
    PERFORM f_get_charge_obj_category_desc USING '' '' lv_kostl.

  ELSE.
    p_subrc = 4.
    work-desc = 'Unknown'.
    work-catgdesc = 'Cross BA Indirect'.
  ENDIF.

ENDFORM.

*&---------------------------------------------------------------------*
*&      Form  F_OBJNR_DEPENDENT_DATA_02
*&---------------------------------------------------------------------*
FORM f_objnr_dependent_data_02 USING p_objnr
                                      p_posnr
                                      p_area
                                      p_kostl
                                      p_budat
                             CHANGING p_subrc.
  CASE p_objnr.
    WHEN 'PR'.
      PERFORM f_objnr_pr USING p_posnr CHANGING p_subrc.

    WHEN 'OR'.
      PERFORM f_objnr_or USING p_area CHANGING p_subrc.

    WHEN OTHERS.
      IF postab-beknz = 'S'    AND
         postab-kstar > 600500 AND
         postab-objnr_n1 IS INITIAL.
        PERFORM f_objnr_others USING p_kostl p_budat CHANGING p_subrc.
      ELSE.
        p_subrc = 4.
      ENDIF.
  ENDCASE.

ENDFORM.

*&---------------------------------------------------------------------*
*&      Form  F_OBJNR_DEPENDENT_DATA_01
*&---------------------------------------------------------------------*
FORM f_objnr_dependent_data_01 USING p_objnr
                                     p_posnr
                                     p_area
                                     p_kostl
                                     p_budat
                            CHANGING p_subrc.
  CASE p_objnr.
    WHEN 'PR'.
      PERFORM f_objnr_pr USING p_posnr CHANGING p_subrc.

    WHEN 'OR'.
      PERFORM f_objnr_or USING p_area CHANGING p_subrc.

    WHEN OTHERS.
      PERFORM f_objnr_others USING p_kostl p_budat CHANGING p_subrc.

  ENDCASE.

ENDFORM.

*&---------------------------------------------------------------------*
*&      Form  F_MOVE_PRPS_TO_WORK
*&---------------------------------------------------------------------*
FORM f_move_prps_to_work USING    prps STRUCTURE prps
                          CHANGING work STRUCTURE work.

  work-desc       = prps-post1. CONDENSE work-desc.
  work-vernr      = prps-vernr.
  work-analyst    = prps-yyanlystr.
  work-invoicer   = prps-cont_invoicer.
  work-wbscc      = prps-fkstl.
  work-prart      = prps-prart.
  work-zps_disc   = prps-zps_disc.
  work-zps_cbug   = prps-zps_cbug.
  work-zps_qre    = prps-zps_qre.
  work-zps_unbill = prps-zps_unbill.
  work-usr02      = prps-usr02.
  work-zps_pkgnum = prps-zps_pkgnum.

  work-usr03        = prps-usr03.
  work-zps_sh_tskid = prps-zps_sh_tskid.
  work-zps_wrk_type = prps-zps_wrk_type.

ENDFORM.

*&---------------------------------------------------------------------*
*&      Form  F_GET_CHARGE_OBJ_CATEGORY_DESC
*&---------------------------------------------------------------------*
FORM f_get_charge_obj_category_desc USING p_wbs
                                          p_order
                                          p_costctr.
  CLEAR: costctr,
         indicator,
         catgy1,
         catg1desc,
         order,
         catgy2,
         catg2desc,
         busarea.

  IF category = 'X'.
    PERFORM get_charge_object_category
      USING postab-kokrs
            p_wbs
            p_order
            p_costctr
            pa0001-gsber
            postab-budat
      CHANGING indicator
               catgy1
               catg1desc
               catgy2
               catg2desc
               busarea.

    IF busarea = 'X' AND indicator = 'I'.
      work-catgdesc = 'Cross BA Indirect'.
    ELSEIF busarea = 'X' AND indicator = 'D'.
      work-catgdesc = 'Cross BA Direct'.
    ELSE.
      work-catgdesc = catg1desc.
    ENDIF.
  ENDIF.

ENDFORM.

*&---------------------------------------------------------------------*
*&      Form  F_SUMMARIZE_BY_EMPLOYEE
*&---------------------------------------------------------------------*
FORM f_summarize_by_employee.

  work1[] = work[].
  CLEAR work.
  CLEAR work[].
  SORT work1 BY type area pernr.
  LOOP AT work1.
    IF ( work-pernr <> work1-pernr AND work-pernr IS NOT INITIAL )
    OR ( work-area <> work1-area AND work-area IS NOT INITIAL ).
      work-pohrs = hrs.
      APPEND work.
      CLEAR hrs.
    ENDIF.
    hrs = hrs + work1-pohrs.
    MOVE-CORRESPONDING work1 TO work.
  ENDLOOP.
  IF work-pernr IS NOT INITIAL OR
     work-area IS NOT INITIAL.
    work-pohrs = hrs.
    APPEND work.
    CLEAR hrs.
  ENDIF.

ENDFORM.

*&---------------------------------------------------------------------*
*&      Form  F_SORT_REPORT
*&---------------------------------------------------------------------*
FORM f_sort_report.

  IF sort1 = 'X'.
    SORT work BY type area bldat.

  ELSEIF sort2 = 'X'.
    DELETE work WHERE fkstl IS INITIAL.
    SORT work BY fkstl type area pernr budat.

  ELSEIF sort3 = 'X'.
    DELETE work WHERE mgrna IS INITIAL.
    SORT work BY mgrna type area bldat pernr.

  ENDIF.

ENDFORM.

*&---------------------------------------------------------------------*
*&      Form  F_PROCESS_WBS_ATTRIB_SELECTION
*&---------------------------------------------------------------------*
FORM f_process_wbs_attrib_selection.

  LOOP AT work.
    CLEAR pflg.
    IF disc_a   IS NOT INITIAL AND
       cbug_a   IS NOT INITIAL AND
       qre_a    IS NOT INITIAL AND
       unbill_a IS NOT INITIAL.
    ELSE.
      IF work-zps_disc    = 'X' AND disc_e   = 'X'. pflg = 'E'. ENDIF.
      IF work-zps_cbug    = 'X' AND cbug_e   = 'X'. pflg = 'E'. ENDIF.
      IF work-zps_qre     = 'X' AND qre_e    = 'X'. pflg = 'E'. ENDIF.
      IF work-zps_unbill  = 'X' AND unbill_e = 'X'. pflg = 'E'. ENDIF.

      IF pflg = 'E'.
      ELSE.
        IF disc_o   IS INITIAL AND
           cbug_o   IS INITIAL AND
           qre_o    IS INITIAL AND
           unbill_o IS INITIAL.
          pflg = 'X'.
        ELSE.
          IF work-zps_disc    = 'X' AND disc_o   = 'X'.
            pflg = 'X'.
          ENDIF.
          IF work-zps_cbug    = 'X' AND cbug_o   = 'X'.
            pflg = 'X'.
          ENDIF.
          IF work-zps_qre     = 'X' AND qre_o    = 'X'.
            pflg = 'X'.
          ENDIF.
          IF work-zps_unbill  = 'X' AND unbill_o = 'X'.
            pflg = 'X'.
          ENDIF.
        ENDIF.
      ENDIF.
      IF pflg = ' ' OR pflg = 'E'.
        DELETE work INDEX sy-tabix.
      ENDIF.
    ENDIF.
  ENDLOOP.

ENDFORM.

*&---------------------------------------------------------------------*
*&      Form  F_COLOR
*&---------------------------------------------------------------------*
FORM f_color.

  IF gv_col IS INITIAL.
    gv_col = 1.
    FORMAT COLOR COL_NORMAL INTENSIFIED ON.

  ELSE.
    CLEAR gv_col.
    FORMAT COLOR COL_NORMAL INTENSIFIED OFF.

  ENDIF.
ENDFORM.

*&---------------------------------------------------------------------*
*&      Form  F_AT_LINE_SELECTION
*&---------------------------------------------------------------------*
FORM f_at_line_selection.

  page2 = 1.
  GET CURSOR FIELD f1 VALUE f2.
  ASSIGN f1 TO <field>.
  IF f1 IS NOT INITIAL.
    IF f1 CS 'CPUDT'.
      SORT work BY cpudt.
    ELSEIF f1 CS 'BLDAT'.
      SORT work BY bldat.
    ELSEIF f1 CS 'BUDAT'.
      SORT work BY budat area.
    ELSEIF f1 CS 'KOSTL'.
      SORT work BY kostl pernr.
    ELSEIF f1 CS 'HRS'.
      SORT work BY pohrs.
      ASSIGN 'WORK-POHRS' TO <field>.
    ELSEIF f1 CS 'NAME'.
      SORT work BY name.
    ELSEIF f1 CS 'PERNR'.
      SORT work BY pernr.
    ELSEIF f1 CS 'ANSVH'.
      SORT work BY ansvh.
    ELSEIF f1 CS 'CATGDESC'.
      SORT work BY catgdesc.
    ENDIF.
    PERFORM write_report1.
  ENDIF.

ENDFORM.

*&---------------------------------------------------------------------*
*&      Form  F_ADD_ETC_GLOBAL_DATA
*&---------------------------------------------------------------------*
FORM f_add_etc_global_data.

  DATA: lv_subrc LIKE sy-subrc.

  CLEAR: wa_global, work, gt_etc_global, lv_subrc.

  CLEAR: gt_etc_global[].
  CLEAR: gt_etc_global.

*----------------------------------------------------------------------*
* Get Records for the selected period
*----------------------------------------------------------------------*
  SELECT * FROM zetc_global INTO TABLE gt_etc_global
    WHERE pernr    IN pernr1     AND
          chargeno IN posnr1     AND
          begda    IN date1      AND
          lgart    = gc_reg_time AND
          stdaz    NE space.

  SORT gt_etc_global BY pernr reccount datestamp DESCENDING.
  DELETE ADJACENT DUPLICATES FROM gt_etc_global COMPARING pernr reccount.

  LOOP AT gt_etc_global INTO wa_global.
    CLEAR lv_subrc.
*----------------------------------------------------------------------*
* General Data from ETC Global Table
*----------------------------------------------------------------------*
    PERFORM f_general_data_global USING wa_global CHANGING lv_subrc.
    CHECK lv_subrc IS INITIAL.

*----------------------------------------------------------------------*
* If the employee has charged a WBS element number.
*----------------------------------------------------------------------*
    IF wa_global-posid IS NOT INITIAL.
      PERFORM f_wbs_element_data_global USING wa_global CHANGING lv_subrc.
    ENDIF.

*----------------------------------------------------------------------*
* If the employee has charged an Internal Order
*----------------------------------------------------------------------*
    IF wa_global-aufnr IS NOT INITIAL.
      PERFORM f_objnr_dependent_data_01 USING 'OR'
                                              space
                                              wa_global-aufnr
                                              space
                                              wa_global-begda
                                        CHANGING lv_subrc.
    ENDIF.

*----------------------------------------------------------------------*
* If the employee has charged a Cost Center
*----------------------------------------------------------------------*
    IF wa_global-kostl IS NOT INITIAL.
      PERFORM f_objnr_dependent_data_01 USING 'KO'
                                              space
                                              space
                                              wa_global-kostl
                                              wa_global-begda
                                        CHANGING lv_subrc.
    ENDIF.

    IF lv_subrc IS INITIAL.
      COLLECT work.
      CLEAR: wa_global, work.
    ENDIF.

  ENDLOOP.

ENDFORM.

*&---------------------------------------------------------------------*
*&      Form  F_WBS_ELEMENT_DATA_GLOBAL
*&---------------------------------------------------------------------*
FORM f_wbs_element_data_global USING wa_global STRUCTURE zetc_global
                               CHANGING p_subrc.

  DATA: lv_pspnr LIKE prps-pspnr.

*----------------------------------------------------------------------*
* Convert the WBS element to internal format: Using Macro!
*----------------------------------------------------------------------*
  CLEAR: lv_pspnr.
  wbs_int_format wa_global-posid lv_pspnr.

*----------------------------------------------------------------------*
* Get WBS Element Master Data
*----------------------------------------------------------------------*
  SELECT SINGLE * FROM prps WHERE pspnr = lv_pspnr AND
                                  pbukr IN comp    AND
                                  pgsbr IN gsber   AND
                                  akstl IN rptcc   AND
                                  fkstl IN mgrcc.
  IF sy-subrc = 0.
    PERFORM f_objnr_dependent_data_01 USING prps-objnr(2)
                                            prps-objnr+2(8)
                                            prps-objnr+2(10)
                                            prps-objnr+6(10)
                                            wa_global-begda
                                   CHANGING p_subrc.
  ELSE.
    p_subrc = 4.
  ENDIF.

ENDFORM.

*&---------------------------------------------------------------------*
*&      Form  F_GENERAL_DATA_GLOBAL
*&---------------------------------------------------------------------*
FORM f_general_data_global USING wa_global STRUCTURE zetc_global
                            CHANGING p_subrc.

  CLEAR: work-ansvh, work-name, work-kostl.

  SELECT SINGLE ansvh ename kostl INTO (work-ansvh, work-name, work-kostl)
    FROM  pa0001  WHERE  pernr =  wa_global-pernr AND
                         endda GE wa_global-begda AND
                         begda LE wa_global-begda AND
                         gsber IN empba           AND
                         kostl IN dept1.

  IF sy-subrc = 0.
    work-pernr = wa_global-pernr.
    work-pohrs = wa_global-stdaz.
    work-budat = wa_global-begda.
    work-bldat = wa_global-begda.
    work-cpudt = wa_global-datestamp.
  ELSE.
    p_subrc = 4.
  ENDIF.

ENDFORM.

*&---------------------------------------------------------------------*
*&      Form  F_INIT
*&---------------------------------------------------------------------*
FORM f_init.

  PERFORM f_get_hdr_date.

ENDFORM.

*&---------------------------------------------------------------------*
*&      Form  F_SETUP_EMPLOYEE
*&---------------------------------------------------------------------*
FORM f_setup_employee.

  LOOP AT pernr1.
    tab_values-field  = 'PERNR'.
    tab_values-sign   = pernr1-sign.
    tab_values-option = pernr1-option.
    tab_values-low    = pernr1-low.
    tab_values-high   = pernr1-high.
    APPEND tab_values.
  ENDLOOP.

ENDFORM.

*&---------------------------------------------------------------------*
*&      Form  F_GET_HDR_DATE
*&---------------------------------------------------------------------*
FORM f_get_hdr_date.

  repname = sy-repid.

  WRITE: date1-low  MM/DD/YYYY TO datea.
  WRITE: date1-high MM/DD/YYYY TO dateb.

  CONCATENATE 'Payroll Date ' datea 'to' dateb
  INTO datehdr SEPARATED BY space.

ENDFORM.

*&---------------------------------------------------------------------*
*&      Form  F_STATISTICAL_ORDER_TYPES
*&---------------------------------------------------------------------*
FORM f_statistical_order_types.

  gr_stat_orders-sign   = 'I'.
  gr_stat_orders-option = 'EQ'.

  gr_stat_orders-low = 'ZSIO'. APPEND gr_stat_orders.

ENDFORM.

*&---------------------------------------------------------------------*
*&      Form  F_GET_AREA
*&---------------------------------------------------------------------*
FORM f_get_area USING    p_kostl
                 CHANGING p_area.

  DATA: cc_len TYPE i.

  cc_len = strlen( p_kostl ).
  CASE cc_len.
    WHEN 10.
      CONCATENATE 'KS0001'       p_kostl INTO p_area.
    WHEN 4.
      CONCATENATE 'KS0001000000' p_kostl INTO p_area.
    WHEN OTHERS.
      CONCATENATE 'KS0001'       p_kostl INTO p_area.
  ENDCASE.

ENDFORM.
