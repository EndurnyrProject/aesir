defmodule Aesir.Repo.Migrations.ListItemRandomOptions do
  use Ecto.Migration

  @tables [:inventory, :cart_inventory, :storage, :guild_storage]

  # Rows written before the list shape hold an object keyed by option id
  # (`{"<id>": {"val": v, "parm": p}}`); they become slots in option-id order.
  def up do
    for table <- @tables do
      execute """
      UPDATE #{table} SET random_options = COALESCE(
        (SELECT jsonb_agg(
                  jsonb_build_object(
                    'id', e.k::int,
                    'value', COALESCE((e.v->>'val')::int, 0),
                    'param', COALESCE((e.v->>'parm')::int, 0))
                  ORDER BY e.k::int)
           FROM jsonb_each(random_options) AS e(k, v)),
        '[]'::jsonb)
      WHERE random_options IS NULL OR jsonb_typeof(random_options) = 'object'
      """

      execute "ALTER TABLE #{table} ALTER COLUMN random_options SET DEFAULT '[]'::jsonb"
      execute "ALTER TABLE #{table} ALTER COLUMN random_options SET NOT NULL"
    end
  end

  def down do
    for table <- @tables do
      execute "ALTER TABLE #{table} ALTER COLUMN random_options DROP NOT NULL"
      execute "UPDATE #{table} SET random_options = '{}'::jsonb WHERE random_options = '[]'::jsonb"
      execute "ALTER TABLE #{table} ALTER COLUMN random_options SET DEFAULT '{}'::jsonb"
    end
  end
end
