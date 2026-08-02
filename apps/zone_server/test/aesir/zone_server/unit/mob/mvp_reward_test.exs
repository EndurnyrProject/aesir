defmodule Aesir.ZoneServer.Unit.Mob.MvpRewardTest do
  @moduledoc """
  Exercises MVP reward granting on a boss kill: the derived MVP-tier check,
  winner selection over the shared `KillExp` eligibility rule, base-only MVP
  experience, the stop-at-first-success drop roll, the overweight/no-winner
  floor fallbacks, and the server-wide announcement.
  """

  use ExUnit.Case, async: false
  use Mimic

  import Aesir.TestEtsSetup

  alias Aesir.ZoneServer.Announcement
  alias Aesir.ZoneServer.Map.Coordinator
  alias Aesir.ZoneServer.Mmo.ItemDrop.LevelPenalty
  alias Aesir.ZoneServer.Mmo.ItemDrop.LootOwnership
  alias Aesir.ZoneServer.Mmo.ItemManagement.ItemDefinition
  alias Aesir.ZoneServer.Mmo.ItemManagement.Items
  alias Aesir.ZoneServer.Mmo.MobManagement.MobDefinition
  alias Aesir.ZoneServer.Mmo.MobManagement.MobDrop
  alias Aesir.ZoneServer.Unit.Mob.MvpReward
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.UnitRegistry
  alias Phoenix.PubSub

  setup :verify_on_exit!
  setup :set_mimic_from_context
  setup :setup_ets_tables

  setup do
    stub(LevelPenalty, :mvp_exp, fn _mob_level, _base_level -> 100 end)
    stub(LevelPenalty, :mvp_drop, fn _mob_level, _base_level -> 100 end)
    :ok
  end

  defp mob(fields \\ []) do
    struct!(
      %MobDefinition{
        id: 1039,
        aegis_name: "BAPHOMET",
        name: "Baphomet",
        level: 81,
        hp: 668_000,
        stats: %{},
        attack_range: 2,
        size: :large,
        race: :demon,
        element: {:dark, 4},
        walk_speed: 150,
        attack_delay: 800,
        attack_motion: 500,
        client_attack_motion: 500,
        damage_motion: 384
      },
      fields
    )
  end

  defp register_player(char_id, opts \\ []) do
    pid = Keyword.get(opts, :pid, self())

    UnitRegistry.register_unit(
      :player,
      char_id,
      PlayerState,
      %{
        map_name: Keyword.get(opts, :map_name, "gld_dun03"),
        character_name: Keyword.get(opts, :name, "Player#{char_id}"),
        stats: %{
          current_state: %{hp: Keyword.get(opts, :hp, 100)},
          progression: %{base_level: Keyword.get(opts, :base_level, 81)}
        }
      },
      pid
    )

    PubSub.subscribe(Aesir.PubSub, "player:#{char_id}")
    pid
  end

  @item_ids %{"FIRST" => 1001, "SECOND" => 1002, "THIRD" => 1003}

  defp drop(aegis, rate \\ 10_000), do: %MobDrop{item: aegis, rate: rate}

  defp ownership(fields \\ []), do: struct!(%LootOwnership{}, fields)

  defp stub_items do
    stub(Items, :by_aegis, fn aegis ->
      case Map.fetch(@item_ids, aegis) do
        {:ok, id} -> {:ok, %ItemDefinition{id: id, aegis_name: aegis, name: aegis, weight: 10}}
        :error -> :error
      end
    end)
  end

  # A stand-in for a `PlayerSession`: answers the single-writer
  # `{:npc, {:script_apply, op}}` call with `reply` and mirrors the op to the test.
  defp fake_session(reply) do
    test = self()

    spawn_link(fn -> session_loop(test, reply) end)
  end

  defp session_loop(test, reply) do
    receive do
      {:"$gen_call", from, msg} ->
        send(test, {:session_call, msg})
        if reply != :never, do: GenServer.reply(from, reply)
        session_loop(test, reply)
    end
  end

  describe "grant/6 tier check" do
    test "a mini-boss with no mvp exp and no mvp drops produces no reward and no announcement" do
      reject(&Announcement.to_all/1)
      register_player(1)

      assert :ok = MvpReward.grant(%{1 => 500}, mob(), "gld_dun03", 10, 10, ownership())

      refute_receive {:progression, {:mob_kill_exp, _base, _job, _race}}
    end
  end

  describe "grant/6 experience" do
    test "credits base-only mvp exp to the highest damage dealer, not the killer" do
      test = self()
      stub(Announcement, :to_all, fn opts -> send(test, {:announced, opts}) end)
      # The level penalty makes the two candidates' grants distinguishable, so
      # a winner picked by lowest damage would credit a different amount.
      stub(LevelPenalty, :mvp_exp, fn 81, base_level -> base_level end)
      register_player(1, name: "Chipper", base_level: 10)
      register_player(2, name: "Bruiser", base_level: 50)

      assert :ok =
               MvpReward.grant(
                 %{1 => 100, 2 => 900},
                 mob(mvp_exp: 1000),
                 "gld_dun03",
                 10,
                 10,
                 ownership()
               )

      assert_receive {:progression, {:mob_kill_exp, 500, 0, _race}}
      refute_receive {:progression, {:mob_kill_exp, _base, _job, _race}}
      assert_receive {:announced, %{text: "Bruiser has defeated Baphomet!"}}
    end

    test "scales mvp exp by the mvp level penalty" do
      stub(Announcement, :to_all, fn _opts -> :ok end)
      stub(LevelPenalty, :mvp_exp, fn 81, 99 -> 50 end)
      register_player(1, base_level: 99)

      MvpReward.grant(%{1 => 100}, mob(mvp_exp: 1000), "gld_dun03", 10, 10, ownership())

      assert_receive {:progression, {:mob_kill_exp, 500, 0, _race}}
    end
  end

  describe "grant/6 drops" do
    test "drops at most one item even when every entry would succeed its roll" do
      stub(Announcement, :to_all, fn _opts -> :ok end)
      stub_items()
      register_player(1, pid: fake_session({:ok, %{}}))

      MvpReward.grant(
        %{1 => 100},
        mob(mvp_drops: [drop("FIRST"), drop("SECOND"), drop("THIRD")]),
        "gld_dun03",
        10,
        10,
        ownership()
      )

      assert_receive {:session_call, {:npc, {:script_apply, {:give_item, 1001, 1}}}}
      refute_receive {:session_call, _msg}
    end

    test "does not block the caller on the winning session's reply" do
      stub(Announcement, :to_all, fn _opts -> :ok end)
      stub_items()
      # A session that never answers: delivery is issued from the dying mob's
      # process, which must not sit in a GenServer.call -- a player mid-Steal
      # or mid-Spellbreaker is blocked calling that same mob.
      register_player(1, pid: fake_session(:never))

      task =
        Task.async(fn ->
          MvpReward.grant(
            %{1 => 100},
            mob(mvp_drops: [drop("FIRST")]),
            "gld_dun03",
            10,
            10,
            ownership()
          )
        end)

      assert :ok = Task.await(task, 1000)
      assert_receive {:session_call, {:npc, {:script_apply, {:give_item, 1001, 1}}}}
    end

    test "stamps an overweight fallback with the recipient and MVP ownership windows" do
      test = self()
      stub(Announcement, :to_all, fn _opts -> :ok end)

      stub(Coordinator, :drop_items, fn map, items, x, y, opts ->
        send(test, {:floor, map, items, x, y, opts})
        :ok
      end)

      stub_items()
      register_player(1, pid: fake_session({:error, :overweight}))
      ownership = ownership(first: 2, second: 1, third: 3)

      MvpReward.grant(
        %{1 => 100},
        mob(mvp_drops: [drop("FIRST")]),
        "gld_dun03",
        42,
        77,
        ownership
      )

      assert_receive {:floor, "gld_dun03", [{1001, 1, 42, 77, true}], 42, 77,
                      ownership: {%LootOwnership{first: 1, second: 2, third: 3}, true}}
    end

    test "scatters the item when the winner's session died before delivery" do
      test = self()
      stub(Announcement, :to_all, fn _opts -> :ok end)

      stub(Coordinator, :drop_items, fn map, items, x, y, opts ->
        send(test, {:floor, map, items, x, y, opts})
        :ok
      end)

      stub_items()

      dead = spawn(fn -> :ok end)
      ref = Process.monitor(dead)
      assert_receive {:DOWN, ^ref, :process, ^dead, _reason}

      register_player(1, pid: dead)

      MvpReward.grant(
        %{1 => 100},
        mob(mvp_drops: [drop("FIRST")]),
        "gld_dun03",
        42,
        77,
        ownership()
      )

      assert_receive {:floor, "gld_dun03", [{1001, 1, 42, 77, true}], 42, 77,
                      ownership: {%LootOwnership{first: 1, second: nil, third: nil}, true}}
    end

    test "grants exp and announces when no drop entry succeeds its roll" do
      test = self()
      stub(Announcement, :to_all, fn opts -> send(test, {:announced, opts}) end)
      stub(LevelPenalty, :mvp_drop, fn _mob_level, _base_level -> 0 end)
      reject(&Coordinator.drop_items/5)
      stub_items()
      register_player(1, pid: fake_session({:ok, %{}}))

      MvpReward.grant(
        %{1 => 100},
        mob(mvp_exp: 500, mvp_drops: [drop("FIRST"), drop("SECOND")]),
        "gld_dun03",
        10,
        10,
        ownership()
      )

      refute_receive {:session_call, _msg}
      assert_receive {:progression, {:mob_kill_exp, 500, 0, _race}}
      assert_receive {:announced, _opts}
    end
  end

  describe "grant/6 winner eligibility" do
    test "falls through to the next highest contributor when the top one is offline" do
      test = self()
      stub(Announcement, :to_all, fn opts -> send(test, {:announced, opts}) end)
      stub_items()
      register_player(2, name: "Runner", pid: fake_session({:ok, %{}}))

      MvpReward.grant(
        %{1 => 9000, 2 => 100},
        mob(mvp_exp: 700, mvp_drops: [drop("FIRST")]),
        "gld_dun03",
        10,
        10,
        ownership()
      )

      assert_receive {:progression, {:mob_kill_exp, 700, 0, _race}}
      assert_receive {:session_call, {:npc, {:script_apply, {:give_item, 1001, 1}}}}
      assert_receive {:announced, %{text: "Runner has defeated Baphomet!"}}
    end

    test "skips a contributor who left the mob's map" do
      test = self()
      stub(Announcement, :to_all, fn opts -> send(test, {:announced, opts}) end)
      stub_items()
      register_player(1, map_name: "prontera")
      register_player(2, name: "Stayer", pid: fake_session({:ok, %{}}))

      MvpReward.grant(
        %{1 => 9000, 2 => 100},
        mob(mvp_exp: 700),
        "gld_dun03",
        10,
        10,
        ownership()
      )

      assert_receive {:announced, %{text: "Stayer has defeated Baphomet!"}}
    end

    test "uses ranked ownership as-is when no MVP recipient exists" do
      test = self()
      reject(&Announcement.to_all/1)

      stub(Coordinator, :drop_items, fn map, items, x, y, opts ->
        send(test, {:floor, map, items, x, y, opts})
        :ok
      end)

      stub_items()
      ownership = ownership(first: 1, second: 2, third: 3)

      MvpReward.grant(
        %{1 => 9000},
        mob(mvp_exp: 700, mvp_drops: [drop("FIRST")]),
        "gld_dun03",
        42,
        77,
        ownership
      )

      assert_receive {:floor, "gld_dun03", [{1001, 1, 42, 77, true}], 42, 77,
                      ownership: {^ownership, true}}
    end

    test "an empty aggro list produces no reward and no announcement" do
      reject(&Announcement.to_all/1)
      reject(&Coordinator.drop_items/5)
      stub_items()

      assert :ok =
               MvpReward.grant(
                 %{},
                 mob(mvp_exp: 700, mvp_drops: [drop("FIRST")]),
                 "gld_dun03",
                 10,
                 10,
                 ownership()
               )
    end
  end
end
