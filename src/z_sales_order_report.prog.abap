*&---------------------------------------------------------------------*
*& Report Z_SALES_ORDER_REPORT
*&---------------------------------------------------------------------*
*& Description: Custom report to display sales order header and item
*&              data in an ALV grid with selection screen filters.
*& Author:      Generated via Kiro Spec-Driven Development
*& Date:        2026-05-05
*&---------------------------------------------------------------------*
REPORT z_sales_order_report.

*----------------------------------------------------------------------*
* Type Definitions
*----------------------------------------------------------------------*
TYPES: BEGIN OF ty_output,
         vbeln      TYPE vbak-vbeln,    " Sales Order Number
         auart      TYPE vbak-auart,    " Document Type
         vkorg      TYPE vbak-vkorg,    " Sales Organization
         audat      TYPE vbak-audat,    " Document Date
         kunnr      TYPE vbak-kunnr,    " Sold-To Party
         name1      TYPE kna1-name1,    " Customer Name
         netwr      TYPE vbak-netwr,    " Header Net Value
         waerk      TYPE vbak-waerk,    " Currency
         posnr      TYPE vbap-posnr,    " Item Number
         matnr      TYPE vbap-matnr,    " Material Number
         arktx      TYPE vbap-arktx,    " Material Description
         kwmeng     TYPE vbap-kwmeng,   " Order Quantity
         vrkme      TYPE vbap-vrkme,    " Unit of Measure
         netpr      TYPE vbap-netpr,    " Net Price
         netwr_item TYPE vbap-netwr,    " Item Net Value
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
      gs_output TYPE ty_output,
      gs_kna1   TYPE ty_kna1.

* Data references for SELECT-OPTIONS typing
DATA: gv_vbeln TYPE vbak-vbeln,
      gv_vkorg TYPE vbak-vkorg,
      gv_kunnr TYPE vbak-kunnr,
      gv_audat TYPE vbak-audat,
      gv_matnr TYPE vbap-matnr.

*----------------------------------------------------------------------*
* Selection Screen
*----------------------------------------------------------------------*
SELECTION-SCREEN BEGIN OF BLOCK b1 WITH FRAME TITLE TEXT-001.
  SELECT-OPTIONS: s_vbeln FOR gv_vbeln,    " Sales Order Number
                  s_vkorg FOR gv_vkorg,    " Sales Organization
                  s_kunnr FOR gv_kunnr,    " Customer Number
                  s_audat FOR gv_audat,    " Document Date
                  s_matnr FOR gv_matnr.    " Material Number
  PARAMETERS: p_maxrow TYPE i DEFAULT 500. " Maximum Rows
SELECTION-SCREEN END OF BLOCK b1.

*----------------------------------------------------------------------*
* Initialization
*----------------------------------------------------------------------*
INITIALIZATION.
*  TEXT-001 = 'Sales Order Selection Criteria'.

*----------------------------------------------------------------------*
* Start of Selection
*----------------------------------------------------------------------*
START-OF-SELECTION.

  " Step 1: Authorization Check
  PERFORM check_authorization.

  " Step 2: Data Retrieval
  PERFORM retrieve_data.

  " Step 3: ALV Display
  IF gt_output IS NOT INITIAL.
    PERFORM display_alv.
  ENDIF.

*&---------------------------------------------------------------------*
*& Form CHECK_AUTHORIZATION
*&---------------------------------------------------------------------*
*& Checks authorization for sales organization before data access
*&---------------------------------------------------------------------*
FORM check_authorization.

  DATA: lv_authorized TYPE abap_bool VALUE abap_true.

  IF s_vkorg[] IS NOT INITIAL.
    " Check authorization for each specified sales organization
    LOOP AT s_vkorg.
      AUTHORITY-CHECK OBJECT 'V_VBAK_VKO'
        ID 'VKORG' FIELD s_vkorg-low.
      IF sy-subrc <> 0.
        lv_authorized = abap_false.
        EXIT.
      ENDIF.
      " Also check high value if range is specified
      IF s_vkorg-high IS NOT INITIAL.
        AUTHORITY-CHECK OBJECT 'V_VBAK_VKO'
          ID 'VKORG' FIELD s_vkorg-high.
        IF sy-subrc <> 0.
          lv_authorized = abap_false.
          EXIT.
        ENDIF.
      ENDIF.
    ENDLOOP.
  ELSE.
    " No sales org specified - check general authorization
    AUTHORITY-CHECK OBJECT 'V_VBAK_VKO'
      ID 'VKORG' DUMMY.
    IF sy-subrc <> 0.
      lv_authorized = abap_false.
    ENDIF.
  ENDIF.

  IF lv_authorized = abap_false.
    MESSAGE e001(z_so_report)
      WITH 'No authorization for the requested sales organization'.
    " Note: MESSAGE type E stops processing automatically
  ENDIF.

