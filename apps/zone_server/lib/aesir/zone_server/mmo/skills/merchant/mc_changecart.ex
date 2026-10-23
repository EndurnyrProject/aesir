defmodule Aesir.ZoneServer.Mmo.Skills.Merchant.McChangecart do
  @moduledoc """
  Change Cart (MC_CHANGECART, id 154). Self skill that upgrades the visible cart
  sprite tier to the highest one the caster's base level permits.

  Requires a cart mounted when the cast begins (else `{:error, :cart}`). The
  base-level gate and the tier selection live in `CartHandler.change_cart_tier/2`, which uses the client's
  base-level thresholds; when the caster's base level grants no tier
  above the current one the cast fizzles without spending SP.

  Renewal and pre-renewal agree: the cart look is chosen by base level and the skill has no other effect.
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
    quest_owner_job: :merchant,
    damage_kind: :none

  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Unit.Player.Handlers.CartHandler

  @behaviour Active

  @doc "The cast begins only with a cart mounted; without one the reply names the cart."
  @impl Active
  def begin_attempt(%{cart_type: 0}, _target, _level, _definition), do: {:error, :cart}
  def begin_attempt(caster, _target, _level, _definition), do: {:ok, caster}

  @impl Active
  def cast(caster, :self, _level, _definition) do
    case CartHandler.change_cart_tier(caster, base_level(caster)) do
      {:ok, updated} ->
        {:ok, updated}

      # The reference always succeeds and pays; the tier choice is a separate
      # packet with its own level gate.
      {:error, :no_cart_upgrade} ->
        {:ok, caster}
    end
  end

  @spec base_level(map()) :: non_neg_integer()
  defp base_level(%{stats: %{progression: %{base_level: level}}}), do: level
end
