defmodule Aesir.ZoneServer.Mmo.Skill.NoCastTest do
  use ExUnit.Case, async: true
  use Mimic

  alias Aesir.ZoneServer.Map.MapFlags
  alias Aesir.ZoneServer.Mmo.Skill.NoCast

  # Masks shared by both modes: Hermode 1|2, Warp Portal 4|8|32 (plus 16 in renewal).
  @hermode 488
  @warp 27
  @fire_bolt 19

  setup :set_mimic_private
  setup :verify_on_exit!

  setup do
    stub(MapFlags, :vs2?, fn _map -> false end)
    stub(MapFlags, :get, fn _map, _flag -> false end)
    stub(MapFlags, :gvg2_no_te?, fn _map -> false end)
    stub(MapFlags, :gvg2_te?, fn _map -> false end)
    stub(MapFlags, :zone, fn _map -> 0 end)
    :ok
  end

  test "bit 1 refuses off versus ground and bit 2 on PvP maps" do
    assert NoCast.refused?(@hermode, "prontera")

    stub(MapFlags, :vs2?, fn "arena" -> true end)
    refute NoCast.refused?(@hermode, "arena")

    stub(MapFlags, :get, fn "arena", flag -> flag == :pvp end)
    assert NoCast.refused?(@hermode, "arena")
  end

  test "bit 4 refuses GvG ground outside TE and bit 8 battlegrounds" do
    refute NoCast.refused?(@warp, "field")

    stub(MapFlags, :gvg2_no_te?, fn map -> map == "castle" end)
    assert NoCast.refused?(@warp, "castle")

    stub(MapFlags, :get, fn "bg", flag -> flag == :battleground end)
    assert NoCast.refused?(@warp, "bg")
  end

  @tag game_mode: :renewal
  test "renewal Warp Portal is refused on TE ground" do
    stub(MapFlags, :gvg2_te?, fn "te_castle" -> true end)
    assert NoCast.refused?(@warp, "te_castle")
  end

  test "a restricted zone the mask names refuses it, another zone does not" do
    stub(MapFlags, :zone, fn "jail" -> 32 end)
    assert NoCast.refused?(@warp, "jail")

    stub(MapFlags, :zone, fn "jail" -> 64 end)
    refute NoCast.refused?(@warp, "jail")
  end

  test "a skill without a mask is never refused" do
    stub(MapFlags, :zone, fn _map -> 0xFFFF end)
    refute NoCast.refused?(@fire_bolt, "prontera")
  end
end
