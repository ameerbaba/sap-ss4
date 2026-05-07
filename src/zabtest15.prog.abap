REPORT zcor_projtask_labor
       NO STANDARD PAGE HEADING
       LINE-SIZE 201
       LINE-COUNT 58.
*----------------------------------------------------------------------*
*This report checks k_cca for access to cost centers, k_cca for
*access to internal orders and c_prps_vnr, c_prps_kst, c_prps_art and
*zproject for access to wbs elements.
*k_cca is checked when the user request a report by department and
*when the user runs an internal order.  when a wbs element, managing
*cc, reporting cc, invoicing emp nbr, analyst emp nbr or manager emp #,
*then c_prps_vnr, c_prps_kst, c_prps_art and zproject.
*when c_prps_vnr, c_prps_kst and zproject are checked, the first
*authorization that's positive will result in giving access.  in other
*words,  if the user has access to the manager's emp nbr in c_prps_vnr,
*there's no need for them to have access in c_prsp_kst of zproject.
*Access to C_PRPS_ART is always required
*If the user just supplies the business area, then they only get the
*cost centers, internal orders or WBS elements for the business area
*that they have authorizations for in K_CCA, C_PRPS_VNR, C_PRPS_KST,
*C_PRPS_ART and ZPROJECT.
*----------------------------------------------------------------------*
* start of WorkFront ID 199414 Ameer 11/06/2020
* Developer: Ameer Patnam
* Date : 02/02/2021
* Defect # - 46 - Getting "Unauthorized" message when using ZPR1
* WorkFront ID 199414: Changed the table from bseg to acdoca
*STSK0066200:UAT Issue  : Getting  time out dump while executing T code  ZRP1_ALL
*BABAA on 06/02/2023
*----------------------------------------------------------------------*
*BABAA on 11/27/2023 STSK0070517 Add document date to the ZRP1 report
*----------------------------------------------------------------------*
* Includes
*----------------------------------------------------------------------*
INCLUDE ZABTEST15_top.     " Data Declaration
INCLUDE ZABTEST15_sele.    " Selection Screen
INCLUDE ZABTEST15_forms.

INCLUDE ZABTEST15_WIN7.
*INCLUDE z_directory_win7_tmp2.
*----------------------------------------------------------------------*
* Initialization
*----------------------------------------------------------------------*
INITIALIZATION.
  PERFORM f_initialize_variant.
  IF expdir IS INITIAL.
    SELECT SINGLE * FROM usr01
    WHERE bname = sy-uname.
    PERFORM set_default_directory CHANGING expdir.
  ENDIF.

  expdir_tmp = expdir.
  full_path = yes.
*&==================================================================*
AT SELECTION-SCREEN ON VALUE-REQUEST FOR expdir.
* replaces function 'WS_FILENAME_GET'

  type_filter = excel_all_filter.

  ASSIGN expfile_tmp TO <fl>.
  ASSIGN expdir_tmp TO <dr>.

  PERFORM browse_dir CHANGING expfile expdir.
  PERFORM reset_path USING 'expfile' expfile
                           'expdir' expdir.
  UNASSIGN: <fl>, <dr>.

  PERFORM f_init.
  PERFORM f_initialize_variant.

*----------------------------------------------------------------------*
* At Selection Screen
*----------------------------------------------------------------------*
AT SELECTION-SCREEN.
  PERFORM check_variant.
  PERFORM f_at_selection_screen.

AT SELECTION-SCREEN OUTPUT.
  PERFORM f_at_selection_screen_output.

*&----------------------------------------------------------------------
*&   TOP-OF-PAGE
*&----------------------------------------------------------------------
TOP-OF-PAGE.
  PERFORM f_top_of_page.

*&----------------------------------------------------------------------
*&   TOP-OF-PAGE DURING LINE-SELECTION
*&----------------------------------------------------------------------
TOP-OF-PAGE DURING LINE-SELECTION.
  PERFORM f_top_of_page_line_select.

*----------------------------------------------------------------------*
* At Selection Screen On Value Request
*----------------------------------------------------------------------*
* Report Layout
*----------------------------------------------------------------------*
AT SELECTION-SCREEN ON VALUE-REQUEST FOR p_vari.
  PERFORM f4_for_variant.

