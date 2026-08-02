defmodule Aesir.Repo.Migrations.AddItemPickupShareToParties do
  use Ecto.Migration

  def change do
    alter table(:parties) do
      add :item_pickup_share, :boolean, null: false, default: false
    end
  end
end
