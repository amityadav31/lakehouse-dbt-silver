{#- Use the configured schema as-is (mobility, reference, ...) instead of dbt's
    default "<target_schema>_<custom_schema>" (dbo_mobility). -#}
{% macro generate_schema_name(custom_schema_name, node) -%}
    {{ custom_schema_name | trim if custom_schema_name is not none else target.schema }}
{%- endmacro %}