*----------------------------------------------------------------------*
*   AT USER COMMAND
*----------------------------------------------------------------------*
AT USER-COMMAND.

  CASE sy-ucomm.
    WHEN 'EXPO'.
      PERFORM f_export_data.
  ENDCASE.

*----------------------------------------------------------------------*
* AT LINE-SELECTION.
*----------------------------------------------------------------------*
AT LINE-SELECTION.
  PERFORM f_at_line_selection.

*----------------------------------------------------------------------*
* Start-Of-Selection
*----------------------------------------------------------------------*
START-OF-SELECTION.
  PERFORM f_init.

*----------------------------------------------------------------------*
* Process One
*----------------------------------------------------------------------*
  PERFORM f_init_one.
  IF oldind = 'X'.
    PERFORM f_process_method_one.
  ENDIF.

*----------------------------------------------------------------------*
* Process Two
*----------------------------------------------------------------------*
  PERFORM f_init_two.
  PERFORM f_process_method_two.

*----------------------------------------------------------------------*
* Add Non-COIFT Labor Cost : Table ZETC_GLOBAL
*----------------------------------------------------------------------*
  IF date1-low+0(4) LE '2012' AND
     date1-high+0(4) LE '2012'.
    PERFORM f_add_etc_global_data.
  ENDIF.
*----------------------------------------------------------------------*
* Combined Processing of the Data
*----------------------------------------------------------------------*
  PERFORM f_process_combined_data.

*----------------------------------------------------------------------*
* Write Report
*----------------------------------------------------------------------*
  IF gcb_alv = 'X'.
    PERFORM f_display_data.
  ELSE.
    PERFORM write_report.
  ENDIF.

*&---------------------------------------------------------------------*
*&      Form  f_build_catalog
*&---------------------------------------------------------------------*
FORM f_build_catalog.
  CLEAR: gt_fieldcat.
  CLEAR gt_fieldcat[].
*----------------------------------------------------------------------*
*  1 = Fieldname
*  2 = Text (seltext_m)
*  3 = FixColumn Ind     (X)
*  4 = Output Length
*  5 = No Zero Ind       (X)
*  6 = IntType (Data Type)
*  7 = DoSum             (X)
*  8 = HotSpot Ind       (X)
*  9 = Justified (L) Left, (C) Center, (R) Right
* 10 = Leading Zero
* 11 = Key Column
*----------------------------------------------------------------------*
*                                  1        2                 3    4   5   6   7   8   9  10  11
  IF category IS NOT INITIAL.
    PERFORM f_fill_catalog USING 'CATGDESC' 'Charge Category' 'X' '08' ' ' ' ' ' ' ' ' ' ' ' ' ' '.
  ENDIF.
  PERFORM f_fill_catalog USING 'AREA'     'Charge Object'   ' ' '  ' ' ' ' ' ' ' ' ' ' ' ' ' ' '.
  PERFORM f_fill_catalog USING 'DESC'     'Description'     ' ' '  ' ' ' ' ' ' ' ' ' ' ' ' ' ' '.
  PERFORM f_fill_catalog USING 'PERNR'    'Emp Nbr'         ' ' '  ' ' ' ' ' ' ' ' ' ' ' ' ' ' '.
  PERFORM f_fill_catalog USING 'ANSVH'    'LC'              ' ' '  ' ' ' ' ' ' ' ' ' ' ' ' ' ' '.
  PERFORM f_fill_catalog USING 'NAME'     'Emp Name'        ' ' '  ' ' ' ' ' ' ' ' ' ' ' ' ' ' '.
  PERFORM f_fill_catalog USING 'POHRS'    'Hours'           ' ' '  ' ' ' ' ' 'X' ' ' ' ' ' ' ' '.
  PERFORM f_fill_catalog USING 'KOSTL'    'Emp CC'          ' ' '  ' ' ' ' ' ' ' ' ' ' ' ' ' ' '.
  PERFORM f_fill_catalog USING 'AFLAG'    'Adjust Ind'      ' ' '  ' ' ' ' ' ' ' ' ' ' ' ' ' ' '.
  PERFORM f_fill_catalog USING 'BLART'    'Doc Type'        ' ' '  ' ' ' ' ' ' ' ' ' ' ' ' ' ' '.
  PERFORM f_fill_catalog USING 'BUDAT'    'Post Date'       ' ' '  ' ' ' ' ' ' ' ' ' ' ' ' ' ' '.
  PERFORM f_fill_catalog USING 'BLDAT'    'Doc Date'        ' ' '  ' ' ' ' ' ' ' ' ' ' ' ' ' ' '.
  PERFORM f_fill_catalog USING 'CPUDT'    'Created'         ' ' '  ' ' ' ' ' ' ' ' ' ' ' ' ' ' '.
  PERFORM f_fill_catalog USING 'USR03'    'Task Id'         ' ' '  ' ' ' ' ' ' ' ' ' ' ' ' ' ' '.
  PERFORM f_fill_catalog USING 'ZPS_SH_TSKID' 'Sha Tsk Id' ' ' '  ' ' ' ' ' ' ' ' ' ' ' ' ' ' '.
  PERFORM f_fill_catalog USING 'ZPS_WRK_TYPE' 'Work Type'   ' ' '  ' ' ' ' ' ' ' ' ' ' ' ' ' ' '.

