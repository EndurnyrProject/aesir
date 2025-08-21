defmodule Aesir.ZoneServer.Mmo.StatusEffect.Registry do
  @moduledoc """
  Manages loading and accessing status effect definitions.

  This module handles:
  - Loading definitions from configuration files
  - Compiling definitions into efficient runtime structures
  - Providing access to compiled definitions
  - Initializing and managing the ETS table for definitions

  The registry is the single source of truth for status effect definitions
  in the system, ensuring consistent behavior across all game systems.
  """

  require Logger
  alias Aesir.ZoneServer.Mmo.StatusEffect.Schema

  @compiled_effects :status_effect_definitions

  @doc """
  Initialize the registry by loading and compiling all status effect definitions.
  Creates or cleans the ETS table.
  """
  @spec init() :: :ok
  def init do
    if :ets.whereis(@compiled_effects) == :undefined do
      :ets.new(@compiled_effects, [:set, :public, :named_table])
    else
      :ets.delete_all_objects(@compiled_effects)
    end

    load_definitions()
    :ok
  end

  @doc """
  Get a compiled status effect definition by ID.

  ## Parameters
    - status_id: The atom identifying the status effect
    
  ## Returns
    - The compiled definition map or nil if not found
  """
  @spec get_definition(atom()) :: map() | nil
  def get_definition(status_id) do
    case :ets.lookup(@compiled_effects, status_id) do
      [{_, definition}] -> definition
      [] -> nil
    end
  end

  @doc """
  Loads status effect definitions from the priv directory.
  Validates strictly (raises on errors), compiles and stores them in the ETS table.
  """
  @spec load_definitions() :: :ok
  def load_definitions do
    path = Path.join(:code.priv_dir(:zone_server), "db/re/status_effects.exs")

    case File.read(path) do
      {:ok, content} ->
        {definitions, _} = Code.eval_string(content)

        # Always validate strictly - will raise on any validation errors
        validated_definitions = Schema.validate_all(definitions)

        Logger.info("All #{map_size(validated_definitions)} status effects passed validation")

        # Compile and store validated definitions
        Enum.each(validated_definitions, fn {id, definition} ->
          compiled = compile_definition(definition)
          :ets.insert(@compiled_effects, {id, compiled})
        end)

        Logger.info("Loaded #{map_size(validated_definitions)} status effect definitions")

      {:error, reason} ->
        Logger.error("Failed to load status definitions: #{inspect(reason)}")
    end

    :ok
  end

  @doc """
  Compiles a status effect definition into its runtime representation.
  """
  @spec compile_definition(map()) :: map()
  def compile_definition(definition) do
    definition
    |> compile_hooks()
    |> compile_phases()
  end

  # Private functions

  defp compile_hooks(definition) do
    alias Aesir.ZoneServer.Mmo.StatusEffect.FormulaCompiler

    Enum.reduce([:on_apply, :on_expire, :on_damage, :on_damaged], definition, fn hook, def ->
      case def[hook] do
        nil ->
          def

        # Special handling for on_damage which can have action/condition structure
        %{action: _} = _damage_config when hook == :on_damage ->
          # Don't compile on_damage with action/condition structure
          def

        actions ->
          Map.put(def, hook, compile_actions(actions))
      end
    end)
    |> compile_tick_hooks()
  end

  defp compile_tick_hooks(definition) do
    case definition[:tick] do
      nil ->
        definition

      tick_def ->
        Map.put(definition, :tick, %{
          interval: tick_def[:interval] || 1000,
          actions: compile_actions(tick_def[:actions] || [])
        })
    end
  end

  defp compile_phases(definition) do
    case definition[:phases] do
      nil ->
        definition

      phases ->
        compiled_phases =
          Enum.map(phases, fn {phase_id, phase_def} ->
            compiled_phase =
              phase_def
              |> Map.put(:modifiers, phase_def[:modifiers] || %{})
              |> compile_hooks()

            {phase_id, compiled_phase}
          end)
          |> Map.new()

        Map.put(definition, :phases, compiled_phases)
    end
  end

  defp compile_actions(actions) when is_list(actions) do
    Enum.map(actions, &compile_action/1)
  end

  defp compile_actions(action), do: [compile_action(action)]

  defp compile_action(%{type: :conditional} = action) do
    alias Aesir.ZoneServer.Mmo.StatusEffect.FormulaCompiler

    %{
      type: :conditional,
      condition: FormulaCompiler.compile(action[:if] || action[:condition]),
      then_actions: compile_actions(action[:then] || []),
      else_actions: compile_actions(action[:else] || [])
    }
  end

  defp compile_action(%{formula: formula} = action) when is_binary(formula) do
    alias Aesir.ZoneServer.Mmo.StatusEffect.FormulaCompiler
    Map.put(action, :formula_fn, FormulaCompiler.compile(formula))
  end

  defp compile_action(action), do: action
end
