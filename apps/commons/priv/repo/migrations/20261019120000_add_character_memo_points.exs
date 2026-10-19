defmodule Aesir.Repo.Migrations.AddCharacterMemoPoints do
  use Ecto.Migration

  def change do
    alter table(:characters) do
      add :memo_points, {:array, :map}, null: false, default: []
    end
  end
end
