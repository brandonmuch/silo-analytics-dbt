{% macro clean_string(column_name, force_case='lower') %}
    {%- if force_case == 'lower' -%}
        nullif(trim(lower({{ column_name }})), '')
    {%- elif force_case == 'upper' -%}
        nullif(trim(upper({{ column_name }})), '')
    {%- else -%}
        nullif(trim({{ column_name }}), '')
    {%- endif -%}
{% endmacro %}