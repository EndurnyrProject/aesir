defmodule Aesir.ZoneServer.Mmo.Mechanics.Sizes.Renewal do
  @moduledoc """
  Renewal weapon-size damage modifiers.
  """

  @behaviour Aesir.ZoneServer.Mmo.Mechanics.Sizes

  alias Aesir.ZoneServer.Mmo.Combat.SizeModifiers

  @riding_spears [:one_handed_spear, :two_handed_spear]

  @impl true
  @spec get_modifier(SizeModifiers.weapon_type(), SizeModifiers.size(), boolean()) :: integer()
  def get_modifier(weapon_type, target_size, riding?)

  def get_modifier(weapon_type, :medium, true) when weapon_type in @riding_spears do
    weapon_type |> size_table() |> size_at(:large)
  end

  def get_modifier(weapon_type, target_size, _riding?) do
    weapon_type |> size_table() |> size_at(target_size)
  end

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
