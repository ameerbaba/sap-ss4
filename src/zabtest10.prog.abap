*&---------------------------------------------------------------------*
*& Report zabtest10
*&---------------------------------------------------------------------*
*& Enhanced Sales Order ALV Report - OOP with CL_GUI_ALV_GRID
*& Includes: VBAP items, customer names, authorization checks,
*&           ALV grid display with full interactivity
*&---------------------------------------------------------------------*
REPORT zabtest10.

*----------------------------------------------------------------------*
* Type Definitions
*----------------------------------------------------------------------*
TYPES: BEGIN OF ty_output,
         " Sales Order Number
         vbeln  TYPE vbak-vbeln,
         " Created Date
         erdat  TYPE vbak-erdat,
         " Created By
         ernam  TYPE vbak-ernam,
         " Document Type
         auart  TYPE vbak-auart,
         " Sales Organization
         vkorg  TYPE vbak-vkorg,
         " Distribution Channel
         vtweg  TYPE vbak-vtweg,
         " Division
         spart  TYPE vbak-spart,
         " Customer Number
         kunnr  TYPE vbak-kunnr,
         " Customer Name
         name1  TYPE kna1-name1,
         " Header Net Value
         netwr  TYPE vbak-netwr,
         " Currency
         waerk  TYPE vbak-waerk,
         " PO Number
         bstnk  TYPE vbak-bstnk,
         " Sales Office
         vkbur  TYPE vbak-vkbur,
         " Sales Group
         vkgrp  TYPE vbak-vkgrp,
         " Item Number
         posnr  TYPE vbap-posnr,
         " Material Number
         matnr  TYPE vbap-matnr,
         " Material Description
         arktx  TYPE vbap-arktx,
         " Order Quantity
         kwmeng TYPE vbap-kwmeng,
         " Unit of Measure
         vrkme  TYPE vbap-vrkme,
         " Net Price
         netpr  TYPE vbap-netpr,
         " Item Net Value
         netwr_i TYPE vbap-netwr,
       END OF ty_output.

TYPES: BEGIN OF ty_kna1,
         kunnr TYPE kna1-kunnr,
         name1 TYPE kna1-name1,
       END OF ty_kna1.
*----------------------------------------------------------------------*
* Data Declarations
*----------------------------------------------------------------------*
DATA: gt_output TYPE STANDARD TABLE OF ty_output,
      lt_kna1   TYPE STANDARD TABLE OF ty_kna1,
      gs_kna1   TYPE ty_kna1.



* Data references for SELECT-OPTIONS
DATA: gv_vbeln TYPE vbak-vbeln,
      gv_vkorg TYPE vbak-vkorg,
      gv_kunnr TYPE vbak-kunnr,
      gv_matnr TYPE vbap-matnr.
*----------------------------------------------------------------------*
* Class Definition - Event Handler
*----------------------------------------------------------------------*
CLASS lcl_event_handler DEFINITION.
  PUBLIC SECTION.
    METHODS:
      handle_double_click
        FOR EVENT double_click OF cl_gui_alv_grid
        IMPORTING e_row e_column es_row_no.
ENDCLASS.

CLASS lcl_event_handler IMPLEMENTATION.
  METHOD handle_double_click.
    " Navigate to sales order display (VA03) on double-click
    DATA(ls_output) = gt_output[ e_row-index ].
    SET PARAMETER ID 'AUN' FIELD ls_output-vbeln.
    AUTHORITY-CHECK OBJECT 'S_TCODE'
      ID 'TCD' FIELD 'VA03'.
    IF sy-subrc = 0.
      CALL TRANSACTION 'VA03' AND SKIP FIRST SCREEN.
    ENDIF.
  ENDMETHOD.
ENDCLASS.
* ALV Grid objects
DATA: go_grid      TYPE REF TO cl_gui_alv_grid,
      go_handler   TYPE REF TO lcl_event_handler,
      gt_fieldcat  TYPE lvc_t_fcat,
      gs_layout    TYPE lvc_s_layo,
      gs_variant   TYPE disvariant.


