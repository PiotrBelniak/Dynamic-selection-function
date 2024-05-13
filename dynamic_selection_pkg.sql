CREATE OR REPLACE NONEDITIONABLE PACKAGE "PIOTR"."DYNAMIC_SELECTION_PKG" 
IS
    type varchar2_100_ntt IS TABLE OF VARCHAR2(100);
    type number_ntt IS TABLE OF NUMBER;
    procedure dynamic_select(tabela VARCHAR2, kolumny VARCHAR2,warunki varchar2_100_ntt DEFAULT NULL,wartosci_warunku varchar2_100_ntt DEFAULT NULL);
    function check_table(tabela VARCHAR2) RETURN VARCHAR2 ACCESSIBLE BY(procedure dynamic_select);
    function check_columns(kolumny VARCHAR2,tabela VARCHAR2) RETURN VARCHAR2 ACCESSIBLE BY(procedure dynamic_select);
    procedure fill_out_collections(kolumny VARCHAR2,tabela VARCHAR2) ACCESSIBLE BY(procedure dynamic_select);
    procedure read_collections;
    procedure prepare_query(query_string VARCHAR2,wartosci_warunku varchar2_100_ntt DEFAULT NULL) ACCESSIBLE BY(procedure dynamic_select);
    procedure column_definition ACCESSIBLE BY(function prepare_query);
    procedure binding_variables(wartosci_warunku varchar2_100_ntt) ACCESSIBLE BY(function prepare_query);
    procedure show_result ACCESSIBLE BY(procedure dynamic_select);
    function row_valuation RETURN VARCHAR2 ACCESSIBLE BY(procedure show_result);
    
END dynamic_selection_pkg;

/
