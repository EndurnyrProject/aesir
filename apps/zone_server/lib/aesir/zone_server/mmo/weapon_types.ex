defmodule Aesir.ZoneServer.Mmo.WeaponTypes do
  @moduledoc """
  Weapon type definitions
  """

  @weapon_types %{
    fist: 0,
    dagger: 1,
    one_handed_sword: 2,
    two_handed_sword: 3,
    one_handed_spear: 4,
    two_handed_spear: 5,
    one_handed_axe: 6,
    two_handed_axe: 7,
    mace: 8,
    two_handed_mace: 9,
    staff: 10,
    bow: 11,
    knuckle: 12,
    musical: 13,
    whip: 14,
    book: 15,
    katar: 16,
    revolver: 17,
    rifle: 18,
    gatling: 19,
    shotgun: 20,
    grenade: 21,
    huuma: 22,
    two_handed_staff: 23,
    # MAX_WEAPON_TYPE used for shield penalties
    shield: 24
  }

  @weapon_atoms_to_ids @weapon_types
  @weapon_ids_to_atoms Map.new(@weapon_types, fn {k, v} -> {v, k} end)

  @doc """
  Get weapon type atom from weapon ID.
  """
  @spec get_weapon_atom(integer()) :: atom()
  def get_weapon_atom(weapon_id) when is_integer(weapon_id) do
    Map.get(@weapon_ids_to_atoms, weapon_id, :fist)
  end

  @doc """
  Get weapon ID from weapon type atom.
  """
  @spec get_weapon_id(atom()) :: integer()
  def get_weapon_id(weapon_atom) when is_atom(weapon_atom) do
    Map.get(@weapon_atoms_to_ids, weapon_atom, 0)
  end

  @doc """
  Check if weapon is ranged.
  """
  @spec is_ranged?(integer() | atom()) :: boolean()
  def is_ranged?(weapon) when is_integer(weapon) do
    # bow, musical, whip, guns
    weapon in [11, 13, 14, 17, 18, 19, 20, 21]
  end

  def is_ranged?(weapon) when is_atom(weapon) do
    weapon in [:bow, :musical, :whip, :revolver, :rifle, :gatling, :shotgun, :grenade]
  end

  @doc """
  Check if weapon is two-handed.
  """
  @spec is_two_handed?(integer() | atom()) :: boolean()
  def is_two_handed?(weapon) when is_integer(weapon) do
    weapon in [3, 5, 7, 9, 11, 13, 14, 16, 18, 19, 20, 21, 22, 23]
  end

  def is_two_handed?(weapon) when is_atom(weapon) do
    weapon in [
      :two_handed_sword,
      :two_handed_spear,
      :two_handed_axe,
      :two_handed_mace,
      :bow,
      :musical,
      :whip,
      :katar,
      :rifle,
      :gatling,
      :shotgun,
      :grenade,
      :huuma,
      :two_handed_staff
    ]
  end

  @doc """
  Get all weapon types as a map.
  """
  @spec weapon_types() :: map()
  def weapon_types, do: @weapon_types

  @doc """
  Get the maximum weapon type ID (shield).
  """
  @spec max_weapon_type() :: integer()
  def max_weapon_type, do: 24

  @doc """
  Get the attack range for a weapon type.

  - Melee weapons: 1 cell
  - Spears/Polearms: 2 cells
  - Ranged weapons: 9+ cells
  """
  @spec get_attack_range(integer() | atom()) :: integer()
  def get_attack_range(weapon) when is_integer(weapon) do
    cond do
      # Spears have extended melee range
      # one_handed_spear, two_handed_spear
      weapon in [4, 5] -> 2
      # Ranged weapons have long range
      is_ranged?(weapon) -> 9
      # All other melee weapons
      true -> 1
    end
  end

  def get_attack_range(weapon) when is_atom(weapon) do
    cond do
      # Spears have extended melee range
      weapon in [:one_handed_spear, :two_handed_spear] -> 2
      # Ranged weapons have long range
      is_ranged?(weapon) -> 9
      # All other melee weapons
      true -> 1
    end
  end
end
