defmodule Aesir.Repo.Migrations.AddCharacterFameOrder do
  use Ecto.Migration

  def up do
    execute "CREATE SEQUENCE character_fame_order_seq AS bigint"

    alter table(:characters) do
      add :fame_order, :bigint, null: false, default: 0
    end

    create index(:characters, ["fame DESC", "fame_order DESC", "id ASC"],
             name: :characters_positive_fame_index,
             where: "fame > 0"
           )
  end

  def down do
    drop index(:characters, [], name: :characters_positive_fame_index)

    alter table(:characters) do
      remove :fame_order
    end

    execute "DROP SEQUENCE character_fame_order_seq"
  end
end
