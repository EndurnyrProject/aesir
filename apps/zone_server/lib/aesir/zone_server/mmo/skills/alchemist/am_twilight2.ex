defmodule Aesir.ZoneServer.Mmo.Skills.Alchemist.AmTwilight2 do
  @moduledoc """
  Twilight Alchemy 2 (AM_TWILIGHT2).

  A spirit skill on the Alchemist tree: it is never learned with skill points
  and is usable once granted. It costs 200 SP and 200 Medicine Bowls, and its
  cast ignores DEX. When the cast begins, an online Super Novice (of any kind)
  must be in the caster's party, or the cast fails with nothing spent.

  The skill shows itself, then brews one Pharmacy batch of 200 White Slim Potions
  (`TwilightAlchemy`): the copies that succeed are added as one stack. A batch
  that cannot be made, or where no copy succeeds, fails the cast after it showed
  itself, with the SP and the Medicine Bowls spent.

  Renewal: a 3 s fixed cast. Pre-renewal: a 3 s cast and a 10 s delay. No
  monster casts it.
  """

  use Aesir.ZoneServer.Mmo.Skill,
    id: 497,
    name: :am_twilight2,
    display_name: "Twilight Alchemy 2",
    max_level: 1,
    target_type: :self,
    damage_type: :no_damage,
    damage_kind: :none,
    quest_skill: true,
    quest_owner_job: :alchemist,
    ignore_dex: true,
    sp_cost: [200],
    item_cost: [%{id: 7134, amount: 200}],
    cast_time: [renewal: [], pre_renewal: [3_000]],
    fixed_cast_time: [renewal: [3_000], pre_renewal: []],
    after_cast_delay: [renewal: [], pre_renewal: [10_000]]

  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.Skill.Definition
  alias Aesir.ZoneServer.Mmo.Skills.Alchemist.TwilightAlchemy
  alias Aesir.ZoneServer.Unit.Player.PlayerState

  @behaviour Active

  @super_novices [:super_novice, :super_baby, :super_novice_e, :super_baby_e, :hyper_novice]

  @impl Active
  @spec begin_attempt(PlayerState.t(), Active.target(), pos_integer(), Definition.t()) ::
          {:ok, PlayerState.t()} | {:error, :skill_failed}
  def begin_attempt(caster, _target, _level, _definition),
    do: TwilightAlchemy.require_party_member(caster, @super_novices)

  @impl Active
  @spec cast(PlayerState.t(), Active.target(), pos_integer(), Definition.t()) ::
          {:ok, PlayerState.t()} | {:failed, PlayerState.t(), :skill_failed, :after_effect}
  def cast(%PlayerState{} = caster, :self, _level, _definition),
    do: TwilightAlchemy.cast_batch(caster, 547, 200)
end
