defmodule Aesir.ZoneServer.Mmo.Skills.Professor.PfSoulburn do
  @moduledoc """
  Soul Siphon (PF_SOULBURN). Targets players only. A `30 + 10 * level` percent
  chance (70% at most) to empty the target's SP; at level 5 the target also
  takes a magic attack whose base is twice the SP it had, reduced by MDEF but
  ignoring element and cards. On a failed roll the same
  happens to the Professor instead: their SP empties and, at level 5, the same
  magic attack strikes them on twice the SP they have left after paying the
  cost, reduced by their own MDEF, which can kill them. A monster's SP never empties.

  Identical in both modes: 80 to 120 SP, 9 cells, a 10 s cooldown (15 s at
  level 5). Monsters cast it through `mob_cast/5`.
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 375,
    name: :pf_soulburn,
    ignore_atk_card: true,
    requires: [],
    display_name: "Soul Siphon",
    max_level: 5,
    target_type: :target_enemy,
    damage_type: :damage,
    ignore_def_card: true,
    ignore_element: true,
    damage_kind: :magic,
    range: 9,
    sp_cost: [80, 90, 100, 110, 120],
    cooldown: [10_000, 10_000, 10_000, 10_000, 15_000]

  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Combat.MagicAttack
  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.Skill.Definition
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Resource

  @behaviour Active

  @doc "Percent chance the siphon lands on the target: `30 + 10 * level`, at most 70."
  @spec success_chance(pos_integer()) :: 40 | 50 | 60 | 70
  def success_chance(level), do: min(30 + 10 * level, 70)

  @doc """
  Siphons the target or backfires. `opts` accepts `:rng`, a
  `(pos_integer() -> pos_integer())` roll defaulting to `&:rand.uniform/1`.
  """
  @impl Active
  @spec cast(Active.caster(), Active.target(), pos_integer(), Definition.t(), keyword()) ::
          {:ok, Active.caster()} | {:error, atom()}
  def cast(caster, {:unit, target_id}, level, definition, opts \\ []) do
    rng = Keyword.get(opts, :rng, &:rand.uniform/1)

    case Combat.resolve_combatant(target_id) do
      {:ok, %{unit_type: :player}} -> siphon(caster, {:player, target_id}, level, definition, rng)
      {:ok, _not_a_player} -> {:error, :invalid_target}
      error -> error
    end
  end

  @impl Active
  @spec mob_cast(MobState.t(), term(), pos_integer(), Definition.t(), map()) ::
          :ok | {:error, atom()}
  def mob_cast(%MobState{}, {:unit, type, _id}, _level, _definition, _row) when type != :player,
    do: {:error, :invalid_target}

  def mob_cast(%MobState{} = caster, {:unit, type, id}, level, definition, _row) do
    with {:ok, _caster} <- siphon(caster, {type, id}, level, definition, &:rand.uniform/1),
         do: :ok
  end

  defp siphon(caster, target, level, definition, rng) do
    if rng.(100) <= success_chance(level),
      do: drain(caster, target, level, definition),
      else: backfire(caster, level, definition)
  end

  defp drain(caster, target, level, definition) do
    with {:ok, sp} <- Resource.read(target, :sp) do
      if level == 5, do: burn(caster, target, sp * 2, definition)
      Resource.drain_sp_percent(target, 100)
      {:ok, caster}
    end
  end

  defp burn(caster, target, damage, definition) do
    MagicAttack.execute_magic_attack(caster, target,
      skill_id: definition.id,
      skill_level: 5,
      base_damage: damage,
      skip_range: true
    )
  end

  defp backfire(caster, level, definition) do
    if level == 5 do
      MagicAttack.execute_self_magic_attack(caster,
        skill_id: definition.id,
        skill_level: 5,
        base_damage: own_sp(caster) * 2
      )
    end

    {:ok, empty_sp(caster)}
  end

  defp own_sp(%PlayerState{stats: %{current_state: %{sp: sp}}}), do: sp
  defp own_sp(%MobState{sp: sp}), do: sp

  defp empty_sp(%PlayerState{stats: %{current_state: current} = stats} = caster),
    do: %{caster | stats: %{stats | current_state: %{current | sp: 0}}}

  # A monster's SP is never drained.
  defp empty_sp(%MobState{} = caster), do: caster
end
