defmodule Aesir.ZoneServer.Mmo.Skills.Merchant.McCartrevolution do
  @moduledoc """
  Cart Revolution (MC_CARTREVOLUTION, id 153). Physical neutral splash attack with
  knockback whose damage scales with the current cart weight; requires a mounted
  cart, else `{:error, :no_cart}`.

  Max level 1, 1-cell splash, 2 cells of knockback, 12 SP, and the damage is
  always resolved as neutral element whatever the weapon carries. Like Arrow
  Shower the splash is centred on the target's cell and its native displacement
  goes through `Combat.execute_splash_attack` for one combined knockback.

  ## Damage formula

  `150 + 100 * cart_weight / cart_weight_max` percent of weapon damage: an empty
  cart hits for 150%, a full cart for 250%. `Cart.Weight.current_weight/1` and
  `Cart.Weight.max_weight/0` (`80_000`) use the one weight unit Aesir uses
  everywhere (item-db weight, e.g. Red Potion = 70).

  Renewal and pre-renewal agree: 150% weapon damage plus 1% per 1% of cart load (250% at a full cart, and the flat 250% for a caster without a cart), always dealt as neutral element regardless of the weapon, a 1-cell splash around the target, 2 cells of knockback, 12 SP, one cell of reach, and a mounted cart to cast.
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 153,
    name: :mc_cartrevolution,
    display_name: "Cart Revolution",
    max_level: 1,
    target_type: :target_enemy,
    damage_type: :damage,
    range: 1,
    element: :neutral,
    knockback: 2,
    splash_radius: 1,
    sp_cost: [12],
    quest_skill: true,
    quest_owner_job: :merchant

  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Unit.Cart.Weight

  @behaviour Active

  @base_ratio 150

  @impl Active
  def cast(%{cart_type: 0}, _target, _level, _definition), do: {:error, :no_cart}

  def cast(caster, {:unit, target_id}, level, definition) do
    with {:ok, %{position: {x, y}}} <- Combat.resolve_combatant(target_id) do
      opts = [
        skill_id: definition.id,
        skill_level: level,
        skill_ratio: caster_ratio(caster),
        skip_crit: true,
        element: :neutral,
        base_distance: definition.knockback,
        origin: {x, y},
        native_target_types: [:mob]
      ]

      _ = Combat.execute_splash_attack(caster, {x, y}, definition.splash_radius, opts)
      {:ok, caster}
    end
  end

  @max_ratio 250

  defp caster_ratio(%{cart: cart}), do: skill_ratio(cart)
  defp caster_ratio(_caster_without_cart), do: @max_ratio

  @doc """
  The skill ratio for the current cart load: `150 + 100 * current/max` (clamped at
  250% by the cart cap). Heavier carts hit harder. A caster with no cart at all
  (a mob) hits at the 250% ceiling.
  """
  @spec skill_ratio(Weight.cart()) :: pos_integer()
  def skill_ratio(cart) do
    @base_ratio + div(100 * Weight.current_weight(cart), Weight.max_weight())
  end
end
