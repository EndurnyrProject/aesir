defmodule Aesir.ZoneServer.Mmo.MobSkill.Archetype do
  @moduledoc """
  Behaviour every mob-skill archetype implements.

  An archetype is the generic behavior a family of rAthena mob skills reduces to
  (elemental nuke, status attack, ground AoE, heal, summon, teleport). The
  `MobSkill.Catalog` maps each concrete skill name to an archetype atom plus its
  static params; the `MobSkill.Executor` picks the archetype module and calls
  `apply/4`.

  Contract:

    * `caster` is the casting mob's `MobState.t()`.
    * `target` is already resolved by the Executor into whatever shape the
      archetype needs (a target unit id, the caster itself, a ground cell, ...);
      an archetype never runs its own target selection.
    * `params` are the catalog's static params for the skill (e.g.
      `%{element: :fire}` or `%{status: :sc_stun}`).
    * `level` is the row's skill level.

  Implementations reuse the caster-agnostic combat/status primitives and return
  `:ok` on success or `{:error, reason}` when the effect could not be applied
  (e.g. the target became invalid). They must not raise for expected
  no-op/invalid-target situations.
  """

  alias Aesir.ZoneServer.Unit.Mob.MobState

  @callback apply(
              caster :: MobState.t(),
              target :: term(),
              params :: map(),
              level :: pos_integer()
            ) :: :ok | {:error, term()}
end
