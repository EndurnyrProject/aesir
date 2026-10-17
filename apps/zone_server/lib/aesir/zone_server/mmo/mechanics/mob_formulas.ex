defmodule Aesir.ZoneServer.Mmo.Mechanics.MobFormulas do
  @moduledoc """
  Pure mob-stat formula leaves over static mob definitions.

  Shared helpers implement the status MATK steps both modes take on a monster:
  flat (pseudo-buff) MATK and Mystical Amplification's percentage, each added
  to both bounds and truncated. A MATK rate and the `:atk` channel are player
  bonuses (item scripts, or renewal equipment ATK a monster's damage never
  sums) and never apply.
  """

  alias Aesir.ZoneServer.Mmo.MobManagement.MobDefinition

  @typedoc "Mob definition used by formula implementations."
  @type mob_data :: MobDefinition.t()

  @typedoc "A unit's aggregated status modifiers."
  @type modifiers :: %{optional(atom()) => number()}

  @typedoc "A roll's minimum and maximum."
  @type bounds :: {integer(), integer()}

  @callback calculate_hit(mob_data()) :: integer()
  @callback calculate_flee(mob_data()) :: integer()
  @callback calculate_perfect_dodge(mob_data()) :: integer()
  @callback calculate_aspd(mob_data()) :: integer()
  @callback calculate_base_attack(mob_data()) :: integer()

  @doc "The weapon roll's bounds from the database attack and status (weapon) ATK."
  @callback attack_bounds(mob_data(), modifiers()) :: bounds()

  @doc """
  Status ATK added after the roll, from the current STR and the base status ATK
  a guardian's Guard Up grants (`status_calc_mob`).
  """
  @callback status_attack(mob_data(), str :: integer(), guard_up :: integer(), modifiers()) ::
              integer()

  @doc "MATK bounds from the current INT and the status MATK stages."
  @callback magic_attack_bounds(mob_data(), int :: integer(), modifiers()) :: bounds()
  @callback calculate_defense(mob_data()) :: integer()
  @callback calculate_soft_defense(mob_data()) :: integer()
  @callback calculate_magic_defense(mob_data()) :: integer()
  @callback calculate_soft_mdef(mob_data()) :: integer()

  @doc "Adds flat status MATK to both bounds."
  @spec add_flat(bounds(), modifiers()) :: bounds()
  def add_flat({min, max}, modifiers) do
    flat = Map.get(modifiers, :matk, 0)
    {min + flat, max + flat}
  end

  @doc "Applies Mystical Amplification's percentage to both bounds."
  @spec amplify(bounds(), modifiers()) :: bounds()
  def amplify({min, max}, modifiers) do
    rate = Map.get(modifiers, :base_matk_rate, 0)
    {min + div(min * rate, 100), max + div(max * rate, 100)}
  end

  @doc "Floors both bounds at zero."
  @spec floor_zero(bounds()) :: bounds()
  def floor_zero({min, max}), do: {max(min, 0), max(max, 0)}
end
