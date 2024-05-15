# Dynamic selection
## Usage
This function is the PL\SQL implementation of select statement with one table and unknown number of columns and predicates using DBMS_SQL built-in package.  
>[!NOTE]
>Currently only conjuction of equality predicate is supported.

## Requirements
Package called DYNAMIC_SELECTION_PKG has everything that is required for function to work properly.

## How to use function
We call the function by specifying table , column names delimited by comma, 
```bash
call dynamic_selection_pkg.dynamic_select('table name','column name(s)'
    ,dynamic_selection_pkg.varchar2_100_ntt('predicate nr1','predicate nr2',...,'predicate nr n')
    ,dynamic_selection_pkg.varchar2_100_ntt('predicate value nr.1','predicate value nr.2',...,predicate value nr.n))
```

## Result
The function prints the result of the query as serveroutput.

## Restrictions
The table must be in your own schema.

## Potential Issues
The procedure in this form does not protect from SQL injection via penultimate argument - this collection is not checked before constructing dynamic SQL query.

## Fixes and updates
The issue mentioned in previous statement can be solved by verifying the collection for suspicious elements, like BEGIN, NULL, mathematical signs.

The next version will have collection parameters replaced with comma-delimited text parameters for simplicity of use.