*----------------------------------------------------------------------*
* Selection Screen
*----------------------------------------------------------------------*
SELECTION-SCREEN BEGIN OF BLOCK b1 WITH FRAME TITLE TEXT-001.
" Sales Order Created Date Range
PARAMETERS: p_frdate TYPE vbak-erdat OBLIGATORY,
            p_todate TYPE vbak-erdat OBLIGATORY.
" Sales Order Number
SELECT-OPTIONS: s_vbeln FOR gv_vbeln.
" Sales Organization
SELECT-OPTIONS: s_vkorg FOR gv_vkorg.
" Customer Number
SELECT-OPTIONS: s_kunnr FOR gv_kunnr.
" Material Number
SELECT-OPTIONS: s_matnr FOR gv_matnr.
" Maximum Rows
PARAMETERS: p_maxrow TYPE i DEFAULT 500.
SELECTION-SCREEN END OF BLOCK b1.

*----------------------------------------------------------------------*
* Initialization
*----------------------------------------------------------------------*
INITIALIZATION.
* TEXT-001 = 'Sales Order Selection Criteria'.

*----------------------------------------------------------------------*
* Start of Selection
*----------------------------------------------------------------------*
START-OF-SELECTION.

  " Step 1: Authorization Check
  PERFORM check_authorization.

  " Step 2: Data Retrieval
  PERFORM retrieve_data.

  " Step 3: ALV Grid Display
  IF gt_output IS NOT INITIAL.
    PERFORM build_fieldcatalog.
    PERFORM build_layout.
    PERFORM display_alv_grid.
  ENDIF.

*&---------------------------------------------------------------------*
*& Form CHECK_AUTHORIZATION
*&---------------------------------------------------------------------*
FORM check_authorization.

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
*& Form RETRIEVE_DATA
*&---------------------------------------------------------------------*
FORM retrieve_data.

  " Retrieve sales order header + item data via INNER JOIN
  SELECT vbak~vbeln, vbak~erdat, vbak~ernam, vbak~auart,
         vbak~vkorg, vbak~vtweg, vbak~spart, vbak~kunnr,
         vbak~netwr, vbak~waerk, vbak~bstnk, vbak~vkbur, vbak~vkgrp,
         vbap~posnr, vbap~matnr, vbap~arktx,
         vbap~kwmeng, vbap~vrkme, vbap~netpr   ", vbap~netwr_i
    FROM vbak
    INNER JOIN vbap ON vbak~vbeln = vbap~vbeln
    INTO CORRESPONDING FIELDS OF TABLE @gt_output
    UP TO @p_maxrow ROWS
    WHERE vbak~erdat BETWEEN @p_frdate AND @p_todate
      AND vbak~vbeln IN @s_vbeln
      AND vbak~vkorg IN @s_vkorg
      AND vbak~kunnr IN @s_kunnr
      AND vbap~matnr IN @s_matnr.

  " Check if any data was found
  IF gt_output IS INITIAL.
    MESSAGE 'No sales orders found for the given selection criteria.' TYPE 'I'.
    RETURN.
  ENDIF.

  " Inform if result set was limited
  IF lines( gt_output ) >= p_maxrow.
    MESSAGE |Result limited to { p_maxrow } rows. Narrow your selection.| TYPE 'I'.
  ENDIF.

  " Retrieve customer names from KNA1
  SELECT kunnr, name1
    FROM kna1
    INTO TABLE @lt_kna1
    FOR ALL ENTRIES IN @gt_output
    WHERE kunnr = @gt_output-kunnr.

  " Enrich output with customer names
  LOOP AT gt_output ASSIGNING FIELD-SYMBOL(<ls_output>).
    READ TABLE lt_kna1 INTO gs_kna1
      WITH KEY kunnr = <ls_output>-kunnr.
    IF sy-subrc = 0.
      <ls_output>-name1 = gs_kna1-name1.
    ENDIF.
  ENDLOOP.

ENDFORM.

