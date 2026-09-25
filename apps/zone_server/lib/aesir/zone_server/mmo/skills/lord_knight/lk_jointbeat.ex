defmodule Aesir.ZoneServer.Mmo.Skills.LordKnight.LkJointbeat do
  @moduledoc """
  Vital Strike (LK_JOINTBEAT) strikes with a spear and applies one of six
  Joint Beat wounds on a connecting hit. Renewal and pre-renewal share the
  wound chances and ratios; their after-cast delay differs at level five.
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 399,
    name: :lk_jointbeat,
    display_name: "Vital Strike",
    max_level: 10,
    target_type: :target_enemy,
    damage_type: :damage,
    range: 4,
    require_weapon: [:one_handed_spear, :two_handed_spear],
    sp_cost: [12, 12, 14, 14, 16, 16, 18, 18, 20, 20],
    after_cast_delay: [
      renewal: [800, 800, 800, 800, 1_000, 1_000, 1_000, 1_000, 1_000, 1_000],
      pre_renewal: [800, 800, 800, 800, 800, 1_000, 1_000, 1_000, 1_000, 1_000]
    ]

  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.Skill.Definition
  alias Aesir.ZoneServer.Mmo.StatusEffect.Effects.Jointbeat
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter
  alias Aesir.ZoneServer.Mmo.StatusEntry
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.Stats

  @behaviour Active

  @impl Active
  @spec validate(Active.caster(), Active.target(), pos_integer(), Definition.t()) ::
          :ok | {:error, :requires_spear}
  def validate(%PlayerState{stats: %{equipment: equipment}}, _target, _level, _definition) do
    if Stats.weapon_type(equipment) in [:one_handed_spear, :two_handed_spear],
      do: :ok,
      else: {:error, :requires_spear}
  end

  def validate(%MobState{}, _target, _level, _definition), do: :ok

  @impl Active
  @spec cast(Active.caster(), Active.target(), pos_integer(), Definition.t()) ::
          {:ok, Active.caster()} | {:error, atom()}
  def cast(caster, {:unit, target_id}, level, definition) do
    with {:ok, target} <- Combat.resolve_combatant(target_id) do
      break = choose_break({target.unit_type, target.unit_id})
      ratio = 50 + 10 * level

      case Combat.execute_skill_attack(caster, target_id,
             skill_id: definition.id,
             skill_level: level,
             skill_ratio: if(break == :neck, do: 2 * ratio, else: ratio),
             skip_crit: true,
             skip_range: true,
             report_hit: true
           ) do
        {:ok, %{hit?: true}} ->
          maybe_apply_break(caster, target, break, level)
          {:ok, caster}

        {:ok, %{hit?: false}} ->
          {:ok, caster}

        {:error, _reason} = error ->
          error
      end
    end
  end

  defp maybe_apply_break(caster, target, break, level) do
    chance = max(50 * (level + 1) - div(270 * target.base_stats.str, 100), 0)

    if :rand.uniform(100) <= chance do
      type = caster.__struct__.get_unit_type(caster)
      id = caster.__struct__.get_unit_id(caster)

      _ =
        Interpreter.apply_status(target.unit_type, target.unit_id, :sc_jointbeat,
          val1: level,
          val2: break,
          duration: 30_000,
          caster_id: id,
          source_type: type
        )
    end

    :ok
  end

  @doc "Keeps a previously broken neck, or chooses one of six fresh wounds."
  @spec choose_break({atom(), integer()}) :: atom()
  def choose_break({unit_type, unit_id}) do
    case StatusStorage.get_status(unit_type, unit_id, :sc_jointbeat) do
      %StatusEntry{val2: :neck} -> :neck
      _ -> Enum.random(Jointbeat.breaks())
    end
  end
end
