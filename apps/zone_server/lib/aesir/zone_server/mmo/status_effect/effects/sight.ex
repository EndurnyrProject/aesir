defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.Sight do
  @moduledoc """
  Sight (SC_SIGHT).

  A 10-second self aura applied by the Sight skill. It re-centers on the caster
  every 500ms tick (the native pulse is far tighter and is coarsened here):
  each pulse reveals concealed units within radius 3 of the caster's current cell
  by force-ending their `:sc_hiding` and `:sc_cloaking`, so someone who cloaks or
  walks in after the cast is still caught. The first pulse fires on apply. It
  carries no modifiers and deals no damage. If the caster's position cannot be
  resolved the pulse is a safe no-op and the aura expires normally.

  Renewal and pre-renewal behave identically: same radius, same duration, and no
  damage in either mode.
  """
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_sight,
    no_dispel: true,
    properties: [:buff],
    duration: 10_000,
    tick_interval: 500,
    no_save: true,
    option: :sight

  alias Aesir.ZoneServer.Mmo.Skill.Unit.CombatTarget
  alias Aesir.ZoneServer.Mmo.StatusEffect.Helpers
  alias Aesir.ZoneServer.Unit
  alias Aesir.ZoneServer.Unit.SpatialIndex
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @reveal_radius 3
  @hidden_statuses [:sc_hiding, :sc_cloaking]

  @impl true
  def on_apply({unit_type, _unit_id}, instance, %{target_id: caster_id}) do
    pulse(unit_type, caster_id)
    {:ok, instance}
  end

  @impl true
  def on_tick({unit_type, _unit_id}, instance, %{target_id: caster_id}) do
    pulse(unit_type, caster_id)
    {:ok, instance}
  end

  @spec pulse(atom(), integer()) :: :ok
  defp pulse(unit_type, caster_id) do
    case SpatialIndex.get_unit_position(unit_type, caster_id) do
      {:ok, {x, y, map_name}} ->
        map_name
        |> SpatialIndex.get_all_units_in_range(x, y, @reveal_radius)
        |> Enum.filter(fn target -> CombatTarget.combat_unit?(target) and living?(target) end)
        |> Enum.each(&reveal/1)

      {:error, :not_found} ->
        :ok
    end
  end

  defp reveal(target), do: Helpers.remove_statuses(target, @hidden_statuses)

  defp living?({unit_type, unit_id}) do
    case UnitRegistry.get_unit(unit_type, unit_id) do
      {:ok, {_module, state, _pid}} -> Unit.living?(state)
      {:error, :not_found} -> false
    end
  end
end
