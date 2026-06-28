defmodule Aesir.ZoneServer.Mmo.Skills.AcConcentration do
  @moduledoc """
  Improve Concentration (AC_CONCENTRATION). Self-buff applying SC_CONCENTRATE,
  raising AGI and DEX by (2 + level)% of the caster's stat above its equipment
  bonus, then revealing hidden/cloaked units within radius 3 of the caster.

  rAthena (status.cpp SC_CONCENTRATE): val2 = 2 + level; val3/val4 store the
  caster's equipment/card AGI/DEX bonus (param_bonus[1]/[4]) so the percentage
  applies to the base stat only.
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 45,
    name: :ac_concentration,
    display_name: "Improve Concentration",
    max_level: 10,
    target_type: :self,
    damage_type: :no_damage,
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
  alias Aesir.ZoneServer.Mmo.StatusEffect.Helpers
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Unit.Player.Stats
  alias Aesir.ZoneServer.Unit.SpatialIndex

  @behaviour Active

  @reveal_radius 3
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
      reveal_hidden(caster_id)
      {:ok, caster}
    end
  end

  defp reveal_hidden(caster_id) do
    case SpatialIndex.get_unit_position(:player, caster_id) do
      {:ok, {x, y, map_name}} ->
        map_name
        |> SpatialIndex.get_all_units_in_range(x, y, @reveal_radius)
        |> Enum.each(&Helpers.remove_statuses(&1, @hidden_statuses))

      {:error, :not_found} ->
        :ok
    end
  end
end
