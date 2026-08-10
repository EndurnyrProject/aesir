defmodule Aesir.Repo.Migrations.AddCraftToItems do
  use Ecto.Migration

  def change do
    alter table(:inventory) do
      add :craft, :map
    end

    alter table(:storage) do
      add :craft, :map
    end

    alter table(:cart_inventory) do
      add :craft, :map
    end
  end
end
