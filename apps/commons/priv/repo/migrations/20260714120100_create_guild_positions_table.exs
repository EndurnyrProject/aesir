defmodule Aesir.Repo.Migrations.CreateGuildPositionsTable do
  use Ecto.Migration

  def change do
    create table(:guild_positions, primary_key: false) do
      add :guild_id, :bigint, primary_key: true
      add :index, :integer, primary_key: true
      add :name, :string
      add :can_invite, :boolean, null: false, default: false
      add :can_expel, :boolean, null: false, default: false
      add :can_storage, :boolean, null: false, default: false
      add :tax, :integer, null: false, default: 0
    end
  end
end
