*&---------------------------------------------------------------------*
*& Report ZABTEST14
*&---------------------------------------------------------------------*
*& Enhanced Sales Order ALV Report - OOP with CL_GUI_ALV_GRID
*& Includes: VBAP items, customer names, authorization checks,
*&           ALV grid display with full interactivity
*&---------------------------------------------------------------------*
REPORT zabtest14.

*----------------------------------------------------------------------*
* Type Definitions
*----------------------------------------------------------------------*
TYPES: BEGIN OF ty_output,
         vbeln   TYPE vbak-vbeln,
         erdat   TYPE vbak-erdat,
         ernam   TYPE vbak-ernam,
         auart   TYPE vbak-auart,
         vkorg   TYPE vbak-vkorg,
         vtweg   TYPE vbak-vtweg,
         spart   TYPE vbak-spart,
         kunnr   TYPE vbak-kunnr,
         name1   TYPE kna1-name1,
         netwr   TYPE vbak-netwr,
         waerk   TYPE vbak-waerk,
         bstnk   TYPE vbak-bstnk,
         vkbur   TYPE vbak-vkbur,
         vkgrp   TYPE vbak-vkgrp,
         posnr   TYPE vbap-posnr,
         matnr   TYPE vbap-matnr,
         arktx   TYPE vbap-arktx,
         kwmeng  TYPE vbap-kwmeng,
         vrkme   TYPE vbap-vrkme,
         netpr   TYPE vbap-netpr,
         netwr_i TYPE vbap-netwr,
       END OF ty_output.

TYPES: BEGIN OF ty_kna1,
         kunnr TYPE kna1-kunnr,
         name1 TYPE kna1-name1,
       END OF ty_kna1.

*----------------------------------------------------------------------*
* Global Data Declarations
*----------------------------------------------------------------------*
DATA: gt_output   TYPE STANDARD TABLE OF ty_output,
      gt_kna1     TYPE SORTED TABLE OF ty_kna1 WITH NON-UNIQUE KEY kunnr.

DATA: gv_vbeln TYPE vbak-vbeln,
      gv_vkorg TYPE vbak-vkorg,
      gv_kunnr TYPE vbak-kunnr,
      gv_matnr TYPE vbap-matnr.

*----------------------------------------------------------------------*
* Class Definition - Event Handler
*----------------------------------------------------------------------*
CLASS lcl_event_handler DEFINITION.
  PUBLIC SECTION.
    METHODS handle_double_click
      FOR EVENT double_click OF cl_gui_alv_grid
      IMPORTING e_row e_column es_row_no.
ENDCLASS.

CLASS lcl_event_handler IMPLEMENTATION.
  METHOD handle_double_click.
    TRY.
        DATA(ls_output) = gt_output[ e_row-index ].
        SET PARAMETER ID 'AUN' FIELD ls_output-vbeln.
        AUTHORITY-CHECK OBJECT 'S_TCODE'
          ID 'TCD' FIELD 'VA03'.
        IF sy-subrc = 0.
          CALL TRANSACTION 'VA03' AND SKIP FIRST SCREEN.
        ENDIF.
      CATCH cx_sy_itab_line_not_found.
        RETURN.
    ENDTRY.
  ENDMETHOD.
ENDCLASS.

* ALV Grid objects
DATA: go_grid     TYPE REF TO cl_gui_alv_grid,
      go_handler  TYPE REF TO lcl_event_handler,
      gt_fieldcat TYPE lvc_t_fcat,
      gs_layout   TYPE lvc_s_layo,
      gs_variant  TYPE disvariant.

*----------------------------------------------------------------------*
* Selection Screen
*----------------------------------------------------------------------*
SELECTION-SCREEN BEGIN OF BLOCK b1 WITH FRAME TITLE TEXT-001.
PARAMETERS: p_frdate TYPE vbak-erdat OBLIGATORY,
            p_todate TYPE vbak-erdat OBLIGATORY.
SELECT-OPTIONS: s_vbeln FOR gv_vbeln,
                s_vkorg FOR gv_vkorg,
                s_kunnr FOR gv_kunnr,
                s_matnr FOR gv_matnr.
PARAMETERS: p_maxrow TYPE i DEFAULT 500.
SELECTION-SCREEN END OF BLOCK b1.

