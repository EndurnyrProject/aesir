defmodule Aesir.ZoneServer.Mmo.Skills.TfBackslidingTest do
  use ExUnit.Case, async: true
  import Mimic

  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skills.TfBacksliding

  setup :verify_on_exit!

  defp caster(dir), do: %{character_id: 1000, x: 150, y: 150, dir: dir}

  defp definition do
    {:ok, definition} = Catalog.by_id(150)
    definition
  end

  test "Catalog.by_id/1 resolves TF_BACKSLIDING" do
    assert definition().name == :tf_backsliding
    assert definition().max_level == 1
    assert definition().target_type == :self
    assert definition().sp_cost == [7]
  end

  # dir -> the cell one step ahead of {150, 150} in that facing direction,
  # inverse of Geometry.calculate_direction/4.
  @facing_cells %{
    0 => {150, 149},
    1 => {149, 149},
    2 => {149, 150},
    3 => {149, 151},
    4 => {150, 151},
    5 => {151, 151},
    6 => {151, 150},
    7 => {151, 149}
  }

  for {dir, {fx, fy}} <- @facing_cells do
    test "cast/4 blows the caster 5 cells away from facing cell {#{fx}, #{fy}} at dir #{dir}" do
      caster = caster(unquote(dir))
      {fx, fy} = unquote({fx, fy})

      expect(Combat, :knockback, fn :player, 1000, ^fx, ^fy, 5 -> {:ok, {145, 145}} end)

      assert {:ok, ^caster} = TfBacksliding.cast(caster, :self, 1, definition())
    end
  end
end
