defmodule Aesir.ZoneServer.Mmo.Skills.Merchant.McVending do
  @moduledoc """
  Vending (MC_VENDING, id 41) prepares a merchant's cart shop.

  Renewal and pre-renewal agree: use is self-targeted, requires a mounted cart,
  and pays its 30 SP before preparation is offered. Canceling the editor does
  not refund that cost, and submitting listings does not charge it again.
  The selected level determines the editor's slot allowance, up to 12.

  The effect stages preparation on the player; the owning session publishes
  the connection-bound grant after the normal cast has settled.
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 41,
    name: :mc_vending,
    display_name: "Vending",
    max_level: 10,
    target_type: :self,
    damage_type: :no_damage,
    range: 1,
    sp_cost: [30, 30, 30, 30, 30, 30, 30, 30, 30, 30],
    damage_kind: :none

  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Unit.Player.PlayerState

  @behaviour Active

  @max_slots 12

  @impl Active
  def begin_attempt(%PlayerState{cart_type: 0}, _target, _level, _definition), do: {:error, :cart}
  def begin_attempt(caster, _target, _level, _definition), do: {:ok, caster}

  @impl Active
  def cast(%PlayerState{} = caster, _target, level, _definition) do
    {:ok, %{caster | pending_vending_setup: %{level: level}}}
  end

  def cast(caster, _target, _level, _definition), do: {:ok, caster}

  @doc "Maximum number of shop slots offered for the selected Vending level."
  @spec max_slots(pos_integer()) :: pos_integer()
  def max_slots(level) when is_integer(level) and level > 0, do: min(2 + level, @max_slots)
end