ENDFORM.
*&---------------------------------------------------------------------*
*&      Form  f_fill_catalog
*&---------------------------------------------------------------------*
FORM f_fill_catalog USING VALUE(p_fieldname)
                          VALUE(p_text)
                          VALUE(p_fixcol)
                          VALUE(p_outlen)
                          VALUE(p_nozero)
                          VALUE(p_inttype)
                          VALUE(p_dosum)
                          VALUE(p_hotspot)
                          VALUE(p_just)
                          VALUE(p_lzero)
                          VALUE(p_keycol).

  DATA: ls_fieldcat TYPE slis_fieldcat_alv.

  gv_pos = gv_pos + 1.

  CLEAR ls_fieldcat.
  ls_fieldcat-fieldname  = p_fieldname.
  ls_fieldcat-col_pos    = gv_pos.
  ls_fieldcat-seltext_m  = p_text.
  ls_fieldcat-fix_column = p_fixcol.
  ls_fieldcat-outputlen  = p_outlen.
  ls_fieldcat-no_zero    = p_nozero.
  ls_fieldcat-inttype    = p_inttype.
  ls_fieldcat-do_sum     = p_dosum.
  ls_fieldcat-hotspot    = p_hotspot.
  ls_fieldcat-just       = p_just.
  ls_fieldcat-lzero      = p_lzero.
  ls_fieldcat-key        = p_keycol.

  APPEND ls_fieldcat TO gt_fieldcat.

ENDFORM.
*&---------------------------------------------------------------------*
*&      Form  f_build_layout
*&---------------------------------------------------------------------*
FORM f_build_layout.

  CLEAR: gs_layout.

  gs_layout-zebra             = 'X'.
  gs_layout-colwidth_optimize = 'X'.

ENDFORM.
*&---------------------------------------------------------------------*
*&      Form  f_initialize_variant
*&---------------------------------------------------------------------*
FORM f_initialize_variant.
  g_save = 'A'.
  CLEAR g_variant.
  g_variant-report   = sy-repid.
  g_variant-username = sy-uname.
  g_variant-handle   = '1'.
  gx_variant         = g_variant.

  CALL FUNCTION 'REUSE_ALV_VARIANT_DEFAULT_GET'
    EXPORTING
      i_save     = g_save
    CHANGING
      cs_variant = gx_variant
    EXCEPTIONS
      not_found  = 2.
  IF sy-subrc = 0.
    p_vari = gx_variant-variant.
  ENDIF.

ENDFORM.
*&---------------------------------------------------------------------*
*&      Form  check_variant
*&---------------------------------------------------------------------*
FORM check_variant.
  IF p_vari IS NOT INITIAL.
    gx_variant = g_variant.
    gx_variant-variant = p_vari.
    CALL FUNCTION 'REUSE_ALV_VARIANT_EXISTENCE'
      EXPORTING
        i_save     = g_save
      CHANGING
        cs_variant = gx_variant.
    g_variant = gx_variant.
  ELSE.
    PERFORM f_initialize_variant.
  ENDIF.

