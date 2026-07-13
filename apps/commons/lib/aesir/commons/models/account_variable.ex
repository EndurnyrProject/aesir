defmodule Aesir.Commons.Models.AccountVariable do
  @moduledoc """
  A per-account script variable (rAthena `#var` / `##var`).

  Backs the permanent, account-scoped globals NPC scripts read and write. The
  row is keyed by `{account_id, name}`, where `name` carries the scope sigil
  (`#` account-local, `##` account-global) plus rAthena's trailing `$` for
  string vars, so the two scopes never collide in one table. The value is
  stored jsonb-wrapped as `%{"v" => value}`. Persisted and read write-through
  by `Aesir.ZoneServer.Script.Vars`; there is no in-process cache.
  """

  use Ecto.Schema

  import Ecto.Changeset

  @type t :: %__MODULE__{
          account_id: integer(),
          name: String.t(),
          value: map()
        }

  @primary_key false
  schema "account_variables" do
    field :account_id, :integer, primary_key: true
    field :name, :string, primary_key: true
    field :value, :map
  end

  @doc "Changeset for upserting an account variable row."
  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(account_variable, attrs) do
    account_variable
    |> cast(attrs, [:account_id, :name, :value])
    |> validate_required([:account_id, :name, :value])
  end
end
