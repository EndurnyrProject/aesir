defmodule Aesir.ZoneServer.Npc.ShopTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Npc.Shop
  alias Aesir.ZoneServer.Npc.Shop.Registry

  @shop_id_base 0x4800_0000
  @warp_id_base 0x4000_0000
  @npc_id_base 0x5000_0000

  defp shop(overrides) do
    struct!(
      Shop,
      Keyword.merge([id: "s", map: "prontera", x: 150, y: 60, dir: 4, sprite: 85], overrides)
    )
  end

  describe "entity_id/1" do
    test "is stable across calls for the same placement" do
      s = shop([])

      assert Registry.entity_id(s) == Registry.entity_id(s)
    end

    test "is distinct for two shops on the same map with different cells" do
      a = shop(id: "a", x: 150, y: 60)
      b = shop(id: "b", x: 200, y: 40)

      assert Registry.entity_id(a) != Registry.entity_id(b)
    end

    test "lives in the reserved shop gid range, disjoint from warp and npc bases" do
      gid = Registry.entity_id(shop([]))

      assert gid in @shop_id_base..(@npc_id_base - 1)
      refute gid in @warp_id_base..(@shop_id_base - 1)
      refute gid in 1..1_999_999
    end
  end
end