ENDFORM.

*&---------------------------------------------------------------------*
*&      Form  f4_for_variant
*&---------------------------------------------------------------------*
FORM f4_for_variant.
  CALL FUNCTION 'REUSE_ALV_VARIANT_F4'
    EXPORTING
      is_variant = g_variant
      i_save     = g_save
    IMPORTING
      e_exit     = g_exit
      es_variant = gx_variant
    EXCEPTIONS
      not_found  = 2.
  IF sy-subrc = 2.
    MESSAGE ID sy-msgid TYPE 'S' NUMBER sy-msgno
            WITH sy-msgv1 sy-msgv2 sy-msgv3 sy-msgv4.
  ELSE.
    IF g_exit = space.
      p_vari = gx_variant-variant.
    ENDIF.
  ENDIF.

ENDFORM.
*&---------------------------------------------------------------------*
*&      Form  F_DISPLAY_DATA
*&---------------------------------------------------------------------*
FORM f_display_data.

  PERFORM f_build_catalog.
  PERFORM f_build_layout.
  PERFORM f_build_header.
  PERFORM f_build_events.
  PERFORM f_build_sort.

  PERFORM f_show_output.

ENDFORM.
*&---------------------------------------------------------------------*
*&      Form  F_BUILD_EVENTS
*&---------------------------------------------------------------------*
FORM f_build_events.

  CONSTANTS: c_formname_top_of_page TYPE slis_formname VALUE
  'TOP_OF_PAGE'.

  DATA: ls_event TYPE slis_alv_event.

  CLEAR: gt_events, ls_event.
  CLEAR gt_events[].

  CALL FUNCTION 'REUSE_ALV_EVENTS_GET'
    EXPORTING
      i_list_type     = 4
    IMPORTING
      et_events       = gt_events
    EXCEPTIONS
      list_type_wrong = 0
      OTHERS          = 0.

  READ TABLE gt_events INTO ls_event
  WITH KEY name = slis_ev_top_of_page.

  IF sy-subrc = 0.
    ls_event-form = c_formname_top_of_page.
    MODIFY gt_events FROM ls_event INDEX sy-tabix.
  ENDIF.

ENDFORM.
*---------------------------------------------------------------------*
*       FORM TOP_OF_PAGE
*---------------------------------------------------------------------*
FORM top_of_page.

  DATA: l_list_header LIKE LINE OF gt_list_top_of_page,
        l_info TYPE slis_entry.

  IF sy-ucomm = 'PRIN' OR
     sy-ucomm = '&RNT_PREV'.
*---------------------------------------------------------------------*
* Use the Following for List Display
*---------------------------------------------------------------------*
    READ TABLE gt_list_top_of_page INTO l_list_header WITH KEY typ = 'H'.
    CALL FUNCTION 'Z_ESRI_HEADING'
      EXPORTING
        line_size = sy-linsz
        heading1  = l_list_header-info
        heading2  = datehdr.
  ELSE.
*---------------------------------------------------------------------*
* Use the Following for Grid Display
*---------------------------------------------------------------------*
    CALL FUNCTION 'REUSE_ALV_COMMENTARY_WRITE'
      EXPORTING
        i_logo             = 'ENJOYSAP_LOGO'
        it_list_commentary = gt_list_top_of_page.
  ENDIF.
ENDFORM.
*&---------------------------------------------------------------------*
*&      Form  F_BUILD_HEADER
*&---------------------------------------------------------------------*
FORM f_build_header.

  DATA: ls_line TYPE slis_listheader.

  DATA: date1(10), info(40), l_time(8), l_system TYPE sy-sysid.

  CLEAR: gt_list_top_of_page.
  CLEAR gt_list_top_of_page[].

*----------------------------------------------------------------------*
* Main Header:
*----------------------------------------------------------------------*
  PERFORM f_add_to_header USING 'H' text-id1.

