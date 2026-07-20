defmodule Aesir.ZoneServer.Mmo.Skills.Merchant.McCartrevolution do
  @moduledoc """
  Cart Revolution (MC_CARTREVOLUTION, id 153). Physical neutral splash attack with
  knockback whose damage scales with the current cart weight; requires a mounted
  cart, else `{:error, :no_cart}`.

  rAthena (`src/map/skills/merchant/cartrevolution.cpp`): `MaxLevel` 1, `SplashArea`
  1, `Knockback` 2, `SpCost` 12, element forced to Neutral (`battle.cpp:3698`,
  `battle_attr_fix(... ELE_NEUTRAL ...)`). Like `AC_SHOWER` we center the splash on
  the target's cell and reuse `Combat.execute_splash_attack` + `Combat.knockback`.

  ## Damage formula

  rAthena `SkillCartRevolution::calculateSkillRatio` (cartrevolution.cpp:11-17):

      base_skillratio += 50;                                  // on top of the 100 base
      if (sd && sd->cart_weight)
        base_skillratio += 100 * sd->cart_weight / sd->cart_weight_max;

  so the total ratio is `150 + 100 * cart_weight / cart_weight_max` (empty cart →
  150%, full cart → 250%).

  ## Cart-weight scaling

  `Cart.Weight.current_weight/1` and `Cart.Weight.max_weight/0` (`80_000`) use the
  one weight unit Aesir uses everywhere (item-db weight, e.g. Red Potion = 70), so
  `100 * current / max` reproduces rAthena's `100 * cart_weight / cart_weight_max`
  (empty cart → 150%, full → 250%).
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 153,
    name: :mc_cartrevolution,
    display_name: "Cart Revolution",
    max_level: 1,
    target_type: :target_enemy,
    damage_type: :damage,
    range: -1,
    element: :neutral,
    knockback: 2,
    splash_radius: 1,
    sp_cost: [12]

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
        skill_ratio: skill_ratio(caster.cart),
        skip_crit: true
      ]

      caster
      |> Combat.execute_splash_attack({x, y}, definition.splash_radius, opts)
      |> Enum.each(&Combat.knockback(:mob, &1, x, y, definition.knockback))

      {:ok, caster}
    end
  end

  @doc """
  The skill ratio for the current cart load: `150 + 100 * current/max` (clamped at
  250% by the cart cap). Heavier carts hit harder.
  """
  @spec skill_ratio(Weight.cart()) :: pos_integer()
  def skill_ratio(cart) do
    @base_ratio + div(100 * Weight.current_weight(cart), Weight.max_weight())
  end
end
