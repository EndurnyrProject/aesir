defmodule Aesir.ZoneServer.Mmo.MobSkill.Archetype.Dispel do
  @moduledoc """
  Strips every dispellable status from the mob's player target (`SA_DISPELL`).

  The success roll lives here, not in the primitive: `StatusEffect.Dispel.dispel/1`
  takes no level and always removes, mirroring rAthena's split between
  `dispell.cpp:36-72`'s `rnd()%100 >= 50+10*lv` failure check and the removal
  loop it guards. `Skills.SaDispell` rolls the same odds for the player cast.

  Removal is the primitive's business, including its documented rAthena
  behavior that debuffs are dispelled too — only `no_dispel` statuses survive.

  Mob -> player dispel is PvE: it never reaches `Skill.Targeting.validate_enemy`'s
  PvP branch, because the attacker is not a player (and the mob cast path does
  not consult that gate at all). That structure, not a special case, is what
  exempts this cast from the PvP gate.

  `apply/4` runs inside the caster's `MobSession` process (from
  `:cast_complete`); the removal is a cross-process-safe interpreter operation
  on the target.
  """

  @behaviour Aesir.ZoneServer.Mmo.MobSkill.Archetype

  alias Aesir.ZoneServer.Mmo.StatusEffect.Dispel
  alias Aesir.ZoneServer.Unit.Mob.MobState

  @impl true
  def apply(%MobState{} = caster, target, params, level),
    do: apply(caster, target, params, level, [])

  @doc """
  Rolls `50 + 10*lv`% and, on success, dispels the resolved player target.

  `opts` accepts `:rng`, a `(pos_integer() -> pos_integer())` function for the
  success roll, defaulting to `&:rand.uniform/1`.
  """
  @spec apply(MobState.t(), term(), map(), pos_integer(), keyword()) :: :ok | {:error, term()}
  def apply(caster, target, params, level, opts)

  def apply(%MobState{}, {:unit, :player, player_id}, _params, level, opts) do
    rng = Keyword.get(opts, :rng, &:rand.uniform/1)

    if rng.(100) <= 50 + 10 * level do
      Dispel.dispel({:player, player_id})
    end

    :ok
  end

  def apply(%MobState{}, _target, _params, _level, _opts), do: {:error, :invalid_target}
end
