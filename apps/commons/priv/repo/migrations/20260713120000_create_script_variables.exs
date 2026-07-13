defmodule Aesir.Repo.Migrations.CreateScriptVariables do
  use Ecto.Migration

  def change do
    create table(:server_variables, primary_key: false) do
      add :name, :string, primary_key: true
      add :value, :map, null: false
    end

    create table(:account_variables, primary_key: false) do
      add :account_id, references(:accounts, on_delete: :delete_all), primary_key: true
      add :name, :string, primary_key: true
      add :value, :map, null: false
    end
  end
end