*&---------------------------------------------------------------------*
*& Form BUILD_FIELDCATALOG
*&---------------------------------------------------------------------*
FORM build_fieldcatalog.

  DATA ls_fcat TYPE lvc_s_fcat.

  CLEAR gt_fieldcat.

  " Sales Order Number
  CLEAR ls_fcat.
  ls_fcat-fieldname = 'VBELN'.
  ls_fcat-coltext   = 'Sales Order Number'.
  ls_fcat-scrtext_s = 'Order No.'.
  ls_fcat-outputlen = 10.
  APPEND ls_fcat TO gt_fieldcat.

  " Created On Date
  CLEAR ls_fcat.
  ls_fcat-fieldname = 'ERDAT'.
  ls_fcat-coltext   = 'Created On Date'.
  ls_fcat-scrtext_s = 'Created'.
  ls_fcat-outputlen = 10.
  APPEND ls_fcat TO gt_fieldcat.

  " Created By User
  CLEAR ls_fcat.
  ls_fcat-fieldname = 'ERNAM'.
  ls_fcat-coltext   = 'Created By User'.
  ls_fcat-scrtext_s = 'Created By'.
  ls_fcat-outputlen = 12.
  APPEND ls_fcat TO gt_fieldcat.

  " Sales Document Type
  CLEAR ls_fcat.
  ls_fcat-fieldname = 'AUART'.
  ls_fcat-coltext   = 'Sales Document Type'.
  ls_fcat-scrtext_s = 'Doc Type'.
  ls_fcat-outputlen = 4.
  APPEND ls_fcat TO gt_fieldcat.

  " Sales Organization
  CLEAR ls_fcat.
  ls_fcat-fieldname = 'VKORG'.
  ls_fcat-coltext   = 'Sales Organization'.
  ls_fcat-scrtext_s = 'Sales Org'.
  ls_fcat-outputlen = 4.
  APPEND ls_fcat TO gt_fieldcat.

  " Distribution Channel
  CLEAR ls_fcat.
  ls_fcat-fieldname = 'VTWEG'.
  ls_fcat-coltext   = 'Distribution Channel'.
  ls_fcat-scrtext_s = 'Dist Ch.'.
  ls_fcat-outputlen = 2.
  APPEND ls_fcat TO gt_fieldcat.

  " Division
  CLEAR ls_fcat.
  ls_fcat-fieldname = 'SPART'.
  ls_fcat-coltext   = 'Division'.
  ls_fcat-scrtext_s = 'Division'.
  ls_fcat-outputlen = 2.
  APPEND ls_fcat TO gt_fieldcat.

  " Sold-To Party
  CLEAR ls_fcat.
  ls_fcat-fieldname = 'KUNNR'.
  ls_fcat-coltext   = 'Sold-To Party'.
  ls_fcat-scrtext_s = 'Customer'.
  ls_fcat-outputlen = 10.
  APPEND ls_fcat TO gt_fieldcat.

  " Customer Name
  CLEAR ls_fcat.
  ls_fcat-fieldname = 'NAME1'.
  ls_fcat-coltext   = 'Customer Name'.
  ls_fcat-scrtext_s = 'Cust Name'.
  ls_fcat-outputlen = 35.
  APPEND ls_fcat TO gt_fieldcat.

  " Header Net Value with currency reference
  CLEAR ls_fcat.
  ls_fcat-fieldname  = 'NETWR'.
  ls_fcat-coltext    = 'Header Net Value'.
  ls_fcat-scrtext_s  = 'Net Value'.
  ls_fcat-outputlen  = 15.
  ls_fcat-cfieldname = 'WAERK'.
  ls_fcat-do_sum     = abap_true.
  APPEND ls_fcat TO gt_fieldcat.

  " Currency
  CLEAR ls_fcat.
  ls_fcat-fieldname = 'WAERK'.
  ls_fcat-coltext   = 'Currency'.
  ls_fcat-scrtext_s = 'Curr'.
  ls_fcat-outputlen = 5.
  APPEND ls_fcat TO gt_fieldcat.

  " PO Number
  CLEAR ls_fcat.
  ls_fcat-fieldname = 'BSTNK'.
  ls_fcat-coltext   = 'PO Number'.
  ls_fcat-scrtext_s = 'PO No.'.
  ls_fcat-outputlen = 20.
  APPEND ls_fcat TO gt_fieldcat.

  " Sales Office
  CLEAR ls_fcat.
  ls_fcat-fieldname = 'VKBUR'.
  ls_fcat-coltext   = 'Sales Office'.
  ls_fcat-scrtext_s = 'Sales Off'.
  ls_fcat-outputlen = 4.
  APPEND ls_fcat TO gt_fieldcat.

  " Sales Group
  CLEAR ls_fcat.
  ls_fcat-fieldname = 'VKGRP'.
  ls_fcat-coltext   = 'Sales Group'.
  ls_fcat-scrtext_s = 'Sales Grp'.
  ls_fcat-outputlen = 3.
  APPEND ls_fcat TO gt_fieldcat.

  " Item Number
  CLEAR ls_fcat.
  ls_fcat-fieldname = 'POSNR'.
  ls_fcat-coltext   = 'Item Number'.
  ls_fcat-scrtext_s = 'Item'.
  ls_fcat-outputlen = 6.
  APPEND ls_fcat TO gt_fieldcat.

  " Material Number
  CLEAR ls_fcat.
  ls_fcat-fieldname = 'MATNR'.
  ls_fcat-coltext   = 'Material Number'.
  ls_fcat-scrtext_s = 'Material'.
  ls_fcat-outputlen = 18.
  APPEND ls_fcat TO gt_fieldcat.

  " Material Description
  CLEAR ls_fcat.
  ls_fcat-fieldname = 'ARKTX'.
  ls_fcat-coltext   = 'Material Description'.
  ls_fcat-scrtext_s = 'Matl Desc'.
  ls_fcat-outputlen = 40.
  APPEND ls_fcat TO gt_fieldcat.

  " Order Quantity
  CLEAR ls_fcat.
  ls_fcat-fieldname = 'KWMENG'.
  ls_fcat-coltext   = 'Order Quantity'.
  ls_fcat-scrtext_s = 'Quantity'.
  ls_fcat-outputlen = 13.
  APPEND ls_fcat TO gt_fieldcat.

  " Unit of Measure
  CLEAR ls_fcat.
  ls_fcat-fieldname = 'VRKME'.
  ls_fcat-coltext   = 'Unit of Measure'.
  ls_fcat-scrtext_s = 'UoM'.
  ls_fcat-outputlen = 3.
  APPEND ls_fcat TO gt_fieldcat.

  " Net Price with currency reference
  CLEAR ls_fcat.
  ls_fcat-fieldname  = 'NETPR'.
  ls_fcat-coltext    = 'Net Price'.
  ls_fcat-scrtext_s  = 'Net Price'.
  ls_fcat-outputlen  = 13.
  ls_fcat-cfieldname = 'WAERK'.
  APPEND ls_fcat TO gt_fieldcat.

  " Item Net Value with currency reference
  CLEAR ls_fcat.
  ls_fcat-fieldname  = 'NETWR_I'.
  ls_fcat-coltext    = 'Item Net Value'.
  ls_fcat-scrtext_s  = 'Item Val'.
  ls_fcat-outputlen  = 15.
  ls_fcat-cfieldname = 'WAERK'.
  ls_fcat-do_sum     = abap_true.
  APPEND ls_fcat TO gt_fieldcat.

