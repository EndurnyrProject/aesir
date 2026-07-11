defmodule Aesir.ZoneServer.Mmo.StatusEffect.Registry do
  @moduledoc """
  Stores compiled status effect definitions in ETS for fast runtime access.

  Definitions come from the modules listed in `Aesir.ZoneServer.Mmo.StatusEffect.Effects`.
  Each definition is the module's validated metadata map with the implementing
  module under the `:module` key, so metadata consumers (properties, immunity,
  resistance) operate on plain maps while behavior dispatches to the module.
  """
  import Aesir.ZoneServer.EtsTable, only: [table_for: 1]

  require Logger

  alias Aesir.ZoneServer.Mmo.StatusEffect.Effects

  @doc """
  Gets a status effect definition by ID.

  Returns the metadata map (including the `:module` key) or nil if not found.
  """
  @spec get_definition(atom()) :: map() | nil
  def get_definition(status_id) do
    case :ets.lookup(table_for(:status_effect_definitions), status_id) do
      [{_, definition}] -> definition
      [] -> nil
    end
  end

  @doc """
  Gets a status effect definition by the string form of its ID.

  For data that crosses the VM boundary (persisted statuses), where converting
  an arbitrary string to an atom would be unsafe. Returns the metadata map or
  nil for unknown names.
  """
  @spec get_definition_by_name(String.t()) :: map() | nil
  def get_definition_by_name(name) do
    table_for(:status_effect_definitions)
    |> :ets.tab2list()
    |> Enum.find_value(fn {status_id, definition} ->
      if Atom.to_string(status_id) == name, do: definition
    end)
  end

  @doc """
  Loads all status effect definitions into the ETS table.
  """
  @spec load_definitions() :: :ok
  def load_definitions do
    modules = Effects.all()

    Enum.each(modules, &register_module/1)

    Logger.info("Loaded #{length(modules)} status effect definitions")

    :ok
  end

  @doc """
  Registers a single module-based status effect definition.

  The module must implement `Aesir.ZoneServer.Mmo.StatusEffect.Definition`.
  """
  @spec register_module(module()) :: :ok
  def register_module(module) do
    definition = Map.put(module.metadata(), :module, module)
    :ets.insert(table_for(:status_effect_definitions), {module.id(), definition})
    :ok
  end
end
