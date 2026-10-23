defmodule Aesir.ZoneServer.Mmo.ItemManagement.NoEquipTest do
  use ExUnit.Case, async: true
  use Mimic

  alias Aesir.ZoneServer.Map.MapFlags
  alias Aesir.ZoneServer.Mmo.ItemManagement.NoEquip

  setup :set_mimic_private

  defp on_map(flags, zone \\ 0) do
    stub(MapFlags, :get, fn "m", flag -> flag in flags end)
    stub(MapFlags, :zone, fn "m" -> zone end)
  end

  test "the normal-map bit restricts only on a map no versus flag marks" do
    on_map([])
    assert NoEquip.mask_restricted?(1, "m")

    for flag <- [:pvp, :gvg_dungeon, :gvg, :gvg_castle, :gvg_te, :gvg_te_castle, :battleground] do
      on_map([flag])
      refute NoEquip.mask_restricted?(1, "m"), "#{flag} is not a normal map"
    end
  end

  test "each map-type bit restricts on its own map types" do
    cases = [
      {2, [:pvp], [:gvg]},
      {4, [:gvg], [:gvg_te]},
      {4, [:gvg_castle], [:gvg_te_castle]},
      {8, [:battleground], [:pvp]},
      {16, [:gvg_te], [:gvg]},
      {16, [:gvg_te_castle], [:gvg_castle]}
    ]

    for {mask, restricted, free} <- cases do
      on_map(restricted)
      assert NoEquip.mask_restricted?(mask, "m"), "#{mask} on #{inspect(restricted)}"
      on_map(free)
      refute NoEquip.mask_restricted?(mask, "m"), "#{mask} on #{inspect(free)}"
    end
  end

  test "a zone bit restricts on a map whose restricted zones include it" do
    on_map([:pvp], 64)
    assert NoEquip.mask_restricted?(64, "m")
    refute NoEquip.mask_restricted?(32, "m")
  end

  test "no map context restricts nothing" do
    refute NoEquip.restricted?(1, nil)
  end
end