ENDFORM.

*&---------------------------------------------------------------------*
*& Form RETRIEVE_DATA
*&---------------------------------------------------------------------*
*& Retrieves sales order header and item data with customer names
*&---------------------------------------------------------------------*
FORM retrieve_data.

  " Retrieve sales order header and item data via INNER JOIN
  SELECT vbak~vbeln vbak~auart vbak~vkorg vbak~audat
         vbak~kunnr vbak~netwr vbak~waerk
         vbap~posnr vbap~matnr vbap~arktx
         vbap~kwmeng vbap~vrkme vbap~netpr vbap~netwr
    FROM vbak
    INNER JOIN vbap ON vbak~vbeln = vbap~vbeln
    INTO CORRESPONDING FIELDS OF TABLE gt_output
    UP TO p_maxrow ROWS
    WHERE vbak~vbeln IN s_vbeln
      AND vbak~vkorg IN s_vkorg
      AND vbak~kunnr IN s_kunnr
      AND vbak~audat IN s_audat
      AND vbap~matnr IN s_matnr.

  " Check if any data was found
  IF gt_output IS INITIAL.
    MESSAGE i002(z_so_report)
      WITH 'No sales orders found for the given selection criteria'.
    RETURN.
  ENDIF.

  " Check if result set was limited
  IF lines( gt_output ) >= p_maxrow.
    MESSAGE i003(z_so_report)
      WITH 'Result set limited to' p_maxrow 'rows. Narrow your selection.'.
  ENDIF.

  " Retrieve customer names from KNA1 using FOR ALL ENTRIES
  IF gt_output IS NOT INITIAL.
    SELECT kunnr name1
      FROM kna1
      INTO TABLE lt_kna1
      FOR ALL ENTRIES IN gt_output
      WHERE kunnr = gt_output-kunnr.

    " Enrich output with customer names
    LOOP AT gt_output ASSIGNING FIELD-SYMBOL(<fs_output>).
      READ TABLE lt_kna1 INTO gs_kna1
        WITH KEY kunnr = <fs_output>-kunnr.
      IF sy-subrc = 0.
        <fs_output>-name1 = gs_kna1-name1.
      ENDIF.
    ENDLOOP.
  ENDIF.

ENDFORM.

