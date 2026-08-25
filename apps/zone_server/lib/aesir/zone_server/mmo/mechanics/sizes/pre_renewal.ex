defmodule Aesir.ZoneServer.Mmo.Mechanics.Sizes.PreRenewal do
  @moduledoc """
  Pre-renewal weapon-size damage modifiers.

  The static table is transcribed from `rAthena db/pre-re/size_fix.yml` over the shared
  `rAthena db/size_fix.yml` defaults.
  """

  @behaviour Aesir.ZoneServer.Mmo.Mechanics.Sizes

  alias Aesir.ZoneServer.Mmo.Combat.SizeModifiers

  @riding_spears [:one_handed_spear, :two_handed_spear]
  @size_table %{
    fist: {100, 100, 100},
    dagger: {100, 75, 50},
    one_handed_sword: {75, 100, 75},
    two_handed_sword: {75, 75, 100},
    one_handed_spear: {75, 75, 100},
    two_handed_spear: {75, 75, 100},
    one_handed_axe: {50, 75, 100},
    two_handed_axe: {50, 75, 100},
    mace: {75, 100, 100},
    two_handed_mace: {100, 100, 100},
    staff: {100, 100, 100},
    two_handed_staff: {100, 100, 100},
    bow: {100, 100, 75},
    knuckle: {100, 75, 50},
    musical: {75, 100, 75},
    whip: {75, 100, 50},
    book: {100, 100, 50},
    katar: {75, 100, 75},
    revolver: {100, 100, 100},
    rifle: {100, 100, 100},
    gatling: {100, 100, 100},
    shotgun: {100, 100, 100},
    grenade: {100, 100, 100},
    huuma: {100, 100, 100}
  }

  @impl true
  @spec get_modifier(SizeModifiers.weapon_type(), SizeModifiers.size(), boolean()) :: integer()
  def get_modifier(weapon_type, :medium, true) when weapon_type in @riding_spears do
    weapon_type |> size_table() |> size_at(:large)
  end

  def get_modifier(weapon_type, target_size, _riding?) do
    weapon_type |> size_table() |> size_at(target_size)
  end

  defp size_table(weapon_type), do: Map.get(@size_table, weapon_type, {100, 100, 100})

  defp size_at({small, _medium, _large}, :small), do: small
  defp size_at({_small, medium, _large}, :medium), do: medium
  defp size_at({_small, _medium, large}, :large), do: large
end