*----------------------------------------------------------------------*
* Initialization
*----------------------------------------------------------------------*
INITIALIZATION.
  TEXT-001 = 'Sales Order Selection Criteria'.

*----------------------------------------------------------------------*
* Start of Selection
*----------------------------------------------------------------------*
START-OF-SELECTION.
  PERFORM f_check_authorization.
  PERFORM f_retrieve_data.
  IF gt_output IS NOT INITIAL.
    PERFORM f_build_fieldcatalog.
    PERFORM f_build_layout.
    PERFORM f_display_alv_grid.
  ENDIF.

*&---------------------------------------------------------------------*
*& Form F_CHECK_AUTHORIZATION
*&---------------------------------------------------------------------*
FORM f_check_authorization.

  DATA(lv_authorized) = abap_true.

  IF s_vkorg[] IS NOT INITIAL.
    LOOP AT s_vkorg.
      AUTHORITY-CHECK OBJECT 'V_VBAK_VKO'
        ID 'VKORG' FIELD s_vkorg-low.
      IF sy-subrc <> 0.
        lv_authorized = abap_false.
        EXIT.
      ENDIF.
    ENDLOOP.
  ELSE.
    AUTHORITY-CHECK OBJECT 'V_VBAK_VKO'
      ID 'VKORG' DUMMY.
    IF sy-subrc <> 0.
      lv_authorized = abap_false.
    ENDIF.
  ENDIF.

  IF lv_authorized = abap_false.
    MESSAGE 'No authorization for the requested sales organization.' TYPE 'E'.
  ENDIF.

ENDFORM.

*&---------------------------------------------------------------------*
*& Form F_RETRIEVE_DATA
*&---------------------------------------------------------------------*
FORM f_retrieve_data.

* Retrieve sales order header + item data via INNER JOIN
  SELECT vbak~vbeln, vbak~erdat, vbak~ernam, vbak~auart,
         vbak~vkorg, vbak~vtweg, vbak~spart, vbak~kunnr,
         vbak~netwr, vbak~waerk, vbak~bstnk, vbak~vkbur, vbak~vkgrp,
         vbap~posnr, vbap~matnr, vbap~arktx,
         vbap~kwmeng, vbap~vrkme, vbap~netpr, vbap~netwr
    FROM vbak
    INNER JOIN vbap ON vbak~vbeln = vbap~vbeln
    INTO CORRESPONDING FIELDS OF TABLE @gt_output
    UP TO @p_maxrow ROWS
    WHERE vbak~erdat BETWEEN @p_frdate AND @p_todate
      AND vbak~vbeln IN @s_vbeln
      AND vbak~vkorg IN @s_vkorg
      AND vbak~kunnr IN @s_kunnr
      AND vbap~matnr IN @s_matnr.

  IF gt_output IS INITIAL.
    MESSAGE 'No sales orders found for the given selection criteria.' TYPE 'I'.
    RETURN.
  ENDIF.

  IF lines( gt_output ) >= p_maxrow.
    MESSAGE |Result limited to { p_maxrow } rows. Narrow your selection.| TYPE 'I'.
  ENDIF.

* Retrieve customer names (sorted table for efficient lookup)
  SELECT kunnr, name1
    FROM kna1
    INTO TABLE @gt_kna1
    FOR ALL ENTRIES IN @gt_output
    WHERE kunnr = @gt_output-kunnr.

* Enrich output with customer names
  LOOP AT gt_output ASSIGNING FIELD-SYMBOL(<gs_output>).
    <gs_output>-name1 = VALUE #( gt_kna1[ kunnr = <gs_output>-kunnr ]-name1 OPTIONAL ).
  ENDLOOP.

ENDFORM.

