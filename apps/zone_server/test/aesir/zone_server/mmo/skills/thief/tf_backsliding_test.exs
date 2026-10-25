defmodule Aesir.ZoneServer.Mmo.Skills.Thief.TfBackslidingTest do
  use ExUnit.Case, async: true
  import Mimic

  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skills.Thief.TfBacksliding
  alias Aesir.ZoneServer.Mmo.StatusStorage

  setup :verify_on_exit!

  defp caster(dir), do: %{character_id: 1000, x: 150, y: 150, dir: dir}

  defp definition do
    {:ok, definition} = Catalog.by_id(150)
    definition
  end

  # dir -> the cell one step ahead of {150, 150} in that facing direction,
  # inverse of Geometry.calculate_direction/4.
  @facing_cells %{
    0 => {150, 151},
    1 => {149, 151},
    2 => {149, 150},
    3 => {149, 149},
    4 => {150, 149},
    5 => {151, 149},
    6 => {151, 150},
    7 => {151, 151}
  }

  describe "endure" do
    setup do
      Aesir.TestEtsSetup.setup_ets_tables(%{})
      stub(Combat, :knockback, fn :player, 1000, _x, _y, 5 -> {:ok, {145, 145}} end)
      :ok
    end

    test "leaves the caster unstoppable by damage for 200 ms" do
      before = System.monotonic_time(:millisecond)
      TfBacksliding.cast(caster(0), :self, 1, definition())
      later = System.monotonic_time(:millisecond)

      assert StatusStorage.endure_tick(:player, 1000) in (before + 200)..(later + 200)
    end

    test "a caster already showing endure keeps it as it is" do
      StatusStorage.apply_status(:player, 1000, :sc_endure, val1: 1)

      TfBacksliding.cast(caster(0), :self, 1, definition())

      assert StatusStorage.endure_tick(:player, 1000) == nil
    end
  end

  for {dir, {fx, fy}} <- @facing_cells do
    test "cast/4 blows the caster 5 cells away from facing cell {#{fx}, #{fy}} at dir #{dir}" do
      caster = caster(unquote(dir))
      {fx, fy} = unquote({fx, fy})

      expect(Combat, :knockback, fn :player, 1000, ^fx, ^fy, 5 -> {:ok, {145, 145}} end)

      assert {:ok, ^caster} = TfBacksliding.cast(caster, :self, 1, definition())
    end
  end
end
