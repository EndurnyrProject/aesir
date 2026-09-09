defmodule Aesir.ZoneServer.Mmo.Skills.Archer.AcConcentration do
  @moduledoc """
  Improve Concentration (AC_CONCENTRATION). A self-buff raising the caster's
  AGI and DEX by `(2 + level)` percent for one to four minutes, then sweeping
  the square around the caster once to strip concealment from everyone standing
  in it. The percentage applies only to the stat the archer actually owns:
  whatever AGI and DEX gear and cards contribute is subtracted first, so the
  buff cannot be inflated with equipment.

  The buff is identical in both modes: the same percentage per level, the same
  durations, the same exclusion of gear-granted stats, and the same one-shot
  reveal over the same area. It is suppressed while the caster stands in a
  Quagmire in both modes as well.
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 45,
    name: :ac_concentration,
    status: :sc_concentrate,
    display_name: "Improve Concentration",
    max_level: 10,
    target_type: :self,
    damage_type: :no_damage,
    splash_radius: 3,
    sp_cost: [25, 30, 35, 40, 45, 50, 55, 60, 65, 70],
    duration: [
      60_000,
      80_000,
      100_000,
      120_000,
      140_000,
      160_000,
      180_000,
      200_000,
      220_000,
      240_000
    ]

  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.Skill.Unit.CombatTarget
  alias Aesir.ZoneServer.Mmo.StatusEffect.Helpers
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Unit
  alias Aesir.ZoneServer.Unit.Player.Stats
  alias Aesir.ZoneServer.Unit.SpatialIndex
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @behaviour Active

  @hidden_statuses [:sc_hiding, :sc_cloaking]

  @impl Active
  def cast(%{character_id: caster_id} = caster, :self, level, definition) do
    params = [
      val1: level,
      val2: 2 + level,
      val3: Stats.get_equipment_modifier(caster.stats, :agi),
      val4: Stats.get_equipment_modifier(caster.stats, :dex),
      caster_id: caster_id,
      duration: Enum.at(definition.duration, level - 1)
    ]

    with :ok <- StatusInterpreter.apply_status(:player, caster_id, :sc_concentrate, params) do
      reveal_hidden(caster_id, definition.splash_radius)
      {:ok, caster}
    end
  end

  defp reveal_hidden(caster_id, radius) do
    case SpatialIndex.get_unit_position(:player, caster_id) do
      {:ok, {x, y, map_name}} ->
        map_name
        |> SpatialIndex.get_all_units_in_range(x, y, radius)
        |> Enum.filter(fn target -> CombatTarget.combat_unit?(target) and living?(target) end)
        |> Enum.each(&Helpers.remove_statuses(&1, @hidden_statuses))

      {:error, :not_found} ->
        :ok
    end
  end

  defp living?({unit_type, unit_id}) do
    case UnitRegistry.get_unit(unit_type, unit_id) do
      {:ok, {_module, state, _pid}} -> Unit.living?(state)
      {:error, :not_found} -> false
    end
  end
end
