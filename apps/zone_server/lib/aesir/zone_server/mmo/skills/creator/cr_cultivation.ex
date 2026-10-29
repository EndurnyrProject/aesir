defmodule Aesir.ZoneServer.Mmo.Skills.Creator.CrCultivation do
  @moduledoc """
  Plant Cultivation (CR_CULTIVATION).

  A player plants a Mushroom Spore (level 1) or a Stem (level 2) on a cell next
  to it for 10 SP. A cell any player, monster or Homunculus stands on (dead or
  hidden included, the caster too) refuses the planting: the cast fails with
  the seed kept. Otherwise the cell shows the skill, the seed is spent and half
  the time nothing grows, which fails the cast. The other half grows an ordinary
  monster with no owner for five minutes, which then withers without dropping
  anything: a Black or a Red Mushroom at level 1; at level 2 a Green Plant (30%),
  a Red Plant (25%), a Yellow Plant (25%), a White Plant (10%), a Blue Plant (8%)
  or a Shining Plant (2%). A spawn the map refuses grows nothing without failing
  the cast.

  Only the pre-renewal skill tree teaches it; renewal shares the same data. No
  monster casts it.
  """

  use Aesir.ZoneServer.Mmo.Skill,
    id: 491,
    name: :cr_cultivation,
    display_name: "Plant Cultivation",
    max_level: 2,
    target_type: :ground,
    damage_type: :no_damage,
    damage_kind: :none,
    range: 1,
    sp_cost: [10, 10],
    duration: [300_000, 300_000]

  alias Aesir.ZoneServer.Map.Coordinator
  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.Skill.Definition
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.SpatialIndex

  @behaviour Active

  @seeds %{1 => 921, 2 => 905}
  @character_units [:player, :mob, :homunculus]
  @default_rng &:rand.uniform/1

  # Level 2's table: the first entry whose bound exceeds a 0..99 draw.
  @plants [{30, 1_080}, {55, 1_078}, {80, 1_081}, {90, 1_082}, {98, 1_079}, {100, 1_083}]

  @doc "The level's seed, the only item the planting needs."
  @impl Active
  @spec dynamic_item_cost(Active.caster(), Active.target(), pos_integer(), Definition.t()) :: [
          %{id: integer(), amount: pos_integer()}
        ]
  def dynamic_item_cost(_caster, _target, level, _definition),
    do: [%{id: Map.fetch!(@seeds, level), amount: 1}]

  @impl Active
  @spec cast(PlayerState.t(), Active.target(), pos_integer(), Definition.t()) ::
          {:ok, PlayerState.t()} | {:failed, PlayerState.t(), :skill_failed, atom()}
  def cast(%PlayerState{} = caster, {:ground, x, y}, level, definition) do
    cond do
      occupied?(caster.map_name, x, y) ->
        {:failed, caster, :skill_failed, :spare_items}

      rng().(100) <= 50 ->
        {:failed, caster, :skill_failed, :after_effect}

      true ->
        _ =
          Coordinator.summon_mob(caster.map_name, plant(level), x, y,
            lifetime_ms: Enum.at(definition.duration, level - 1)
          )

        {:ok, caster}
    end
  end

  defp occupied?(map_name, x, y) do
    map_name
    |> SpatialIndex.units_in_area(x, y, x, y)
    |> Enum.any?(fn {type, _id} -> type in @character_units end)
  end

  defp plant(1), do: 1_084 + rng().(2) - 1

  defp plant(2) do
    draw = rng().(100) - 1
    Enum.find_value(@plants, fn {bound, mob_id} -> if draw < bound, do: mob_id end)
  end

  defp rng, do: Application.get_env(:zone_server, :cultivation_rng, @default_rng)
end
