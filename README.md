# Z_SALES_ORDER_REPORT

Custom ABAP report that displays sales order header and item data in an ALV grid.

## Features

- Selection screen with filters for: Sales Order, Sales Org, Customer, Date, Material
- INNER JOIN between VBAK and VBAP for efficient data retrieval
- Customer name enrichment from KNA1
- ALV grid display with full interactive capabilities (sort, filter, export)
- Authorization check on V_VBAK_VKO before data access
- Configurable row limit (default 500)

## Deployment

This repository is structured for [abapGit](https://abapgit.org/).

1. Install abapGit on your SAP system (transaction ZABAPGIT)
2. Create a new online repository pointing to this GitHub repo
3. Select target package and pull

## Target System

- Host: azw2sapfs4ps.esri.com
- Client: 050
