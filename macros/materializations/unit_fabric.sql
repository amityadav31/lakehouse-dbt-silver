{#-
  Override of dbt's default `unit` materialization for Fabric.

  Why 1 (nested CTEs): dbt-core turns the unit-test inputs into CTEs injected
  into the model SQL, and both the default materialization
  (get_empty_subquery_sql → CTAS) and fabric__get_unit_test_sql wrap that SQL in
  another WITH. The Fabric dbt job rejects that with error 16214 "Nested CTE
  cannot be used in this query". Fix: create the model SQL (one level of CTEs)
  as a view, read its column types from the view, and compare the view to the
  expected rows with a plain UNION ALL. No statement nests a WITH.

  Why 2 (leftovers): every test node ends with ROLLBACK, and Fabric Warehouse
  DDL is transactional, so a DROP inside the test transaction is undone and the
  object survives into the next run (and into Fabric's Git sync). Fix: create
  and drop the view in autocommit, and commit before the final drop.

  Remove once dbt-fabric handles both itself.
-#}
{%- materialization unit, adapter='fabric' -%}

  {% set expected_rows = config.get('expected_rows') %}
  {% set expected_sql = config.get('expected_sql') %}

  {%- set target_relation = this.incorporate(type='table') -%}
  {%- set temp_relation = make_temp_relation(target_relation) -%}
  {%- set actual_view = temp_relation.incorporate(
        path={"identifier": temp_relation.identifier ~ '_vw'}, type='view') -%}

  {#- USE first: the connection may still be on a bronze lakehouse from reading source columns.
      The table drop clears leftovers from the previous version of this macro. -#}
  {% call statement('pre_drop_unit_test_objects', auto_begin=False) -%}
    {{ get_use_database_sql(actual_view.database) }}
    drop view if exists {{ actual_view.include(database=False) }};
    drop table if exists {{ temp_relation.include(database=False) }};
  {%- endcall %}

  {% call statement('create_unit_test_view', auto_begin=False) -%}
    {{ get_use_database_sql(actual_view.database) }}
    EXEC('CREATE VIEW {{ actual_view.include(database=False) }} AS {{ sql | replace("'", "''") }}');
  {%- endcall %}

  {%- set column_name_to_data_types = {} -%}
  {%- set column_name_to_quoted = {} -%}
  {%- for column in adapter.get_columns_in_relation(actual_view) -%}
  {%-   do column_name_to_data_types.update({column.name|lower: column.data_type}) -%}
  {%-   do column_name_to_quoted.update({column.name|lower: column.quoted}) -%}
  {%- endfor -%}

  {%- set tested_expected_column_names = expected_rows[0].keys() if (expected_rows | length) > 0
        else column_name_to_quoted.keys() -%}
  {%- set expected_column_names_quoted = [] -%}
  {%- for column_name in tested_expected_column_names -%}
  {%-   do expected_column_names_quoted.append(column_name_to_quoted[column_name|lower]) -%}
  {%- endfor -%}

  {% if not expected_sql %}
  {%   set expected_sql = get_expected_sql(expected_rows, column_name_to_data_types, column_name_to_quoted) %}
  {% endif %}

  {% call statement('main', fetch_result=True) -%}
    select {{ expected_column_names_quoted | join(', ') }}, 'actual' as [actual_or_expected]
    from {{ actual_view }}
    union all
    select {{ expected_column_names_quoted | join(', ') }}, 'expected' as [actual_or_expected]
    from ( {{ expected_sql }} ) as dbt_internal_unit_test_expected
  {%- endcall %}

  {#- commit first so the end-of-node ROLLBACK can't undo the drop -#}
  {% do adapter.commit() %}
  {% call statement('drop_unit_test_view', auto_begin=False) -%}
    {{ get_use_database_sql(actual_view.database) }}
    drop view if exists {{ actual_view.include(database=False) }}
  {%- endcall %}

  {{ return({'relations': []}) }}

{%- endmaterialization -%}
