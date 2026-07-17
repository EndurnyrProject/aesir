defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects do
  @moduledoc """
  Discovery of status effect implementations.

  New status effects are added by creating a module under
  `Aesir.ZoneServer.Mmo.StatusEffect.Effects` that uses
  `Aesir.ZoneServer.Mmo.StatusEffect.Definition`. There is no registration
  step — the module is found on its own.
  """

  alias Aesir.ZoneServer.Mmo.StatusEffect.Definition

  @namespace "Elixir.Aesir.ZoneServer.Mmo.StatusEffect.Effects."

  @doc """
  Returns all status effect implementations.

  Candidates come from the `:zone_server` application manifest rather than the
  code server, so modules compiled from test files are structurally excluded
  and their ids cannot collide with real ones.

  The order follows the manifest and is not guaranteed stable; no caller
  depends on it, as status ids are unique and every consumer either iterates or
  keys by id.
  """
  @spec all() :: [module()]
  def all do
    {:ok, modules} = :application.get_key(:zone_server, :modules)

    Enum.filter(modules, &effect_module?/1)
  end

  defp effect_module?(module) do
    String.starts_with?(Atom.to_string(module), @namespace) and
      Code.ensure_loaded?(module) and
      Definition in List.wrap(module.__info__(:attributes)[:behaviour])
  end
end
