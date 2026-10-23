defmodule Aesir.ZoneServer.Mmo.Skills.Champion.ChChaincrush do
  @moduledoc """
  Chain Crush Combo (CH_CHAINCRUSH), a Champion combo skill.

  Cast instantly inside the window Raging Thrust or Glacier Fist opens on the
  retained target, never after itself. The blow is one damage roll shown as one
  hit per two levels. With Asura Strike known, Fury active, and one sphere left
  it opens the window toward an instant Asura that spends every held sphere
  (see `Monk.Combo`).

  Renewal: `200*lv * BaseLv / 100` percent for one sphere.
  Pre-renewal: `400 + 100*lv` percent for two spheres; the window also opens
  toward Glacier Fist with one sphere left, so the two can loop. Both cost
  `2 + 2*lv` SP.
  """

  use Aesir.ZoneServer.Mmo.Skill,
    id: 372,
    no_target_self: true,
    name: :ch_chaincrush,
    display_name: "Chain Crush Combo",
    max_level: 10,
    target_type: :target_enemy,
    damage_type: :damage,
    range: -2,
    hit_count: [-1, -1, -2, -2, -3, -3, -4, -4, -5, -5],
    sp_cost: [4, 6, 8, 10, 12, 14, 16, 18, 20, 22],
    sphere_cost: [renewal: List.duplicate(1, 10), pre_renewal: List.duplicate(2, 10)],
    after_cast_delay: List.duplicate(1_000, 10)

  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.Skill.Definition
  alias Aesir.ZoneServer.Mmo.Skills.Champion.Formulas
  alias Aesir.ZoneServer.Mmo.Skills.Monk.Combo
  alias Aesir.ZoneServer.Mmo.Skills.Monk.Root
  alias Aesir.ZoneServer.Unit.Player.PlayerState

  @behaviour Active

  @accepted_stages [:extremity, :tiger_fist]

  @doc """
  Starts only while the window after Raging Thrust or Glacier Fist is open;
  otherwise refused silently.
  """
  @impl Active
  @spec begin_attempt(PlayerState.t(), Active.target(), pos_integer(), Definition.t()) ::
          {:ok, PlayerState.t()} | {:error, :invalid_combo}
  def begin_attempt(caster, _target, _level, _definition),
    do: with(:ok <- Combo.check(caster.combo, @accepted_stages, now()), do: {:ok, caster})

  @impl Active
  @spec cast(PlayerState.t(), Active.target(), pos_integer(), Definition.t()) ::
          {:ok, PlayerState.t()} | {:error, atom()}
  def cast(caster, {:unit, target_id}, level, definition) do
    now = now()
    duration = Enum.at(definition.after_cast_delay, level - 1, 0)

    with :ok <- Root.check_cast(:player, caster.character_id, definition.id),
         {:ok, target_type, _position} <- Combat.resolve_target_position(target_id),
         :ok <-
           Combat.execute_skill_attack(
             caster,
             target_id,
             attack_options(caster, level, definition)
           ),
         {:ok, combo} <-
           Combo.open_follow_up(caster, :chain_crush, {target_type, target_id}, now, duration) do
      {:ok, %{caster | combo: combo}}
    end
  end

  def cast(_caster, _target, _level, _definition), do: {:error, :invalid_combo}

  defp attack_options(caster, level, definition) do
    [
      skill_id: definition.id,
      skill_level: level,
      skill_ratio: Formulas.chain_crush_ratio(level, caster.stats.progression.base_level),
      hit_divisions: Definition.hit_count_at_level(definition, level),
      skip_crit: true
    ]
  end

  defp now, do: System.monotonic_time(:millisecond)
end
