defmodule Aesir.ZoneServer.Mmo.Skills.Sniper.SnFalconassault do
  @moduledoc """
  Falcon Assault sends an equipped falcon for one neutral misc hit that never misses.

  Both modes deal five Blitz Beat base hits times `(150 + 70 * level)%`.
  Renewal's base uses AGI, DEX, Steel Crow and the Assault level; pre-renewal
  uses DEX, INT and Steel Crow. Renewal casts in 0.5 s plus 0.5 s fixed, with
  0.5 s aftercast delay; pre-renewal casts in 1 s with 3 s aftercast delay.
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 381,
    name: :sn_falconassault,
    display_name: "Falcon Assault",
    max_level: 5,
    ignore_noncrit_atk_bonus: [renewal: true, pre_renewal: false],
    target_type: :target_enemy,
    damage_type: :damage,
    damage_kind: :misc,
    element: :neutral,
    range: 9,
    sp_cost: [30, 34, 38, 42, 46],
    cast_time: [renewal: List.duplicate(500, 5), pre_renewal: List.duplicate(1000, 5)],
    fixed_cast_time: [renewal: List.duplicate(500, 5), pre_renewal: []],
    after_cast_delay: [renewal: List.duplicate(500, 5), pre_renewal: List.duplicate(3000, 5)]

  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.Skill.Definition
  alias Aesir.ZoneServer.Mmo.Skills.Hunter.HtSteelcrow
  alias Aesir.ZoneServer.Mmo.Skills.Sniper.Formulas
  alias Aesir.ZoneServer.Unit.Player.Handlers.FalconHandler
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.Stats

  @behaviour Active

  @steel_crow_id HtSteelcrow.definition(:renewal).id

  @impl Active
  @spec validate(PlayerState.t(), Active.target(), pos_integer(), Definition.t()) ::
          :ok | {:error, :falcon_not_equipped}
  def validate(%PlayerState{} = caster, _target, _level, _definition) do
    if FalconHandler.falcon?(caster), do: :ok, else: {:error, :falcon_not_equipped}
  end

  @impl Active
  @spec cast(PlayerState.t(), Active.target(), pos_integer(), Definition.t()) ::
          {:ok, PlayerState.t()} | {:error, atom()}
  def cast(%PlayerState{stats: stats} = caster, {:unit, target_id}, level, definition) do
    steel_crow = Map.get(stats.progression.learned_skills, @steel_crow_id, 0)

    effective_stats = %{
      agi: Stats.get_effective_stat(stats, :agi),
      dex: Stats.get_effective_stat(stats, :dex),
      int: Stats.get_effective_stat(stats, :int)
    }

    case Combat.execute_misc_attack(caster, target_id,
           skill_id: definition.id,
           skill_level: level,
           base_damage: Formulas.falcon_assault_damage(level, steel_crow, effective_stats),
           element: :neutral
         ) do
      :ok -> {:ok, caster}
      {:error, _reason} = error -> error
    end
  end
end
