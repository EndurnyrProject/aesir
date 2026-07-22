defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.Sight do
  @moduledoc """
  Sight (SC_SIGHT).

  A 10-second buff applied to the caster by MG_SIGHT. On apply it pulses once,
  revealing concealed units in radius 3 around the caster by force-ending their
  `:sc_hiding` and `:sc_cloaking`. It carries no modifiers and does not tick.
  """
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_sight,
    no_dispel: true,
    properties: [:buff],
    duration: 10_000,
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
    case SpatialIndex.get_unit_position(unit_type, caster_id) do
      {:ok, {x, y, map_name}} ->
        map_name
        |> SpatialIndex.get_all_units_in_range(x, y, @reveal_radius)
        |> Enum.filter(fn target -> CombatTarget.combat_unit?(target) and living?(target) end)
        |> Enum.each(&reveal/1)

      {:error, :not_found} ->
        :ok
    end

    {:ok, instance}
  end

  defp reveal(target), do: Helpers.remove_statuses(target, @hidden_statuses)

  defp living?({unit_type, unit_id}) do
    case UnitRegistry.get_unit(unit_type, unit_id) do
      {:ok, {_module, state, _pid}} -> Unit.living?(state)
      {:error, :not_found} -> false
    end
  end
end
