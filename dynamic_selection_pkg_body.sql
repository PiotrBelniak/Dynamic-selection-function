CREATE OR REPLACE NONEDITIONABLE PACKAGE BODY "PIOTR"."DYNAMIC_SELECTION_PKG" 
IS
    query_cursor PLS_INTEGER;
    nazwy_kolumn varchar2_100_ntt;/*nazwy kolumn wyciagniete z data dictionary*/
    typy_kolumn varchar2_100_ntt;/*typy danych kolumn wyciagniete z data dictionary*/
    dlugosci_kolumn number_ntt;/*dlugosci kolumn wyciagniete z data dictionary*/
    lista_kolumn varchar2_100_ntt:=varchar2_100_ntt();/*lista kolumn z inputu u¿ytkownika do g³ównego programu*/
    
    procedure dynamic_select(tabela VARCHAR2, kolumny VARCHAR2,warunki varchar2_100_ntt DEFAULT NULL,wartosci_warunku varchar2_100_ntt DEFAULT NULL)
    IS
        sql_string VARCHAR2(2000);
        missing_value EXCEPTION;
        incorrect_table EXCEPTION;
        illegal_columns EXCEPTION;
        incorrect_columns EXCEPTION;

        FUNCTION check_for_null(tablica IN varchar2_100_ntt) RETURN varchar2 
        IS
            null_nt varchar2_100_ntt:=varchar2_100_ntt(NULL);
            intersection_nt varchar2_100_ntt;
            return_val VARCHAR2(50);
        begin
            intersection_nt:=tablica MULTISET INTERSECT null_nt;

            IF intersection_nt IS EMPTY THEN
                return_val:='NULL IS ABSENT';
            ELSIF intersection_nt IS NOT EMPTY THEN
                return_val:='NULL IS PRESENT';
            END IF;  
            return return_val;
        END;
    
    begin
        IF check_for_null(warunki) = 'NULL IS PRESENT' OR check_for_null(wartosci_warunku) = 'NULL IS PRESENT' THEN
            RAISE missing_value;
        END IF;
        IF check_table(tabela) = 'INVALID' THEN
            RAISE incorrect_table;
        END IF;
        IF check_columns(kolumny,tabela) = 'INVALID' THEN
            RAISE incorrect_columns;
        END IF;
        IF INSTR(kolumny,'=',1)> 0 OR INSTR(kolumny,'<',1)> 0 OR INSTR(kolumny,'>',1)> 0 OR INSTR(kolumny,'--',1)> 0 OR INSTR(kolumny,'/*',1)> 0 THEN
            RAISE illegal_columns;
        END IF;
        
        fill_out_collections(kolumny,tabela);
        
        sql_string:='SELECT ';
        FOR indx IN dynamic_selection_pkg.lista_kolumn.FIRST..dynamic_selection_pkg.lista_kolumn.LAST LOOP
            sql_string := sql_string || dynamic_selection_pkg.lista_kolumn(indx) || ',';
        END LOOP;
        sql_string:=SUBSTR(sql_string,1,LENGTH(sql_string)-1) || ' FROM ' || tabela;
        IF warunki.COUNT>0 AND warunki.COUNT = wartosci_warunku.COUNT THEN
            FOR indx IN warunki.FIRST..warunki.LAST LOOP
                IF indx = 1 THEN
                    sql_string := sql_string || ' WHERE ' || warunki(indx) || ' = :warunek' || indx;
                ELSE
                    sql_string := sql_string || ' AND ' || warunki(indx) || ' = :warunek' || indx;
                END IF;
            END LOOP;
        END IF;
        
        prepare_query(sql_string,wartosci_warunku);
        
        DBMS_OUTPUT.PUT_LINE(sql_string);
        
        show_result;
        DBMS_SQL.CLOSE_CURSOR(dynamic_selection_pkg.query_cursor);
    EXCEPTION
        WHEN missing_value THEN
            DBMS_OUTPUT.PUT_LINE('Predicate nor predicate value can be null');
        WHEN illegal_columns THEN
            DBMS_OUTPUT.PUT_LINE('Columns cannot be accepted as they are.');   
        WHEN incorrect_table THEN
            DBMS_OUTPUT.PUT_LINE('Table does not exist in your schema.');  
        WHEN incorrect_columns THEN
            DBMS_OUTPUT.PUT_LINE('At least one column does not exist for that table.');   
        WHEN OTHERS THEN
            DBMS_SQL.CLOSE_CURSOR(dynamic_selection_pkg.query_cursor);
            RAISE;
    END dynamic_select;
    
    function check_table(tabela VARCHAR2) RETURN VARCHAR2 ACCESSIBLE BY(procedure dynamic_select)
    IS
        ret_val VARCHAR2(20);
        table_list varchar2_100_ntt;
    BEGIN
        SELECT table_name BULK COLLECT INTO table_list FROM USER_TABLES;
        IF UPPER(tabela) MEMBER OF table_list THEN
            ret_val:='VALID';
        ElSE
            ret_val:='INVALID';
        END IF;
        return ret_val;
    END check_table;

    function check_columns(kolumny VARCHAR2, tabela VARCHAR2) RETURN VARCHAR2 ACCESSIBLE BY(procedure dynamic_select)
    IS
        ret_val VARCHAR2(20);
        licznik NUMBER :=1;
        illegal_delimeters EXCEPTION;
        tablecolumn_list varchar2_100_ntt;
    BEGIN
        IF REGEXP_REPLACE(REGEXP_REPLACE(kolumny ,'[/,/./;/:]'),'\w') IS NOT NULL THEN
            raise illegal_delimeters;
        END IF;
        SELECT column_name BULK COLLECT INTO tablecolumn_list from user_tab_columns where table_name = tabela;
        /*check, if there are any delimiters. If not, fill collection with only one item*/
        IF REGEXP_INSTR(kolumny, '[/,/./;/:]{1}\w*',1,licznik) = 0 THEN
            dynamic_selection_pkg.lista_kolumn.EXTEND;
            dynamic_selection_pkg.lista_kolumn(dynamic_selection_pkg.lista_kolumn.LAST) := REGEXP_REPLACE(kolumny ,'[/,/./;/:]');
        ELSE
            dynamic_selection_pkg.lista_kolumn.EXTEND;
            dynamic_selection_pkg.lista_kolumn(dynamic_selection_pkg.lista_kolumn.LAST):=UPPER(SUBSTR(kolumny,1,REGEXP_INSTR(kolumny, '[/,/./;/:]{1}',1,licznik,0)-1));
            LOOP
                EXIT WHEN REGEXP_INSTR(kolumny, '[/,/./;/:]{1}\w*',1,licznik) = 0;
                dynamic_selection_pkg.lista_kolumn.EXTEND;
                dynamic_selection_pkg.lista_kolumn(dynamic_selection_pkg.lista_kolumn.LAST) := UPPER(SUBSTR(kolumny, REGEXP_INSTR(kolumny, '[/,/./;/:]{1}\w*',1,licznik,0)+1,REGEXP_INSTR(kolumny, '[/,/./;/:]{1}\w*',1,licznik,1)-REGEXP_INSTR(kolumny, '[/,/./;/:]{1}\w*',1,licznik,0)-1));
                licznik :=licznik+1;
            END LOOP;
        END IF;          
        IF dynamic_selection_pkg.lista_kolumn SUBMULTISET OF tablecolumn_list THEN
            ret_val :='VALID';
        ELSE
            ret_val:='INVALID';
        END IF;
        return ret_val;
    EXCEPTION
        WHEN illegal_delimeters THEN
            DBMS_OUTPUT.PUT_LINE('Select list cannot be verified.');   
    END check_columns;
    
    procedure fill_out_collections(kolumny VARCHAR2,tabela VARCHAR2) ACCESSIBLE BY(procedure dynamic_select)
    IS
        sql_string VARCHAR2(2000);
    BEGIN
        sql_string := 'SELECT column_name, data_type, data_length from user_tab_columns where table_name = ''' || tabela || ''' and column_name IN (';
        FOR indx IN dynamic_selection_pkg.lista_kolumn.FIRST..dynamic_selection_pkg.lista_kolumn.LAST LOOP
            sql_string:=sql_string || '''' || dynamic_selection_pkg.lista_kolumn(indx) || ''',';
        END LOOP;
        sql_string:=SUBSTR(sql_string,1,LENGTH(sql_string)-1) || ')';
        EXECUTE IMMEDIATE sql_string BULK COLLECT INTO dynamic_selection_pkg.nazwy_kolumn,dynamic_selection_pkg.typy_kolumn,dynamic_selection_pkg.dlugosci_kolumn; 
    END;
    
    procedure read_collections
    IS
    BEGIN
        FOR indx IN dynamic_selection_pkg.nazwy_kolumn.FIRST..dynamic_selection_pkg.nazwy_kolumn.LAST LOOP
            DBMS_OUTPUT.PUT_LINE(dynamic_selection_pkg.nazwy_kolumn(indx) || '    ' || dynamic_selection_pkg.typy_kolumn(indx) || '    ' || dynamic_selection_pkg.dlugosci_kolumn(indx));
        END LOOP;
    END read_collections;
    
    procedure prepare_query(query_string VARCHAR2,wartosci_warunku varchar2_100_ntt DEFAULT NULL) ACCESSIBLE BY(procedure dynamic_select)
    IS

    BEGIN
        /*open the cursor*/
        dynamic_selection_pkg.query_cursor:=DBMS_SQL.OPEN_CURSOR; 
        /*parse the query*/
        DBMS_SQL.PARSE(dynamic_selection_pkg.query_cursor,query_string,DBMS_SQL.NATIVE);
        /*define columns*/
        column_definition;
        /*bind variables*/
        IF wartosci_warunku IS NOT NULL THEN
            binding_variables(wartosci_warunku);
        END IF; 
    END prepare_query;
    
    procedure column_definition ACCESSIBLE BY(function prepare_query)
    IS
        number_var NUMBER;
        char_var VARCHAR(1000);
        date_var DATE;
        blob_var BLOB;
        clob_var CLOB;
    BEGIN
        FOR indx IN dynamic_selection_pkg.typy_kolumn.FIRST..dynamic_selection_pkg.typy_kolumn.LAST LOOP
            CASE dynamic_selection_pkg.typy_kolumn(indx)
                WHEN 'NUMBER' THEN 
                    DBMS_SQL.DEFINE_COLUMN(dynamic_selection_pkg.query_cursor,indx,number_var);
                WHEN 'VARCHAR2' THEN 
                    DBMS_SQL.DEFINE_COLUMN(dynamic_selection_pkg.query_cursor,indx,char_var,dynamic_selection_pkg.dlugosci_kolumn(indx));
                WHEN 'DATE' THEN 
                    DBMS_SQL.DEFINE_COLUMN(dynamic_selection_pkg.query_cursor,indx,date_var);
                WHEN 'BLOB' THEN 
                    DBMS_SQL.DEFINE_COLUMN(dynamic_selection_pkg.query_cursor,indx,blob_var);
                WHEN 'CLOB' THEN 
                    DBMS_SQL.DEFINE_COLUMN(dynamic_selection_pkg.query_cursor,indx,clob_var);
            END CASE;
        END LOOP;        
    END column_definition;
    
    procedure binding_variables(wartosci_warunku varchar2_100_ntt) ACCESSIBLE BY(function prepare_query)
    IS
    BEGIN
        FOR indx IN wartosci_warunku.FIRST..wartosci_warunku.LAST LOOP
            DBMS_SQL.BIND_VARIABLE(dynamic_selection_pkg.query_cursor,'warunek' || indx,wartosci_warunku(indx));
        END LOOP;        
    END binding_variables;    
    
    procedure show_result  ACCESSIBLE BY(procedure dynamic_select)
    IS
        id_egzekucji NUMBER;
        linia_tekstu VARCHAR2(1000);
    BEGIN
        id_egzekucji:=DBMS_SQL.EXECUTE(dynamic_selection_pkg.query_cursor);
        
        LOOP
            id_egzekucji:=DBMS_SQL.FETCH_ROWS(dynamic_selection_pkg.query_cursor);
            EXIT WHEN id_egzekucji = 0;
            
            IF DBMS_SQL.LAST_ROW_COUNT = 1 THEN
                FOR indx IN dynamic_selection_pkg.nazwy_kolumn.FIRST..dynamic_selection_pkg.nazwy_kolumn.LAST LOOP
                    IF dynamic_selection_pkg.typy_kolumn(indx) = 'VARCHAR2' OR dynamic_selection_pkg.typy_kolumn(indx) = 'CHAR' THEN
                        linia_tekstu := linia_tekstu || RPAD(dynamic_selection_pkg.nazwy_kolumn(indx),GREATEST(dynamic_selection_pkg.dlugosci_kolumn(indx),LENGTH(dynamic_selection_pkg.nazwy_kolumn(indx))));
                    ELSE
                        linia_tekstu := linia_tekstu || RPAD(dynamic_selection_pkg.nazwy_kolumn(indx),GREATEST(15,LENGTH(dynamic_selection_pkg.nazwy_kolumn(indx))));
                    END IF;
                END LOOP;
                DBMS_OUTPUT.PUT_LINE(RPAD(' ',length(linia_tekstu),'-'));
                DBMS_OUTPUT.PUT_LINE(RPAD(' ',length(linia_tekstu),'-'));
                DBMS_OUTPUT.PUT_LINE(linia_tekstu);
                DBMS_OUTPUT.PUT_LINE(RPAD(' ',length(linia_tekstu),'-'));
            END IF;
            linia_tekstu:=row_valuation;
            DBMS_OUTPUT.PUT_LINE(linia_tekstu);
        END LOOP;

    END show_result;
    
    function row_valuation RETURN VARCHAR2 ACCESSIBLE BY(procedure show_result)
    IS
        rezultat VARCHAR2(1000);
        number_var NUMBER;
        char_var VARCHAR(1000);
        date_var DATE;
        blob_var BLOB;
        clob_var CLOB;
    BEGIN
        FOR indx IN dynamic_selection_pkg.typy_kolumn.FIRST..dynamic_selection_pkg.typy_kolumn.LAST LOOP
            CASE dynamic_selection_pkg.typy_kolumn(indx)
                WHEN 'NUMBER' THEN 
                    DBMS_SQL.COLUMN_VALUE(dynamic_selection_pkg.query_cursor,indx,number_var);
                    char_var:=RPAD(TO_CHAR(number_var),GREATEST(15,LENGTH(dynamic_selection_pkg.nazwy_kolumn(indx))));
                WHEN 'VARCHAR2' THEN 
                    DBMS_SQL.COLUMN_VALUE(dynamic_selection_pkg.query_cursor,indx,char_var);
                    char_var:=RPAD(char_var,GREATEST(dynamic_selection_pkg.dlugosci_kolumn(indx),LENGTH(dynamic_selection_pkg.nazwy_kolumn(indx))));
                WHEN 'DATE' THEN 
                    DBMS_SQL.COLUMN_VALUE(dynamic_selection_pkg.query_cursor,indx,date_var);
                    char_var:=RPAD(TO_CHAR(date_var,'DD.MM.RRRR'),GREATEST(15,LENGTH(dynamic_selection_pkg.nazwy_kolumn(indx))));
                WHEN 'BLOB' THEN 
                    DBMS_SQL.COLUMN_VALUE(dynamic_selection_pkg.query_cursor,indx,blob_var);
                WHEN 'CLOB' THEN 
                    DBMS_SQL.COLUMN_VALUE(dynamic_selection_pkg.query_cursor,indx,clob_var);
            END CASE;
            
            rezultat:= rezultat || char_var;
        END LOOP;          
        return rezultat;
    END row_valuation;
    
END dynamic_selection_pkg;

/