*&---------------------------------------------------------------------*
*& Form DISPLAY_ALV
*&---------------------------------------------------------------------*
*& Displays the output data in an ALV grid using cl_salv_table
*&---------------------------------------------------------------------*
FORM display_alv.

  DATA: lo_alv     TYPE REF TO cl_salv_table,
        lo_columns TYPE REF TO cl_salv_columns_table,
        lo_column  TYPE REF TO cl_salv_column_table,
        lo_funcs   TYPE REF TO cl_salv_functions_list,
        lx_msg     TYPE REF TO cx_salv_msg,
        lx_not_found TYPE REF TO cx_salv_not_found.

  TRY.
      " Create ALV instance
      cl_salv_table=>factory(
        IMPORTING
          r_salv_table = lo_alv
        CHANGING
          t_table      = gt_output ).

      " Enable all standard ALV functions (sort, filter, export, etc.)
      lo_funcs = lo_alv->get_functions( ).
      lo_funcs->set_all( abap_true ).

      " Configure columns
      lo_columns = lo_alv->get_columns( ).
      lo_columns->set_optimize( abap_true ).

      " Set column texts
      TRY.
          lo_column ?= lo_columns->get_column( 'VBELN' ).
          lo_column->set_short_text( 'Order No.' ).
          lo_column->set_medium_text( 'Sales Order' ).
          lo_column->set_long_text( 'Sales Order Number' ).

          lo_column ?= lo_columns->get_column( 'AUART' ).
          lo_column->set_short_text( 'Doc Type' ).
          lo_column->set_medium_text( 'Document Type' ).
          lo_column->set_long_text( 'Sales Document Type' ).

          lo_column ?= lo_columns->get_column( 'VKORG' ).
          lo_column->set_short_text( 'Sales Org' ).
          lo_column->set_medium_text( 'Sales Org.' ).
          lo_column->set_long_text( 'Sales Organization' ).

          lo_column ?= lo_columns->get_column( 'AUDAT' ).
          lo_column->set_short_text( 'Doc Date' ).
          lo_column->set_medium_text( 'Document Date' ).
          lo_column->set_long_text( 'Document Date' ).

          lo_column ?= lo_columns->get_column( 'KUNNR' ).
          lo_column->set_short_text( 'Customer' ).
          lo_column->set_medium_text( 'Customer No.' ).
          lo_column->set_long_text( 'Sold-To Party' ).

          lo_column ?= lo_columns->get_column( 'NAME1' ).
          lo_column->set_short_text( 'Cust Name' ).
          lo_column->set_medium_text( 'Customer Name' ).
          lo_column->set_long_text( 'Customer Name' ).

          lo_column ?= lo_columns->get_column( 'NETWR' ).
          lo_column->set_short_text( 'Net Value' ).
          lo_column->set_medium_text( 'Header Net Val' ).
          lo_column->set_long_text( 'Header Net Value' ).
          lo_column->set_currency_column( 'WAERK' ).

          lo_column ?= lo_columns->get_column( 'WAERK' ).
          lo_column->set_short_text( 'Currency' ).
          lo_column->set_medium_text( 'Currency' ).
          lo_column->set_long_text( 'Document Currency' ).

          lo_column ?= lo_columns->get_column( 'POSNR' ).
          lo_column->set_short_text( 'Item' ).
          lo_column->set_medium_text( 'Item Number' ).
          lo_column->set_long_text( 'Sales Order Item' ).

          lo_column ?= lo_columns->get_column( 'MATNR' ).
          lo_column->set_short_text( 'Material' ).
          lo_column->set_medium_text( 'Material No.' ).
          lo_column->set_long_text( 'Material Number' ).

          lo_column ?= lo_columns->get_column( 'ARKTX' ).
          lo_column->set_short_text( 'Matl Desc' ).
          lo_column->set_medium_text( 'Material Desc.' ).
          lo_column->set_long_text( 'Material Description' ).

          lo_column ?= lo_columns->get_column( 'KWMENG' ).
          lo_column->set_short_text( 'Quantity' ).
          lo_column->set_medium_text( 'Order Qty' ).
          lo_column->set_long_text( 'Order Quantity' ).

          lo_column ?= lo_columns->get_column( 'VRKME' ).
          lo_column->set_short_text( 'UoM' ).
          lo_column->set_medium_text( 'Unit of Meas.' ).
          lo_column->set_long_text( 'Unit of Measure' ).

          lo_column ?= lo_columns->get_column( 'NETPR' ).
          lo_column->set_short_text( 'Net Price' ).
          lo_column->set_medium_text( 'Net Price' ).
          lo_column->set_long_text( 'Net Price' ).
          lo_column->set_currency_column( 'WAERK' ).

          lo_column ?= lo_columns->get_column( 'NETWR_ITEM' ).
          lo_column->set_short_text( 'Item Val' ).
          lo_column->set_medium_text( 'Item Net Value' ).
          lo_column->set_long_text( 'Item Net Value' ).
          lo_column->set_currency_column( 'WAERK' ).

        CATCH cx_salv_not_found INTO lx_not_found.
          " Column not found - continue with defaults
      ENDTRY.

      " Display the ALV grid
      lo_alv->display( ).

    CATCH cx_salv_msg INTO lx_msg.
      MESSAGE lx_msg TYPE 'E'.
  ENDTRY.

ENDFORM.
