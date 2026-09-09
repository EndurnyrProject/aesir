defmodule Aesir.ZoneServer.Mmo.Skills.Wizard.WzEarthspike do
  @moduledoc """
  Earth Spike (WZ_EARTHSPIKE). A bolt of earth magic striking once per level.

  Renewal: 200% MATK per hit (nine times that under the Earth Care option), 14 to 30
  SP, and a fixed cast part. Pre-renewal: 100% MATK per hit, 12 to 20 SP, a 0.7 s per
  level variable cast, and a 1 s plus 0.2 s per level delay.
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 90,
    name: :wz_earthspike,
    requires: [:player_state],
    display_name: "Earth Spike",
    max_level: 5,
    target_type: :target_enemy,
    damage_type: :damage,
    damage_kind: :magic,
    element: :earth,
    range: 9,
    cast_time: [
      renewal: [800, 1400, 2000, 2600, 3200],
      pre_renewal: [700, 1400, 2100, 2800, 3500]
    ],
    fixed_cast_time: [renewal: [400, 600, 800, 1000, 1200], pre_renewal: []],
    after_cast_delay: [
      renewal: List.duplicate(1400, 5),
      pre_renewal: [1000, 1200, 1400, 1600, 1800]
    ],
    sp_cost: [renewal: [14, 18, 22, 26, 30], pre_renewal: [12, 14, 16, 18, 20]]

  alias Aesir.Commons.GameMode
  alias Aesir.ZoneServer.Mmo.Combat.MagicAttack
  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.StatusStorage

  @behaviour Active

  @impl Active
  def cast(caster, {:unit, target_id}, level, _definition) do
    case MagicAttack.execute_bolt(caster, target_id, 90, level, skill_ratio: skill_ratio(caster)) do
      {:ok, _ref} -> {:ok, caster}
      {:error, _reason} = error -> error
    end
  end

  @doc "Renewal deals 200% MATK (nine times that under the Earth Care option); classic deals 100%."
  @spec skill_ratio(map()) :: pos_integer()
  def skill_ratio(caster) do
    case {GameMode.mode(), Map.get(caster, :character_id)} do
      {:renewal, id} when is_integer(id) ->
        if StatusStorage.has_status?(:player, id, :sc_earth_care_option), do: 1800, else: 200

      {:renewal, _} ->
        200

      {:pre_renewal, _} ->
        100
    end
  end
end
