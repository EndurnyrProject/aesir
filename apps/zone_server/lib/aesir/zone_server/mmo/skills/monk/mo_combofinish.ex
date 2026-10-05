defmodule Aesir.ZoneServer.Mmo.Skills.Monk.MoCombofinish do
  @moduledoc """
  Raging Thrust (MO_COMBOFINISH).

  A single-target strike that spends one spirit sphere. Landing it closes the
  combo chain unless the caster can follow it up, counting the spheres left
  after this one is paid: a Monk with Asura Strike, Fury, and four spheres left,
  or a Champion with Glacier Fist and one sphere or Chain Crush Combo and two.
  Any of those opens an `:extremity` window (see `Monk.Combo`).

  The reference declares a 5x5 splash area, but the splash only applies while a
  Soul Linker's Monk spirit is linked; Aesir has no Soul Linker, so the strike
  stays single-target and the area is metadata only.

  Renewal: 550 plus 50 per level plus STR percent for 2 plus level SP.
  Pre-renewal: 240 plus 60 per level percent for 10 plus level SP. Both modes
  spend one sphere.
  """

  use Aesir.ZoneServer.Mmo.Skill,
    id: 273,
    name: :mo_combofinish,
    display_name: "Raging Thrust",
    max_level: 5,
    target_type: :target_enemy,
    damage_type: :damage,
    range: -2,
    splash_radius: 2,
    sp_cost: [renewal: [3, 4, 5, 6, 7], pre_renewal: [11, 12, 13, 14, 15]],
    sphere_cost: List.duplicate(1, 5),
    after_cast_delay: List.duplicate(1_000, 5)

  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.Skill.Definition
  alias Aesir.ZoneServer.Mmo.Skills.Monk.Combo
  alias Aesir.ZoneServer.Mmo.Skills.Monk.Formulas
  alias Aesir.ZoneServer.Unit.Player.PlayerState

  @behaviour Active

  @impl Active
  @spec validate(PlayerState.t(), Active.target(), pos_integer(), Definition.t()) ::
          :ok | {:error, :invalid_combo}
  def validate(caster, {:unit, target_id}, _level, _definition) do
    case Combo.validate(caster.combo, :thrust, target_id, now()) do
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

    with {:ok, target} <- Combo.validate(caster.combo, :thrust, target_id, now),
         {:ok, target_type, _position} <- Combat.resolve_target_position(target_id),
         {:ok, ^target} <- Combo.validate(caster.combo, :thrust, {target_type, target_id}, now),
         :ok <-
           Combat.execute_skill_attack(
             caster,
             target_id,
             skill_options(caster, level, definition)
           ),
         duration <- Enum.at(definition.after_cast_delay, level - 1, 0),
         {:ok, combo} <-
           Combo.open_follow_up(
             caster,
             :thrust,
             :thrust,
             target,
             now,
             duration,
             Enum.at(definition.sphere_cost, level - 1, 0)
           ) do
      {:ok, %{caster | combo: combo}}
    else
      {:error, _reason} = error -> error
    end
  end

  def cast(_caster, _target, _level, _definition), do: {:error, :invalid_combo}

  defp skill_options(caster, level, definition) do
    [
      skill_id: definition.id,
      skill_level: level,
      skill_ratio: Formulas.thrust_ratio(level, caster.stats.base_stats.str),
      hit_divisions: Formulas.thrust_hit_count(),
      skip_crit: true
    ]
  end

  defp now, do: System.monotonic_time(:millisecond)
end
