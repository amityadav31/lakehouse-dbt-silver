{#-
  Override of dbt's default `unit` materialization for Fabric.

  Why: dbt-core creates the unit test's temp table outside a transaction, then
  drops it inside the transaction it opened for the test query, and ends every
  test node with ROLLBACK. Fabric Warehouse DDL is transactional, so that
  ROLLBACK undoes the DROP and leaves `<test>__dbt_tmp` tables behind; the next
  run then fails with "There is already an object named ...", and Fabric's Git
  sync commits the leftovers as warehouse objects.

  Fix: drop any leftover before creating; after the test query, commit the open
  transaction and drop the temp table in autocommit.
  Identical to the default materialization (dbt-core 1.12) otherwise.
  Remove once dbt-fabric handles this itself.
-#}
{%- materialization unit, adapter='fabric' -%}

  {% set relations = [] %}
  {% set sql_header = config.get('sql_header') if flags.REQUIRE_SQL_HEADER_IN_TEST_CONFIGS else none %}

  {% set expected_rows = config.get('expected_rows') %}
  {% set expected_sql = config.get('expected_sql') %}
  {% set tested_expected_column_names = expected_rows[0].keys() if (expected_rows | length ) > 0 else get_columns_in_query(sql) %}

  {%- set target_relation = this.incorporate(type='table') -%}
  {%- set temp_relation = make_temp_relation(target_relation)-%}
  {#- changed: clear a leftover from a failed earlier run (a failing test exits before cleanup).
      USE first: the connection may still be on a bronze lakehouse from reading source columns. -#}
  {% call statement('pre_drop_unit_test_temp', auto_begin=False) -%}
    {{ get_use_database_sql(temp_relation.database) }}
    drop table if exists {{ temp_relation.include(database=False) }}
  {%- endcall %}
  {% do run_query(get_create_table_as_sql(True, temp_relation, get_empty_subquery_sql(sql))) %}
  {%- set columns_in_relation = adapter.get_columns_in_relation(temp_relation) -%}
  {%- set column_name_to_data_types = {} -%}
  {%- set column_name_to_quoted = {} -%}
  {%- for column in columns_in_relation -%}
  {%-   do column_name_to_data_types.update({column.name|lower: column.data_type}) -%}
  {%-   do column_name_to_quoted.update({column.name|lower: column.quoted}) -%}
  {%- endfor -%}

  {%- set expected_column_names_quoted = [] -%}
  {%- for column_name in tested_expected_column_names -%}
  {%-   do expected_column_names_quoted.append(column_name_to_quoted[column_name|lower]) -%}
  {%- endfor -%}

  {% if not expected_sql %}
  {%   set expected_sql = get_expected_sql(expected_rows, column_name_to_data_types, column_name_to_quoted) %}
  {% endif %}
  {% set unit_test_sql = get_unit_test_sql(sql, expected_sql, expected_column_names_quoted) %}

  {% call statement('main', fetch_result=True) -%}

    {% if sql_header %}{{ sql_header }}{% endif %}
    {{ unit_test_sql }}

  {%- endcall %}

  {#- changed: commit first so the end-of-node ROLLBACK can't undo the drop -#}
  {% do adapter.commit() %}
  {% call statement('drop_unit_test_temp', auto_begin=False) -%}
    {{ get_use_database_sql(temp_relation.database) }}
    drop table if exists {{ temp_relation.include(database=False) }}
  {%- endcall %}

  {{ return({'relations': relations}) }}

{%- endmaterialization -%}
