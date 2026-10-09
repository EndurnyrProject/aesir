defmodule Aesir.ZoneServer.Mmo.Skills.Champion.ChTigerfist do
  @moduledoc """
  Glacier Fist (CH_TIGERFIST), a Champion combo skill.

  Cast instantly inside the window Raging Thrust opens on the retained target,
  it spends one spirit sphere and strikes once. A landed hit has a `10 + 10*lv`
  percent chance to immobilise the target (`sc_ankle`) for `2000*lv` ms, a
  fifth of that against a boss, shortened by the target's AGI and never below
  `15 * (caster BaseLv + 100)` ms. With Chain Crush Combo known and two spheres
  left it opens the window toward Chain Crush (see `Monk.Combo`).

  Renewal: `(500 + 150*lv) * BaseLv / 100` percent, usable only after Raging
  Thrust. Pre-renewal: `40 + 100*lv` percent, usable after Raging Thrust or
  Chain Crush Combo, so the two can loop while spheres last. Both cost
  `2 + 2*lv` SP.
  """

  use Aesir.ZoneServer.Mmo.Skill,
    id: 371,
    name: :ch_tigerfist,
    display_name: "Glacier Fist",
    max_level: 5,
    target_type: :target_enemy,
    damage_type: :damage,
    range: -2,
    sp_cost: [4, 6, 8, 10, 12],
    sphere_cost: List.duplicate(1, 5),
    after_cast_delay: List.duplicate(1_000, 5)

  alias Aesir.Commons.GameMode
  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.Skill.Definition
  alias Aesir.ZoneServer.Mmo.Skills.Champion.Formulas
  alias Aesir.ZoneServer.Mmo.Skills.Monk.Combo
  alias Aesir.ZoneServer.Mmo.Skills.Monk.Root
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Mmo.StatusEffect.Resistance
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @behaviour Active

  @impl Active
  @spec validate(PlayerState.t(), Active.target(), pos_integer(), Definition.t()) ::
          :ok | {:error, :invalid_combo}
  def validate(caster, {:unit, target_id}, _level, _definition) do
    case Combo.validate(caster.combo, accepted_stages(), target_id, now()) do
      {:ok, _target} -> :ok
      {:error, _reason} = error -> error
    end
  end

  def validate(_caster, _target, _level, _definition), do: {:error, :invalid_combo}

  @impl Active
  @spec cast(PlayerState.t(), Active.target(), pos_integer(), Definition.t()) ::
          {:ok, PlayerState.t()} | {:error, atom()}
  def cast(caster, {:unit, target_id}, level, definition) do
    now = now()
    stages = accepted_stages()
    own_cost = Enum.at(definition.sphere_cost, level - 1, 0)
    duration = Enum.at(definition.after_cast_delay, level - 1, 0)

    with :ok <- Root.check_cast(:player, caster.character_id, definition.id),
         {:ok, _target} <- Combo.validate(caster.combo, stages, target_id, now),
         {:ok, target_type, _position} <- Combat.resolve_target_position(target_id),
         {:ok, target} <- Combo.validate(caster.combo, stages, {target_type, target_id}, now),
         {:ok, %{hit?: hit?}} <-
           Combat.execute_skill_attack(caster, target_id, attack_options(caster, level, own_cost)),
         :ok <- if(hit?, do: maybe_immobilise(caster, target, level), else: :ok),
         {:ok, combo} <-
           Combo.open_follow_up(caster, :tiger_fist, stages, target, now, duration, own_cost) do
      {:ok, %{caster | combo: combo}}
    end
  end

  def cast(_caster, _target, _level, _definition), do: {:error, :invalid_combo}

  defp accepted_stages do
    case GameMode.mode() do
      :renewal -> [:extremity]
      :pre_renewal -> [:extremity, :chain_crush]
    end
  end

  defp attack_options(caster, level, own_cost) do
    [
      skill_id: 371,
      skill_level: level,
      skill_ratio: Formulas.glacier_ratio(level, caster.stats.progression.base_level),
      skip_crit: true,
      report_hit: true,
      spirit_spheres: Combo.spheres_after(caster, own_cost)
    ]
  end

  # The roll and an already-immobilised target are not cast failures.
  defp maybe_immobilise(caster, {target_type, target_id}, level) do
    with true <- Resistance.roll_success(Formulas.glacier_ankle_chance(level)),
         {:ok, %{stats: %{agi: agi}, boss_flag: boss?}} <-
           UnitRegistry.get_unit_info(target_type, target_id) do
      duration =
        Formulas.glacier_ankle_duration(level, agi, boss?, caster.stats.progression.base_level)

      _ =
        StatusInterpreter.apply_status(target_type, target_id, :sc_ankle,
          duration: duration,
          caster_id: caster.character_id,
          source_type: :player
        )
    end

    :ok
  end

  defp now, do: System.monotonic_time(:millisecond)
end
