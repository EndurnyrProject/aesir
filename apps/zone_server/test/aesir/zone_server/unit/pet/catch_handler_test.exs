defmodule Aesir.ZoneServer.Unit.Pet.CatchHandlerTest do
  use Aesir.DataCase, async: true

  import Aesir.TestEtsSetup
  import Mimic

  alias Aesir.Commons.Models.Account
  alias Aesir.Commons.Models.Character
  alias Aesir.Commons.Models.InventoryItem
  alias Aesir.Commons.Models.Pet
  alias Aesir.Net.ChatNotice
  alias Aesir.Net.PetCatchResult
  alias Aesir.Net.PetCatchStart
  alias Aesir.Net.SystemNotice
  alias Aesir.ZoneServer.Config
  alias Aesir.ZoneServer.Map.MapFlags
  alias Aesir.ZoneServer.Mmo.MobManagement.MobMode
  alias Aesir.ZoneServer.Mmo.MobManagement.Mobs
  alias Aesir.ZoneServer.Mmo.MobManagement.MobSpawn
  alias Aesir.ZoneServer.Mmo.MobManagement.MobSpawn.SpawnArea
  alias Aesir.ZoneServer.Mmo.PetManagement.Catalog
  alias Aesir.ZoneServer.Mmo.PetManagement.Egg
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit.Inventory
  alias Aesir.ZoneServer.Unit.Mob.MobSession
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.Pet.Handlers.CatchHandler
  alias Aesir.ZoneServer.Unit.Pet.Runtime
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.SessionState
  alias Aesir.ZoneServer.Unit.Player.Stats
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @map "pet_catch_map"
  @mob_gid 7_001
  @poring 1002
  @apple 619
  @catch_message "You can't catch any pet on this map."

  setup :setup_ets_tables
  setup :set_mimic_private

  setup do
    suffix = System.unique_integer([:positive])
    username = "pch#{suffix}"

    account =
      Repo.insert!(
        Account.changeset(%Account{}, %{
          username: username,
          userid: username,
          user_pass: "password",
          email: "#{username}@example.com"
        })
      )

    character =
      Repo.insert!(
        Character.changeset(%Character{}, %{
          account_id: account.id,
          char_num: 0,
          name: "Pch#{suffix}",
          class: 1,
          base_level: 10,
          str: 1,
          agi: 1,
          vit: 1,
          int: 1,
          dex: 1,
          luk: 5
        })
      )

    {:ok, definition} = Catalog.by_mob(@poring)
    %{character: character, definition: definition}
  end

  describe "capture_rate/3" do
    setup ctx do
      %{definition: %{ctx.definition | capture_rate: 2000}, owner: %{base_level: 10, luk: 5}}
    end

    test "new formula grows as the mob's HP falls", ctx do
      assert CatchHandler.capture_rate(ctx.definition, ctx.owner, mob(1, 1000, 1000)) == 2000
      assert CatchHandler.capture_rate(ctx.definition, ctx.owner, mob(1, 500, 1000)) == 3000
      assert CatchHandler.capture_rate(ctx.definition, ctx.owner, mob(1, 1, 1000)) == 4000
      # 100 * (29 / 100) is 28.999..., so the HP percentage is 28, not 29.
      assert CatchHandler.capture_rate(ctx.definition, ctx.owner, mob(1, 29, 100)) == 3440
    end

    test "legacy formula weighs levels and LUK", ctx do
      stub(Config, :pet_legacy_formula?, fn -> true end)

      assert CatchHandler.capture_rate(ctx.definition, ctx.owner, mob(1, 1000, 1000)) == 2370
      assert CatchHandler.capture_rate(ctx.definition, ctx.owner, mob(1, 500, 1000)) == 3555
      assert CatchHandler.capture_rate(ctx.definition, ctx.owner, mob(1, 1, 1000)) == 4740

      # The reference computes this in unsigned 32-bit arithmetic, so a negative
      # numerator wraps into a near-certain rate instead of flooring to 1.
      weak = %{ctx.definition | capture_rate: 100}
      owner = %{base_level: 1, luk: 0}
      assert CatchHandler.capture_rate(weak, owner, mob(99, 1000, 1000)) == 42_946_832
      assert CatchHandler.capture_rate(weak, owner, mob(99, 500, 1000)) == 42_945_412

      none = %{ctx.definition | capture_rate: 0}
      assert CatchHandler.capture_rate(none, %{base_level: 5, luk: 0}, mob(5, 1000, 1000)) == 1
    end

    test "new formula floors a zero rate to 1", ctx do
      none = %{ctx.definition | capture_rate: 0}
      assert CatchHandler.capture_rate(none, ctx.owner, mob(1, 1000, 1000)) == 1
    end

    test "pet_catch_rate scales the floored rate", ctx do
      stub(Config, :pet_catch_rate, fn -> 50 end)
      assert CatchHandler.capture_rate(ctx.definition, ctx.owner, mob(1, 1000, 1000)) == 1000

      stub(Config, :pet_catch_rate, fn -> 100 end)
      assert CatchHandler.capture_rate(ctx.definition, ctx.owner, mob(1, 1000, 1000)) == 2000
    end
  end

  describe "start/3" do
    test "parks the lure and opens the target cursor, except on a nopetcapture map", ctx do
      started = CatchHandler.start(session(ctx.character), @apple, 0)

      assert started.pet_runtime.catch_process == %{lure_id: @apple, flag: 0}
      assert_receive {:send, _, {:pet_catch_start, %PetCatchStart{}}}

      stub(MapFlags, :get, fn @map, :nopetcapture -> true end)

      assert CatchHandler.start(started, 12_408, 2) == started
      assert_receive {:send, _, {:chat_notice, %ChatNotice{text: @catch_message}}}
      refute_received {:send, _, {:pet_catch_start, _}}
    end
  end

  describe "finish/2" do
    test "catch pick without a live process or mob fails cleanly", ctx do
      reject(&MobSession.capture/1)
      session = session(ctx.character)

      assert CatchHandler.finish(session, @mob_gid) == session
      assert_receive {:send, _, {:pet_catch_result, %PetCatchResult{success: false}}}

      dead = %{poring_mob() | is_dead: true}
      UnitRegistry.register_unit(:mob, @mob_gid, MobState, dead, self())

      finished = session |> with_process(0) |> CatchHandler.finish(@mob_gid)

      assert finished.pet_runtime.catch_process == nil
      assert_receive {:send, _, {:pet_catch_result, %PetCatchResult{success: false}}}
    end

    test "a mob that dies between the roll and the capture is not caught", ctx do
      register_mob(poring_mob())
      stub(MobSession, :capture, fn _pid -> {:error, :dead} end)

      finished =
        ctx.character |> session() |> with_process(0) |> CatchHandler.finish(@mob_gid, &always/1)

      assert finished.pet_runtime.catch_process == nil
      assert finished.game_state.inventory == %{}
      assert_receive {:send, _, {:pet_catch_result, %PetCatchResult{success: false}}}
      refute Repo.exists?(from(p in Pet, where: p.class == @poring))
    end

    test "each failed check fails the catch and clears the process", ctx do
      reject(&MobSession.capture/1)
      stub(MapFlags, :get, fn @map, :nopetcapture -> Process.get(:nopetcapture, false) end)
      full = Map.new(0..(Inventory.capacity() - 1), &{&1, %InventoryItem{nameid: 501, amount: 1}})

      checks = [
        nopetcapture:
          {fn s ->
             Process.put(:nopetcapture, true)
             s
           end, :catch_message},
        no_pet_row:
          {fn s ->
             register_mob(%{poring_mob() | mob_id: 1039})
             s
           end, nil},
        wrong_lure: {&with_process(&1, 12_408, 0), nil},
        status_immune:
          {fn s ->
             register_mob(immune_poring())
             with_process(s, 0, 1)
           end, nil},
        too_far:
          {fn s ->
             register_mob(%{poring_mob() | x: 16})
             s
           end, nil},
        no_slot: {&put_in(&1.game_state.inventory, full), :count_notice},
        hidden:
          {fn s ->
             StatusStorage.apply_status(:mob, @mob_gid, :sc_hiding)
             s
           end, nil}
      ]

      for {name, {arrange, notice}} <- checks do
        register_mob(poring_mob())
        Process.delete(:nopetcapture)
        StatusStorage.remove_status(:mob, @mob_gid, :sc_hiding)
        session = ctx.character |> session() |> with_process(0) |> arrange.()

        finished = CatchHandler.finish(session, @mob_gid, &always/1)

        assert finished.pet_runtime.catch_process == nil, "#{name} kept the process"
        assert_receive {:send, _, {:pet_catch_result, %PetCatchResult{success: false}}}
        assert_notice(notice, name)
      end
    end

    test "a successful roll captures the mob into a fresh egg", ctx do
      mob = register_mob(poring_mob())
      test_pid = self()

      stub(MobSession, :capture, fn pid ->
        send(test_pid, {:captured, pid})
        :ok
      end)

      finished =
        ctx.character |> session() |> with_process(0) |> CatchHandler.finish(@mob_gid, &always/1)

      assert_received {:captured, pid} when pid == mob.process_pid
      assert finished.pet_runtime.catch_process == nil
      assert_receive {:send, _, {:pet_catch_result, %PetCatchResult{success: true}}}

      assert [{_index, egg}] = Map.to_list(finished.game_state.inventory)
      assert %InventoryItem{nameid: egg_id, identify: 1} = egg
      assert egg_id == ctx.definition.egg_item_id

      {:ok, poring} = Mobs.by_id(@poring)
      intimacy = ctx.definition.intimacy_start

      assert %Pet{class: @poring, intimate: ^intimacy, hungry: 100, incubate: 1} =
               pet = Repo.get!(Pet, Egg.pet_id(egg))

      assert pet.level == poring.level
      assert pet.name == poring.name
      assert_receive {:send, _, {:item_added, _}}
    end
  end

  defp always(_base), do: 1

  defp assert_notice(nil, name) do
    refute_received {:send, _, {:chat_notice, _}}, "#{name} sent a chat notice"
    refute_received {:send, _, {:system_notice, _}}, "#{name} sent a system notice"
  end

  defp assert_notice(:catch_message, _name),
    do: assert_received({:send, _, {:chat_notice, %ChatNotice{text: @catch_message}}})

  defp assert_notice(:count_notice, _name) do
    assert_received {:send, _,
                     {:system_notice,
                      %SystemNotice{id: :SYSTEM_NOTICE_ID_CANT_GET_ITEM_BECAUSE_COUNT}}}
  end

  defp mob(level, hp, max_hp), do: %{level: level, hp: hp, max_hp: max_hp}

  defp poring_mob do
    {:ok, data} = Mobs.by_id(@poring)
    state = MobState.new(@mob_gid, data, spawn_ref(), @map, 13, 10)
    %{state | process_pid: self()}
  end

  defp spawn_ref,
    do: %MobSpawn{
      mob: @poring,
      amount: 1,
      respawn_time: 5000,
      spawn_area: %SpawnArea{x: 13, y: 10}
    }

  defp immune_poring do
    %MobState{calculated: calculated} = mob = poring_mob()
    %{mob | calculated: %{calculated | mode: MobMode.mask([:status_immune])}}
  end

  defp register_mob(%MobState{} = mob) do
    UnitRegistry.unregister_unit(:mob, @mob_gid)
    :ok = UnitRegistry.register_unit(:mob, @mob_gid, MobState, mob, mob.process_pid)
    mob
  end

  defp with_process(session, lure \\ @apple, flag) do
    put_in(session.pet_runtime.catch_process, %{lure_id: lure, flag: flag})
  end

  defp session(character) do
    stats = Stats.from_character(character)

    %SessionState{
      game_state: %PlayerState{
        character_id: character.id,
        account_id: character.account_id,
        character_name: character.name,
        map_name: @map,
        x: 10,
        y: 10,
        dir: 0,
        walk_speed: 150,
        movement_state: :standing,
        view_range: 14,
        inventory: %{},
        stats: stats
      },
      connection_pid: self(),
      pet_runtime: %Runtime{generation: 3}
    }
  end
end
