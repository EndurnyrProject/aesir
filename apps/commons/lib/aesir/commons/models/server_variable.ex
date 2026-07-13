defmodule Aesir.Commons.Models.ServerVariable do
  @moduledoc """
  A server-wide script variable (rAthena `$var` / `$var$`).

  Backs the permanent, server-scoped globals NPC scripts read and write
  (donation totals, event stages, ...). The row is keyed by the variable name
  (a string, carrying rAthena's trailing `$` for string vars) and the value is
  stored jsonb-wrapped as `%{"v" => value}` so a bare integer or string round
  trips through a single `:map` column. Persisted and read write-through by
  `Aesir.ZoneServer.Script.Vars`; there is no in-process cache.
  """

  use Ecto.Schema

  import Ecto.Changeset

  @type t :: %__MODULE__{
          name: String.t(),
          value: map()
        }

  @primary_key false
  schema "server_variables" do
    field :name, :string, primary_key: true
    field :value, :map
  end

  @doc "Changeset for upserting a server variable row."
  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(server_variable, attrs) do
    server_variable
    |> cast(attrs, [:name, :value])
    |> validate_required([:name, :value])
  end
end