*----------------------------------------------------------------------*
* Log Time/Date/User Details
*----------------------------------------------------------------------*
  WRITE: sy-datum MM/DD/YYYY TO date1. CLEAR info.
  CONCATENATE 'Run Date:' date1 INTO info SEPARATED BY space.
  PERFORM f_add_to_header USING 'S' info.

  WRITE: sy-uzeit TO l_time. CLEAR info.
  CONCATENATE 'Run Time:' l_time INTO info SEPARATED BY space.
  PERFORM f_add_to_header USING 'S' info.

  CLEAR info.
  CONCATENATE 'User ID:' sy-uname INTO info SEPARATED BY space.
  PERFORM f_add_to_header USING 'S' info.

  WRITE: sy-sysid TO l_system. CLEAR: info.
  CONCATENATE 'SAP System:' l_system INTO info SEPARATED BY space.
  PERFORM f_add_to_header USING 'S' info.

*----------------------------------------------------------------------*
* Italicised Text
*----------------------------------------------------------------------*
  PERFORM f_add_to_header USING 'A' datehdr.

  PERFORM f_add_to_header USING 'S' ' '.

ENDFORM.
*&---------------------------------------------------------------------*
*&      Form  f_add_to_header
*&---------------------------------------------------------------------*
FORM f_add_to_header USING VALUE(p_typ)
                           p_text.

  DATA: ls_line TYPE slis_listheader.

  ls_line-typ  = p_typ.
  ls_line-info = p_text.
  APPEND ls_line TO gt_list_top_of_page.

ENDFORM.
*&---------------------------------------------------------------------*
*&      Form  F_BUILD_SORT
*&---------------------------------------------------------------------*
FORM f_build_sort.
*----------------------------------------------------------------------*
* 1 : Position
* 2 : Table Name (In CAPS)
* 3 : Fieldname  (In CAPS)
* 4 : Sort UP
* 5 : SubTotal
* 6 : Expand
*----------------------------------------------------------------------*
*                          1        2          3      4   5   6
*----------------------------------------------------------------------*
  PERFORM f_do_sort USING '01' 'WORK' 'AREA' 'X' 'X' ' '.

ENDFORM.
*&---------------------------------------------------------------------*
*&      Form  f_do_sort
*&---------------------------------------------------------------------*
FORM f_do_sort USING VALUE(p_spos)
                     VALUE(p_tablename)
                     VALUE(p_fieldname)
                     VALUE(p_up)
                     VALUE(p_subtot)
                     VALUE(p_expa).

  wa_sort-spos      = p_spos.
  wa_sort-tabname   = p_tablename.
  wa_sort-fieldname = p_fieldname.
  wa_sort-up        = p_up.
  wa_sort-subtot    = p_subtot.
  wa_sort-expa      = p_expa.
  APPEND wa_sort TO gt_sort.
  CLEAR wa_sort.

ENDFORM.
*&---------------------------------------------------------------------*
*&      Form  F_SHOW_OUTPUT
*&---------------------------------------------------------------------*
FORM f_show_output.

  DATA: lv_repid LIKE sy-repid.

  lv_repid = sy-repid.

  CALL FUNCTION 'REUSE_ALV_GRID_DISPLAY'
    EXPORTING
      i_callback_program      = lv_repid
      i_callback_user_command = 'USER_COMMAND1'
      is_layout               = gs_layout
      it_fieldcat             = gt_fieldcat[]
      it_sort                 = gt_sort[]
      i_save                  = 'A'
      is_variant              = g_variant
      it_events               = gt_events
    TABLES
      t_outtab                = work
    EXCEPTIONS
      program_error           = 1
      OTHERS                  = 2.

  IF sy-subrc <> 0.
    MESSAGE ID sy-msgid TYPE sy-msgty NUMBER sy-msgno
            WITH sy-msgv1 sy-msgv2 sy-msgv3 sy-msgv4.
  ENDIF.

ENDFORM.
*&---------------------------------------------------------------------*
*&      Form  user_command1
*&---------------------------------------------------------------------*
FORM user_command1 USING r_ucomm     LIKE sy-ucomm
                         rs_selfield TYPE slis_selfield.

  CHECK rs_selfield-value IS NOT INITIAL.

ENDFORM.
