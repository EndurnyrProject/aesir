defmodule Aesir.ZoneServer.Mmo.Skills.AssassinCross.AscMeteorassault do
  @moduledoc """
  Meteor Assault strikes every enemy within two cells of the caster, traps
  included whoever placed them, with one weapon hit each that never crits.

  Every character the hit's additional effects reach draws one of blindness,
  stun or bleeding with equal odds, then rolls it at 5 percent plus 5 percent per
  level against the target's resistance. Bleeding carries the caster as its
  source. Cicada Skin Shed would not dodge it.

  Renewal: 200 percent plus 120 percent per level, scaled by the caster's base
  level above 99; a quarter-second cast plus a quarter-second fixed cast and a
  half-second cooldown; blindness lasts 20 seconds. Enchant Deadly Poison and the
  weapon element property never raise it.

  Classic: 40 percent plus 40 percent per level, ignoring attack cards (so
  neither Enchant Deadly Poison nor Advanced Katar Mastery raises it); a
  half-second cast and a half-second after-cast delay; blindness lasts 30
  seconds.

  Both modes: 10 to 28 SP; stun lasts 5 seconds and bleeding 120 seconds.
  Monsters cast it too, centred on themselves.
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 406,
    name: :asc_meteorassault,
    requires: [],
    display_name: "Meteor Assault",
    max_level: 10,
    target_type: :self,
    damage_type: :damage,
    damage_kind: :weapon,
    damage_splash: true,
    splash_radius: 2,
    ignore_auto_guard: true,
    ignore_atk_card: [renewal: false, pre_renewal: true],
    sp_cost: [10, 12, 14, 16, 18, 20, 22, 24, 26, 28],
    cast_time: [renewal: List.duplicate(250, 10), pre_renewal: List.duplicate(500, 10)],
    fixed_cast_time: [renewal: List.duplicate(250, 10), pre_renewal: []],
    cooldown: [renewal: List.duplicate(500, 10), pre_renewal: []],
    after_cast_delay: [renewal: [], pre_renewal: List.duplicate(500, 10)]

  alias Aesir.Commons.GameMode
  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Combat.LevelModifier
  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.Skill.Definition
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.Player.PlayerState

  @behaviour Active

  @default_rng &:rand.uniform/1
  @riders {:sc_blind, :sc_stun, :sc_bleeding}

  @impl Active
  @spec cast(Active.caster(), Active.target(), pos_integer(), Definition.t()) ::
          {:ok, Active.caster()}
  def cast(caster, _target, level, definition) do
    caster
    |> Combat.execute_splash_attack({caster.x, caster.y}, definition.splash_radius,
      skill_id: definition.id,
      skill_level: level,
      skill_ratio: skill_ratio(level, base_level(caster)),
      skip_crit: true,
      target_skill_units: true,
      typed_results: true,
      delivery: {:splash, nil}
    )
    |> Enum.each(&inflict(caster, &1, level))

    {:ok, caster}
  end

  @doc "The weapon ratio at `level` for a caster of `base_level`."
  @spec skill_ratio(pos_integer(), non_neg_integer()) :: pos_integer()
  def skill_ratio(level, base_level) do
    case GameMode.mode() do
      :renewal -> LevelModifier.skill_ratio(200 + 120 * level, base_level)
      :pre_renewal -> 40 + 40 * level
    end
  end

  @doc "How long the mode makes `status` last when Meteor Assault inflicts it."
  @spec rider_duration(:sc_blind | :sc_stun | :sc_bleeding) :: pos_integer()
  def rider_duration(:sc_blind),
    do: if(GameMode.mode() == :renewal, do: 20_000, else: 30_000)

  def rider_duration(:sc_stun), do: 5_000
  def rider_duration(:sc_bleeding), do: 120_000

  defp inflict(_caster, {:skill_unit, _cell_id}, _level), do: :ok

  defp inflict(caster, {target_type, target_id}, level) do
    {source_type, caster_id} = caster_ref(caster)
    status = elem(@riders, rng().(3) - 1)

    params =
      [
        val1: level,
        success_rate: 5 + 5 * level,
        duration: rider_duration(status),
        caster_id: caster_id,
        source_type: source_type
      ] ++ if(status == :sc_bleeding, do: [val2: caster_id], else: [])

    _ = StatusInterpreter.apply_status(target_type, target_id, status, params)
    :ok
  end

  defp base_level(%PlayerState{stats: %{progression: %{base_level: level}}}), do: level
  defp base_level(%MobState{mob_data: %{level: level}}), do: level
  defp base_level(_caster), do: 0

  defp caster_ref(%PlayerState{character_id: id}), do: {:player, id}
  defp caster_ref(%MobState{instance_id: id}), do: {:mob, id}

  defp rng, do: Application.get_env(:zone_server, :meteor_assault_rng, @default_rng)
end
