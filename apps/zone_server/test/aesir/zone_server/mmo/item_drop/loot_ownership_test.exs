defmodule Aesir.ZoneServer.Mmo.ItemDrop.LootOwnershipTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Mmo.ItemDrop.LootOwnership
  alias Aesir.ZoneServer.Unit.Mob.MobState

  describe "determine/2" do
    test "first eligible attacker keeps rank at the bonus boundary and loses above it" do
      eligible? = fn _attacker_id, "prontera" -> true end

      assert %LootOwnership{first: 1, second: 2} =
               LootOwnership.determine(mob_state([{1, 100}, {2, 185}]), eligible?)

      assert %LootOwnership{first: 2, second: 1} =
               LootOwnership.determine(mob_state([{1, 100}, {2, 186}]), eligible?)
    end

    test "applies the bonus to the first eligible attacker using full logged damage" do
      eligible? = fn attacker_id, "prontera" -> attacker_id != 1 end

      assert %LootOwnership{first: 2, second: 3, third: nil} =
               LootOwnership.determine(
                 mob_state([{1, 1_000}, {2, 100}, {3, 400}]),
                 eligible?
               )
    end

    test "returns no owners for empty and all-ineligible logs" do
      never_eligible? = fn _attacker_id, "prontera" -> false end

      assert %LootOwnership{first: nil, second: nil, third: nil} =
               LootOwnership.determine(mob_state([]), never_eligible?)

      assert %LootOwnership{first: nil, second: nil, third: nil} =
               LootOwnership.determine(mob_state([{1, 100}]), never_eligible?)
    end

    test "leaves unfilled owner slots nil" do
      eligible? = fn _attacker_id, "prontera" -> true end

      assert %LootOwnership{first: 1, second: nil, third: nil} =
               LootOwnership.determine(mob_state([{1, 100}]), eligible?)

      assert %LootOwnership{first: 1, second: 2, third: nil} =
               LootOwnership.determine(mob_state([{1, 100}, {2, 20}]), eligible?)
    end

    test "preserves arrival order when adjusted damage ties" do
      eligible? = fn _attacker_id, "prontera" -> true end

      assert %LootOwnership{first: 1, second: 2, third: 3} =
               LootOwnership.determine(
                 mob_state([{1, 1}, {2, 10}, {3, 10}, {4, 10}]),
                 eligible?
               )
    end
  end

  describe "deadlines/2" do
    test "returns cumulative normal-item deadlines" do
      assert LootOwnership.deadlines(false, 1_000) == {4_000, 6_000, 8_000}
    end

    test "returns cumulative MVP-item deadlines" do
      assert LootOwnership.deadlines(true, 1_000) == {11_000, 21_000, 23_000}
    end
  end

  describe "can_claim?/5" do
    setup do
      %{
        item: %{owners: {10, 20, 30}, unlock_at: {1_000, 2_000, 3_000}},
        no_party: %{party_id: 0, pickup_share: false},
        resolver: fn
          10 -> 7
          20 -> 8
          30 -> 9
        end
      }
    end

    test "allows public items immediately", %{no_party: party_ctx, resolver: resolver} do
      item = %{owners: nil, unlock_at: nil}
      assert :ok = LootOwnership.can_claim?(item, 99, party_ctx, 0, resolver)
    end

    test "allows each direct owner in its phase", context do
      assert :ok =
               LootOwnership.can_claim?(
                 context.item,
                 10,
                 context.no_party,
                 0,
                 context.resolver
               )

      assert {:error, :protected} =
               LootOwnership.can_claim?(
                 context.item,
                 20,
                 context.no_party,
                 999,
                 context.resolver
               )

      assert :ok =
               LootOwnership.can_claim?(
                 context.item,
                 20,
                 context.no_party,
                 1_000,
                 context.resolver
               )

      assert {:error, :protected} =
               LootOwnership.can_claim?(
                 context.item,
                 30,
                 context.no_party,
                 1_999,
                 context.resolver
               )

      assert :ok =
               LootOwnership.can_claim?(
                 context.item,
                 30,
                 context.no_party,
                 2_000,
                 context.resolver
               )
    end

    test "allows owner parties when their owner phase begins", %{item: item, resolver: resolver} do
      assert :ok =
               LootOwnership.can_claim?(item, 99, %{party_id: 7, pickup_share: true}, 0, resolver)

      assert {:error, :protected} =
               LootOwnership.can_claim?(
                 item,
                 99,
                 %{party_id: 8, pickup_share: true},
                 999,
                 resolver
               )

      assert :ok =
               LootOwnership.can_claim?(
                 item,
                 99,
                 %{party_id: 8, pickup_share: true},
                 1_000,
                 resolver
               )

      assert {:error, :protected} =
               LootOwnership.can_claim?(
                 item,
                 99,
                 %{party_id: 9, pickup_share: true},
                 1_999,
                 resolver
               )

      assert :ok =
               LootOwnership.can_claim?(
                 item,
                 99,
                 %{party_id: 9, pickup_share: true},
                 2_000,
                 resolver
               )
    end

    test "requires pickup sharing and a positive claimant party", %{
      item: item,
      resolver: resolver
    } do
      assert {:error, :protected} =
               LootOwnership.can_claim?(
                 item,
                 99,
                 %{party_id: 7, pickup_share: false},
                 0,
                 resolver
               )

      zero_resolver = fn _owner_id -> 0 end

      assert {:error, :protected} =
               LootOwnership.can_claim?(
                 item,
                 99,
                 %{party_id: 0, pickup_share: true},
                 0,
                 zero_resolver
               )
    end

    test "offline owners grant no party rights but retain direct owner rights", %{item: item} do
      offline_resolver = fn _owner_id -> 0 end

      assert {:error, :protected} =
               LootOwnership.can_claim?(
                 item,
                 99,
                 %{party_id: 7, pickup_share: true},
                 0,
                 offline_resolver
               )

      assert :ok =
               LootOwnership.can_claim?(item, 10, %{party_id: 0, pickup_share: false}, 0, fn _ ->
                 0
               end)
    end

    test "party clause skips a nil middle slot but honours the third owner's phase" do
      item = %{owners: {10, nil, 30}, unlock_at: {1_000, 2_000, 3_000}}
      party_ctx = %{party_id: 9, pickup_share: true}

      resolver = fn
        30 -> 9
        _other -> 0
      end

      assert {:error, :protected} =
               LootOwnership.can_claim?(item, 99, party_ctx, 1_999, resolver)

      assert :ok = LootOwnership.can_claim?(item, 99, party_ctx, 2_000, resolver)
    end

    test "absent later owners do not shorten public protection", %{no_party: party_ctx} do
      item = %{owners: {10, nil, nil}, unlock_at: {1_000, 2_000, 3_000}}
      resolver = fn _owner_id -> 0 end

      assert {:error, :protected} =
               LootOwnership.can_claim?(item, 99, party_ctx, 2_999, resolver)

      assert :ok = LootOwnership.can_claim?(item, 99, party_ctx, 3_000, resolver)
    end

    test "becomes public exactly at the third deadline", %{
      item: item,
      no_party: party_ctx,
      resolver: resolver
    } do
      assert {:error, :protected} =
               LootOwnership.can_claim?(item, 99, party_ctx, 2_999, resolver)

      assert :ok = LootOwnership.can_claim?(item, 99, party_ctx, 3_000, resolver)
    end
  end

  defp mob_state(damage_log) do
    %MobState{
      instance_id: 1,
      mob_id: 1,
      mob_data: nil,
      spawn_ref: nil,
      x: 0,
      y: 0,
      map_name: "prontera",
      hp: 1,
      max_hp: 1,
      sp: 0,
      max_sp: 0,
      spawned_at: 0,
      aggro_list: Map.new(damage_log),
      aggro_order: damage_log |> Enum.map(&elem(&1, 0)) |> Enum.reverse()
    }
  end
end
