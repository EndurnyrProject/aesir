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
    no_target_self: true,
    name: :mo_combofinish,
    # Every weapon but a bow or a two-handed staff.
    require_weapon: [
      :fist,
      :dagger,
      :one_handed_sword,
      :two_handed_sword,
      :one_handed_spear,
      :two_handed_spear,
      :one_handed_axe,
      :two_handed_axe,
      :mace,
      :two_handed_mace,
      :staff,
      :knuckle,
      :musical,
      :whip,
      :book,
      :katar,
      :revolver,
      :rifle,
      :gatling,
      :shotgun,
      :grenade,
      :huuma
    ],
    display_name: "Raging Thrust",
    max_level: 5,
    target_type: :target_enemy,
    damage_type: :damage,
    range: -2,
    splash_radius: 2,
    sp_cost: [renewal: [3, 4, 5, 6, 7], pre_renewal: [11, 12, 13, 14, 15]],
    sphere_cost: List.duplicate(1, 5),
    after_cast_delay: List.duplicate(1_000, 5),
    damage_splash: true

  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.Skill.Definition
  alias Aesir.ZoneServer.Mmo.Skills.Monk.Combo
  alias Aesir.ZoneServer.Mmo.Skills.Monk.Formulas
  alias Aesir.ZoneServer.Unit.Player.PlayerState

  @behaviour Active

  @doc "Starts only while a Raging Quadruple Blow window is open; otherwise refused silently."
  @impl Active
  @spec begin_attempt(PlayerState.t(), Active.target(), pos_integer(), Definition.t()) ::
          {:ok, PlayerState.t()} | {:error, :invalid_combo}
  def begin_attempt(caster, _target, _level, _definition),
    do: with(:ok <- Combo.check(caster.combo, :thrust, now()), do: {:ok, caster})

  @impl Active
  @spec cast(PlayerState.t(), Active.target(), pos_integer(), Definition.t()) ::
          {:ok, PlayerState.t()} | {:error, atom()}
  def cast(caster, {:unit, target_id}, level, definition) do
    now = now()

    with :ok <-
           Combat.execute_skill_attack(
             caster,
             target_id,
             skill_options(caster, level, definition)
           ),
         duration <- Enum.at(definition.after_cast_delay, level - 1, 0),
         {:ok, combo} <- Combo.open_follow_up(caster, :thrust, now, duration) do
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
