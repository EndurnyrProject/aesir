defmodule Aesir.ZoneServer.Mmo.Skills.Merchant.McChangecart do
  @moduledoc """
  Change Cart (MC_CHANGECART, id 154). Self skill that upgrades the visible cart
  sprite tier to the highest one the caster's base level permits.

  Requires a cart mounted (else `{:error, :no_cart}`). The base-level gate and the
  tier selection live in `CartHandler.change_cart_tier/2`, which mirrors rAthena's
  `clif_parse_ChangeCart` thresholds; when the caster's base level grants no tier
  above the current one the cast fizzles without spending SP.
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 154,
    name: :mc_changecart,
    display_name: "Change Cart",
    max_level: 1,
    target_type: :self,
    damage_type: :no_damage,
    sp_cost: [40],
    quest_skill: true,
    quest_owner_job: :merchant

  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Unit.Player.Handlers.CartHandler

  @behaviour Active

  @impl Active
  def cast(%{cart_type: 0}, :self, _level, _definition), do: {:error, :no_cart}

  def cast(caster, :self, _level, _definition) do
    CartHandler.change_cart_tier(caster, base_level(caster))
  end

  @spec base_level(map()) :: non_neg_integer()
  defp base_level(%{stats: %{progression: %{base_level: level}}}), do: level
end
