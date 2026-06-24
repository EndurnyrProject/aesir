defmodule Aesir.Repo.Migrations.AddVarsToCharacters do
  use Ecto.Migration

  def change do
    alter table(:characters) do
      add :vars, :map, default: %{}
    end
  end
end