*&---------------------------------------------------------------------*
*& Form F_BUILD_FIELDCATALOG
*&---------------------------------------------------------------------*
FORM f_build_fieldcatalog.

  CLEAR gt_fieldcat.

  PERFORM f_add_field USING 'VBELN'   'Sales Order Number'   'Order No.'  10 '' ''.
  PERFORM f_add_field USING 'ERDAT'   'Created On Date'      'Created'    10 '' ''.
  PERFORM f_add_field USING 'ERNAM'   'Created By User'      'Created By' 12 '' ''.
  PERFORM f_add_field USING 'AUART'   'Sales Document Type'  'Doc Type'    4 '' ''.
  PERFORM f_add_field USING 'VKORG'   'Sales Organization'   'Sales Org'   4 '' ''.
  PERFORM f_add_field USING 'VTWEG'   'Distribution Channel' 'Dist Ch.'    2 '' ''.
  PERFORM f_add_field USING 'SPART'   'Division'             'Division'    2 '' ''.
  PERFORM f_add_field USING 'KUNNR'   'Sold-To Party'        'Customer'   10 '' ''.
  PERFORM f_add_field USING 'NAME1'   'Customer Name'        'Cust Name'  35 '' ''.
  PERFORM f_add_field USING 'NETWR'   'Header Net Value'     'Net Value'  15 'WAERK' 'X'.
  PERFORM f_add_field USING 'WAERK'   'Currency'             'Curr'        5 '' ''.
  PERFORM f_add_field USING 'BSTNK'   'PO Number'            'PO No.'     20 '' ''.
  PERFORM f_add_field USING 'VKBUR'   'Sales Office'         'Sales Off'   4 '' ''.
  PERFORM f_add_field USING 'VKGRP'   'Sales Group'          'Sales Grp'   3 '' ''.
  PERFORM f_add_field USING 'POSNR'   'Item Number'          'Item'         6 '' ''.
  PERFORM f_add_field USING 'MATNR'   'Material Number'      'Material'    18 '' ''.
  PERFORM f_add_field USING 'ARKTX'   'Material Description' 'Matl Desc'   40 '' ''.
  PERFORM f_add_field USING 'KWMENG'  'Order Quantity'       'Quantity'    13 '' ''.
  PERFORM f_add_field USING 'VRKME'   'Unit of Measure'      'UoM'          3 '' ''.
  PERFORM f_add_field USING 'NETPR'   'Net Price'            'Net Price'   13 'WAERK' ''.
  PERFORM f_add_field USING 'NETWR_I' 'Item Net Value'       'Item Val'    15 'WAERK' 'X'.

ENDFORM.

*&---------------------------------------------------------------------*
*& Form F_ADD_FIELD
*&---------------------------------------------------------------------*
FORM f_add_field USING VALUE(pv_fieldname) TYPE c
                       VALUE(pv_coltext)   TYPE c
                       VALUE(pv_scrtext)   TYPE c
                       VALUE(pv_outlen)    TYPE i
                       VALUE(pv_cfield)    TYPE c
                       VALUE(pv_dosum)     TYPE c.

  DATA ls_fcat TYPE lvc_s_fcat.
  ls_fcat-fieldname  = pv_fieldname.
  ls_fcat-coltext    = pv_coltext.
  ls_fcat-scrtext_s  = pv_scrtext.
  ls_fcat-outputlen  = pv_outlen.
  IF pv_cfield IS NOT INITIAL.
    ls_fcat-cfieldname = pv_cfield.
  ENDIF.
  IF pv_dosum = 'X'.
    ls_fcat-do_sum = abap_true.
  ENDIF.
  APPEND ls_fcat TO gt_fieldcat.

ENDFORM.

*&---------------------------------------------------------------------*
*& Form F_BUILD_LAYOUT
*&---------------------------------------------------------------------*
FORM f_build_layout.

  gs_layout-zebra      = abap_true.
  gs_layout-cwidth_opt = abap_true.
  gs_layout-sel_mode   = 'A'.
  gs_layout-grid_title = 'Sales Order Report - Header & Item Data'.

  gs_variant-report  = sy-repid.
  gs_variant-variant = '/DEFAULT'.

ENDFORM.

*&---------------------------------------------------------------------*
*& Form F_DISPLAY_ALV_GRID
*&---------------------------------------------------------------------*
FORM f_display_alv_grid.

  IF go_grid IS INITIAL.
    go_grid = NEW #( i_parent = cl_gui_container=>default_screen ).
    go_handler = NEW #( ).
    SET HANDLER go_handler->handle_double_click FOR go_grid.

    go_grid->set_table_for_first_display(
      EXPORTING
        is_layout       = gs_layout
        is_variant      = gs_variant
        i_save          = 'A'
        i_default       = abap_true
      CHANGING
        it_outtab       = gt_output
        it_fieldcatalog = gt_fieldcat ).
  ELSE.
    go_grid->refresh_table_display( ).
  ENDIF.

  WRITE: / space.

ENDFORM.
