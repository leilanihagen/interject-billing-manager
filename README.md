# Interject Billing Manager

Billing management system created by me for Interject. The project is written in SQL Server, but integrates directly with the Interject Excel Add-in and Interject Data Portal software layer, so it will not be runnable by those who are not Interject users.

## How to View this Project

This project is written in SQL Server, but integrates directly with the Interject Excel Add-in and Interject Data Portal software layer, so it will not be runnable by those who are not Interject users. To best understand the problem and my solutions, first see the Excel sheet located in ./report, then consult the SQL code organized by its corresponding tab on the Excel sheet located in ./src.

## Problem Description

Billing and invoicing of clients, as well as keeping track of software license renewal dates, was previously handled manually and became cumbersome at Interject. I was tasked with creating a centralized system to handle these customer relationships and inventory of Interject products/services.

This project was developed in SQL Server 2008.

Terms:
* *License:* the purchased right to use Interject software for a agreed upon amount of time.
* *Module:* an item (software product or service) that a user can license for a duration of time.

The solution generally needed to accomplish two things:
1. Creating a new schema and group of related tables to contain data describing our inventory, clients and client-license relationships. This includes corresponding history tables.
2. Creating a user interface where Interject account managers can (1) create customer invoices for billing and (2) search, input and modify inventory, client and client-license relationship data entries in the database tables. 

Some specific requirements of the solution:
1. The ability to model a client-license relationship that can be defined for any duration of time (yearly renewal or quarterly, monthly, etc.).
2. The ability for a single clients to have multiple licenses associated with them (typical use case: a client would like a yearly license of one module, but a quarterly license of another).
3. The ability to define licenses specific to a certain location/branch of a client's company.
4. The ability to include a "license partner" () in a client-license relationship
5. The ability to specify discounts on specific modules _and_ discounts that apply to all modules in a given license grouping.
6. The ability to apply "license factors" (a percentage price increase by year or other time duration) to individual modules.

## Solution

After some debate and thorough consideration of the solution requirements, I came up with the idea of a "*license package*." A license package is defined as a client-license relationship that can contain licenses of multiple Interject modules, but all of said modules within one license package must be licensed for the same duration of time, 

## Note on Commit History

This repository unfortunately does not preserve the original commit history because certain development files were excluded from public view and only the final project code is published here. The project code is, however, complete.

## About Interject

Interject is a data-solutions company that focuses on improving the productivity of their clients' businesses in the areas of reporting and accounting, data management, and other custom solutions. I worked for Interject as a member of their student team from May 2019 until February 2020.

I was given permission to publish this project by Interject.

Check out Interject's website at: https://gointerject.com/.
