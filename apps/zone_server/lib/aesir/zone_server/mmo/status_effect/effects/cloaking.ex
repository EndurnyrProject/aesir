defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.Cloaking do
  @moduledoc """
  Cloaking (SC_CLOAKING).

  Conceals its holder, doubles CRIT, and applies wall-sensitive movement speed.
  Player movement commands refresh the stored adjacency branch.
  """
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_cloaking,
    no_dispel: true,
    properties: [:buff, :conceals],
    calc_flags: [:cri, :speed],
    flags: [:cloak, :no_pick_item, :stop_attacking],
    prevented_by: [:sc_refresh, :sc_inspiration],
    no_save: true,
    remove_on_map_change: true,
    icon: :cloaking,
    option: :cloak

  alias Aesir.ZoneServer.Map.MapCache
  alias Aesir.ZoneServer.Mmo.StatusEffect.Definition
  alias Aesir.ZoneServer.Mmo.StatusEntry
  alias Aesir.ZoneServer.Unit.Player.PlayerSession
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @impl true
  @spec modifiers(StatusEntry.t(), map()) :: %{
          critical_rate: 100,
          movement_speed: integer()
        }
  def modifiers(%StatusEntry{val1: level, state: state}, _context) when level in 1..10 do
    adjacent? = Map.get(state, :adjacent_impassable?, false)
    %{critical_rate: 100, movement_speed: movement_modifier(level, adjacent?)}
  end

  # A structurally-valid sc_cloaking entry whose level falls outside the
  # learnable 1..10 range (e.g. a level-less status applied directly by a
  # utility/test path) must not crash the modifier pipeline and take the unit's
  # whole stat recalculation down with it. Keep the concealment CRIT bonus and
  # contribute no speed delta, since no level-specific branch applies.
  def modifiers(%StatusEntry{}, _context), do: %{critical_rate: 100, movement_speed: 0}

  @impl true
  @spec on_movement_intent(Definition.target(), StatusEntry.t(), map(), Definition.context()) ::
          {:ok, StatusEntry.t()} | :remove
  def on_movement_intent(
        {:player, _unit_id},
        %StatusEntry{val1: level} = instance,
        %{map: map, x: x, y: y},
        _context
      ) do
    adjacent? = MapCache.adjacent_impassable?(map, x, y)

    if level in 1..2 and not adjacent? do
      :remove
    else
      {:ok, %{instance | state: Map.put(instance.state, :adjacent_impassable?, adjacent?)}}
    end
  end

  def on_movement_intent({:mob, _unit_id}, instance, _position, _context),
    do: {:ok, instance}

  @impl true
  @spec on_committed_action(
          Definition.target(),
          StatusEntry.t(),
          Definition.committed_action(),
          Definition.context()
        ) :: {:ok, StatusEntry.t()} | :remove
  def on_committed_action({:player, _unit_id}, instance, {:skill, 135}, _context),
    do: {:ok, instance}

  def on_committed_action({:player, _unit_id}, _instance, :normal_attack, _context), do: :remove

  def on_committed_action({:player, _unit_id}, _instance, {:skill, _skill_id}, _context),
    do: :remove

  def on_committed_action({:mob, _unit_id}, _instance, :normal_attack, _context), do: :remove

  def on_committed_action({:mob, _unit_id}, instance, {:skill, _skill_id}, _context),
    do: {:ok, instance}

  @impl true
  @spec on_tick(Definition.target(), StatusEntry.t(), Definition.context()) ::
          {:ok, StatusEntry.t()} | :remove
  def on_tick({:player, unit_id}, instance, _context) do
    with {:ok, {_module, _state, pid}} when is_pid(pid) <- UnitRegistry.get_unit(:player, unit_id),
         :ok <- PlayerSession.try_consume_sp(pid, 1) do
      {:ok, instance}
    else
      {:error, _reason} -> :remove
    end
  end

  def on_tick({:mob, _unit_id}, instance, _context), do: {:ok, instance}

  @impl true
  @spec after_damage_taken(Definition.target(), StatusEntry.t(), map(), Definition.context()) ::
          :ok | :remove
  def after_damage_taken(_target, _instance, %{damage: damage}, _context) when damage > 0,
    do: :remove

  def after_damage_taken(_target, _instance, %{damage: 0}, _context), do: :ok

  defp movement_modifier(level, false) when level in 1..2, do: 300
  defp movement_modifier(level, false), do: 30 - 3 * level
  defp movement_modifier(level, true), do: -min(25, 3 * level - 3)
end