ENDFORM.

*&---------------------------------------------------------------------*
*& Form BUILD_LAYOUT
*&---------------------------------------------------------------------*
FORM build_layout.

  CLEAR gs_layout.
  " Alternating row colors
  gs_layout-zebra      = abap_true.
  " Optimize column widths
  gs_layout-cwidth_opt = abap_true.
  " Allow row selection
  gs_layout-sel_mode   = 'A'.
  gs_layout-grid_title = 'Sales Order Report - Header & Item Data'.

  " Layout variant for saving user settings
  gs_variant-report  = sy-repid.
  gs_variant-variant = '/DEFAULT'.

ENDFORM.

*&---------------------------------------------------------------------*
*& Form DISPLAY_ALV_GRID
*&---------------------------------------------------------------------*
FORM display_alv_grid.

  IF go_grid IS INITIAL.

    " Create ALV grid in full-screen mode
    go_grid = NEW #( i_parent = cl_gui_container=>default_screen ).

    " Create event handler and register events
    go_handler = NEW #( ).
    SET HANDLER go_handler->handle_double_click FOR go_grid.

    " Display ALV grid with layout variant save enabled
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
    " Refresh if already displayed
    go_grid->refresh_table_display( ).
  ENDIF.

  " Trigger screen output to display the grid
  WRITE: / space.

ENDFORM.
