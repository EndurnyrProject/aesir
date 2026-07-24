defmodule Aesir.ZoneServer.Integration.RefineIntegrationTest do
  @moduledoc """
  End-to-end coverage that the refine DSL surface is playable on the real
  stack, mirroring the storage/warp integration coverage. A throwaway NPC
  reads `refine_targets/1` and drives `refine/4` through the real
  `PlayerSession` -> `{:script_apply, {:refine, ...}}` ->
  `ScriptEffectHandler` -> `RefineOps` path:

    1. A forced success on an equipped weapon-lv1 sword (`Phracon`, `:normal`)
       increments `refine`, consumes the ore and zeny, and raises the
       equipped `combat_stats.atk`.
    2. A forced break on an equipped weapon-lv1 sword at `+12` (`Bradium`,
       `:normal`) destroys the inventory row, consumes zeny, and drops the
       equipped atk contribution once stats are recalculated.

  `RefineOps.apply/5` (the arity `ScriptEffectHandler` calls) is stubbed to
  forward into the real `apply/6` with injected `success_roll`/`break_roll` so
  the outcome is deterministic; every other step (persistence, stat recalc,
  item view push) runs for real.
  """

  use Aesir.ZoneServer.IntegrationCase

  @moduletag :capture_log

  alias Aesir.Commons.Models.Account
  alias Aesir.Commons.Models.Character
  alias Aesir.Commons.Models.InventoryItem
  alias Aesir.Net.NpcDialog
  alias Aesir.Net.NpcTalk
  alias Aesir.Repo
  alias Aesir.ZoneServer.Mmo.Refine.RefineDatabase
  alias Aesir.ZoneServer.Npc.Placement
  alias Aesir.ZoneServer.Npc.Registry, as: NpcRegistry
  alias Aesir.ZoneServer.Unit.Inventory
  alias Aesir.ZoneServer.Unit.Inventory.Persistence, as: InventoryPersistence
  alias Aesir.ZoneServer.Unit.Player.Handlers.RefineOps

  @map "prontera"
  @npc_pos {170, 160}
  # Sword: weapon_level 1, refineable, subtype one_handed_sword.
  @sword 1101
  # Phracon: the weapon-lv1 "normal" ore at yml Level 1 (rate 10000, safe).
  @phracon 1010
  # Bradium: the weapon-lv1 "normal" ore at yml Level 13 (rate 1800,
  # breaking_rate 2000) - going +12 -> +13.
  @bradium 6224
  @right_hand 2

  defmodule RefineNpc do
    use Aesir.ZoneServer.Npc,
      spawn: [%{map: "prontera", x: 170, y: 160, dir: 0, sprite: 117, name: "Blacksmith"}]

    @impl true
    def on_talk(ctx) do
      case refine_targets(ctx) do
        [%{index: index} | _] ->
          result = refine(ctx, index, :normal, false)
          ctx |> mes(inspect(result)) |> close()

        [] ->
          ctx |> mes("nothing to refine") |> close()
      end
    end
  end

  setup do
    # Guards against a real cross-test hazard: RefineDatabase.reload/0 is
    # global :persistent_term state, and another suite's test can leave a
    # stubbed material resolution behind if it runs between us and the last
    # reload. A fresh, unstubbed reload here keeps this test's Phracon/Bradium
    # lookups correct regardless of run order.
    :ok = RefineDatabase.reload()

    on_exit(fn -> :persistent_term.erase(NpcRegistry) end)
    NpcRegistry.reload([RefineNpc])
    :ok
  end

  describe "forced success on a weapon-lv1 sword" do
    test "increments refine, consumes ore + zeny, and raises equipped atk" do
      character = insert_character(zeny: 1_000)
      seed_inventory(character.id, nameid: @sword, amount: 1, refine: 0, equip: @right_hand)
      seed_inventory(character.id, nameid: @phracon, amount: 1)

      session = start_session(character)

      stub(RefineOps, :apply, fn state, index, nameid, cost_type, use_blessing? ->
        RefineOps.apply(state, index, nameid, cost_type, use_blessing?, success_roll: 0)
      end)

      Mimic.allow(RefineOps, self(), session.pid)

      atk_before = get_player_state(session.pid).stats.combat_stats.atk

      talk_to_npc(session.pid)

      assert_receive {:packet_sent, %NpcDialog{expect: :CLOSE, text: text}, _}, 1_000
      assert text =~ ":ok, :success, 1"

      state = get_player_state(session.pid)
      assert %InventoryItem{refine: 1} = item_by_nameid(state.inventory, @sword)
      assert state.zeny == 1_000 - 50
      # Weapon-lv1 yml Level 1: bonus 200 -> atk += 200/100 = 2.
      assert state.stats.combat_stats.atk == atk_before + 2
      assert Inventory.held_amount(state.inventory, @phracon) == 0

      assert [%InventoryItem{refine: 1}] =
               InventoryPersistence.load_inventory(character.id)
               |> Enum.filter(&(&1.nameid == @sword))

      assert Repo.get!(Character, character.id).zeny == 1_000 - 50
    end
  end

  describe "forced break on an equipped weapon-lv1 sword" do
    test "destroys the row, consumes zeny, and drops the equipped atk contribution" do
      character = insert_character(zeny: 200_000)
      seed_inventory(character.id, nameid: @sword, amount: 1, refine: 12, equip: @right_hand)
      seed_inventory(character.id, nameid: @bradium, amount: 1)

      session = start_session(character)

      stub(RefineOps, :apply, fn state, index, nameid, cost_type, use_blessing? ->
        RefineOps.apply(state, index, nameid, cost_type, use_blessing?,
          success_roll: 9999,
          break_roll: 0
        )
      end)

      Mimic.allow(RefineOps, self(), session.pid)

      atk_before = get_player_state(session.pid).stats.combat_stats.atk

      talk_to_npc(session.pid)

      assert_receive {:packet_sent, %NpcDialog{expect: :CLOSE, text: text}, _}, 1_000
      assert text =~ ":ok, :broke"

      state = get_player_state(session.pid)
      refute item_by_nameid(state.inventory, @sword)
      assert state.stats.combat_stats.atk < atk_before
      assert state.zeny == 200_000 - 100_000

      assert InventoryPersistence.load_inventory(character.id)
             |> Enum.filter(&(&1.nameid == @sword)) == []

      assert Repo.get!(Character, character.id).zeny == 200_000 - 100_000
    end
  end

  defp start_session(character) do
    session = start_player_session(character: character, map_name: @map, position: @npc_pos)
    on_exit(fn -> end_player_session(session) end)
    flush_packets()
    session
  end

  defp talk_to_npc(pid) do
    {x, y} = @npc_pos
    gid = NpcRegistry.entity_id(%Placement{map: @map, x: x, y: y, sprite: 117})
    simulate_incoming_message(pid, %NpcTalk{npc_id: gid})
  end

  defp insert_character(opts) do
    uniq = System.unique_integer([:positive])
    {x, y} = @npc_pos

    {:ok, account} =
      %Account{}
      |> Account.changeset(%{
        username: "refiner#{uniq}",
        userid: "refiner#{uniq}",
        user_pass: "password",
        email: "refiner#{uniq}@aesir.test"
      })
      |> Repo.insert()

    {:ok, character} =
      %Character{}
      |> Character.changeset(%{
        account_id: account.id,
        char_num: 0,
        name: "Refiner#{uniq}",
        class: 0,
        base_level: 50,
        job_level: 50,
        str: 10,
        agi: 10,
        vit: 10,
        int: 10,
        dex: 10,
        luk: 10,
        zeny: Keyword.fetch!(opts, :zeny),
        last_map: @map,
        last_x: x,
        last_y: y,
        save_map: @map,
        save_x: x,
        save_y: y
      })
      |> Repo.insert()

    character
  end

  defp seed_inventory(char_id, attrs) do
    attrs = attrs |> Map.new() |> Map.put_new(:identify, 1)
    {:ok, item} = InventoryPersistence.insert_item(char_id, attrs)
    item
  end

  defp item_by_nameid(inventory, nameid) do
    inventory |> Map.values() |> Enum.find(&(&1.nameid == nameid))
  end
end
