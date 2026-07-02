defmodule Aesir.Repo.Migrations.CreatePartiesTable do
  use Ecto.Migration

  def change do
    create table(:parties) do
      add :name, :string, null: false
      add :leader_char_id, :bigint, null: false
      add :exp_share, :boolean, null: false, default: false

      timestamps()
    end

    create unique_index(:parties, [:name])
  end
end
