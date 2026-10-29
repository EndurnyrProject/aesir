defmodule Aesir.ZoneServer.Mmo.Skills.AssassinCross.AscCdp do
  @moduledoc """
  Create Deadly Poison brews one Poison Bottle from its seven materials.

  The SP is spent first. The brew needs every material held, room for one more
  bottle and no other skill's menu open; otherwise nothing is consumed and the
  caster is told the stuff is insufficient. Otherwise the materials are consumed
  and the attempt succeeds with a chance of 20 percent plus 0.4 percent per DEX
  and 0.2 percent per LUK. A success adds an unsigned Poison Bottle; a failure
  costs the caster a quarter of maximum HP, which can kill, and also reports the
  stuff as insufficient.

  Both modes cost 50 SP with no cast time; the after-cast delay is five seconds in
  renewal and half a second in classic. Only players cast it.
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 407,
    name: :asc_cdp,
    display_name: "Create Deadly Poison",
    max_level: 1,
    target_type: :self,
    damage_type: :no_damage,
    damage_kind: :none,
    sp_cost: [50],
    after_cast_delay: [renewal: [5_000], pre_renewal: [500]]

  alias Aesir.ZoneServer.Mmo.ItemManagement.Production.Forge
  alias Aesir.ZoneServer.Mmo.ItemManagement.Production.Produce
  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.Skill.Definition
  alias Aesir.ZoneServer.Unit.Player.PlayerState

  @behaviour Active

  @poison_bottle 678
  # A skill brewing directly accepts its recipe at any item level.
  @direct_trigger -1

  @impl Active
  @spec cast(PlayerState.t(), Active.target(), pos_integer(), Definition.t()) ::
          {:ok, PlayerState.t()} | {:failed, PlayerState.t(), :stuff_insufficient}
  def cast(%PlayerState{} = caster, :self, _level, definition) do
    with {:ok, recipe} <-
           Produce.producible(caster, @poison_bottle, @direct_trigger, caster.open_menu_skill_id),
         {:ok, %{pending_production_result: %{success: true}} = made} <-
           Forge.run_skill(caster, recipe, definition.id) do
      {:ok, made}
    else
      {:ok, failed} -> {:failed, failed, :stuff_insufficient}
      _not_producible -> {:failed, caster, :stuff_insufficient}
    end
  end
end
