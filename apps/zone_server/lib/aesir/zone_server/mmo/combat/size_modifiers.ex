defmodule Aesir.ZoneServer.Mmo.Combat.SizeModifiers do
  @moduledoc """
  Renewal weapon-type vs target-size damage modifier table.

  Every weapon type has a fixed percent modifier against each of the three
  target sizes (`:small`, `:medium`, `:large`); 100 is neutral. Spears
  (`:one_handed_spear`, `:two_handed_spear`) get their `:medium` modifier
  bumped to their `:large` modifier while the wielder is mounted, matching
  rAthena's mounted-spear override. Unknown or missing weapon types fall back
  to 100 (neutral) at every size.
  """

  @type weapon_type :: atom()
  @type size :: :small | :medium | :large

  @riding_spears [:one_handed_spear, :two_handed_spear]

  @doc """
  Gets the damage modifier percent for a weapon type vs a target size.

  `riding?` (default `false`) applies the mounted-spear override: for
  `:one_handed_spear`/`:two_handed_spear` against a `:medium` target, the
  modifier becomes the spear's `:large` value instead of its `:medium` value.

  ## Returns
    - Integer percent, 100 = neutral.
  """
  @spec get_modifier(weapon_type(), size(), boolean()) :: integer()
  def get_modifier(weapon_type, target_size, riding? \\ false)

  def get_modifier(weapon_type, :medium, true) when weapon_type in @riding_spears do
    weapon_type |> size_table() |> size_at(:large)
  end

  def get_modifier(weapon_type, target_size, _riding?) do
    weapon_type |> size_table() |> size_at(target_size)
  end

  # Size table: {small, medium, large} percent modifiers per weapon type.
  defp size_table(:fist), do: {100, 100, 100}
  defp size_table(:dagger), do: {100, 75, 50}
  defp size_table(:one_handed_sword), do: {75, 100, 75}
  defp size_table(:two_handed_sword), do: {75, 75, 100}
  defp size_table(:one_handed_spear), do: {75, 75, 100}
  defp size_table(:two_handed_spear), do: {75, 75, 100}
  defp size_table(:one_handed_axe), do: {50, 75, 100}
  defp size_table(:two_handed_axe), do: {50, 75, 100}
  defp size_table(:mace), do: {75, 100, 100}
  defp size_table(:two_handed_mace), do: {100, 100, 100}
  defp size_table(:staff), do: {100, 100, 100}
  defp size_table(:two_handed_staff), do: {100, 100, 100}
  defp size_table(:bow), do: {100, 100, 75}
  defp size_table(:musical), do: {75, 100, 75}
  defp size_table(:whip), do: {75, 100, 75}
  defp size_table(:book), do: {100, 100, 50}
  defp size_table(:katar), do: {75, 100, 75}
  defp size_table(:knuckle), do: {100, 100, 75}
  defp size_table(:revolver), do: {100, 100, 100}
  defp size_table(:rifle), do: {100, 100, 100}
  defp size_table(:gatling), do: {100, 100, 100}
  defp size_table(:shotgun), do: {100, 100, 100}
  defp size_table(:grenade), do: {100, 100, 100}
  defp size_table(:huuma), do: {100, 100, 100}
  defp size_table(_unknown_weapon_type), do: {100, 100, 100}

  defp size_at({small, _medium, _large}, :small), do: small
  defp size_at({_small, medium, _large}, :medium), do: medium
  defp size_at({_small, _medium, large}, :large), do: large
end
