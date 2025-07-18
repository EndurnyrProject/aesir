defmodule Aesir.Repo.Migrations.UpdateAccountPasswordLength do
  use Ecto.Migration

  def change do
    alter table(:accounts) do
      modify :user_pass, :string, size: 255
    end
  end
end
