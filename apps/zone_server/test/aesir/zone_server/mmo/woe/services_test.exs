defmodule Aesir.ZoneServer.Mmo.Woe.ServicesTest do
  use Aesir.DataCase, async: false
  use Mimic

  @moduletag :capture_log

  alias Aesir.ZoneServer.Content.Npc.Woe.InsideFlag
  alias Aesir.ZoneServer.Content.Npc.Woe.Kafra
  alias Aesir.ZoneServer.Content.Npc.Woe.OutsideFlag
  alias Aesir.ZoneServer.Guild.Manager, as: GuildManager
  alias Aesir.ZoneServer.Guild.State, as: GuildState
  alias Aesir.ZoneServer.Mmo.Woe.CastleDb
  alias Aesir.ZoneServer.Mmo.Woe.CastleStore
  alias Aesir.ZoneServer.Mmo.Woe.Persistence
  alias Aesir.ZoneServer.Mmo.Woe.Services
  alias Aesir.ZoneServer.Npc.Registry, as: NpcRegistry
  alias Aesir.ZoneServer.Npc.Session, as: NpcSession
  alias Aesir.ZoneServer.Unit.Broadcast

  setup :set_mimic_private
  setup :verify_on_exit!

  setup do
    Aesir.TestEtsSetup.setup_ets_tables(%{})
    :ok = CastleStore.init()

    prev_inline = Application.get_env(:zone_server, :inline_persistence)
    Application.put_env(:zone_server, :inline_persistence, true)

    on_exit(fn ->
      case prev_inline do
        nil -> Application.delete_env(:zone_server, :inline_persistence)
        value -> Application.put_env(:zone_server, :inline_persistence, value)
      end
    end)

    :ok
  end

  defp row(guild_id, overrides \\ %{}) do
    Map.merge(
      %{guild_id: guild_id, economy: 0, defense: 0, invested_economy: 0, invested_defense: 0},
      overrides
    )
  end

  defp fixture_guild(id, skills \\ %{}) do
    %GuildState{guild_id: id, name: "Test Guild", master_char_id: 1, learned_skills: skills}
  end

  defp contracted_guild(id), do: fixture_guild(id, %{10_001 => 1})

  defp kafra_gid(castle) do
    [{_module, placement}] = NpcRegistry.by_name("Kafra Employee#" <> castle.map)
    NpcRegistry.entity_id(placement)
  end

  describe "kafra_hire_cost/0" do
    test "is 10_000" do
      assert Services.kafra_hire_cost() == 10_000
    end
  end

  describe "kafra_hired?/1" do
    test "reflects the castle store flag" do
      [castle | _] = CastleDb.all()
      refute Services.kafra_hired?(castle.id)

      :ok = CastleStore.put_kafra(castle.id, true)
      assert Services.kafra_hired?(castle.id)
    end
  end

  describe "hire_check/2" do
    setup do
      [castle | _] = CastleDb.all()
      :ok = CastleStore.hydrate(%{castle.id => row(1)})
      %{castle: castle}
    end

    test "not_owner when the guild does not hold the castle", %{castle: castle} do
      assert Services.hire_check(castle.id, 2) == {:error, :not_owner}
    end

    test "contract_required when the guild has no Kafra Contract", %{castle: castle} do
      stub(GuildManager, :get, fn 1 -> {:error, :not_found} end)
      assert Services.hire_check(castle.id, 1) == {:error, :contract_required}
    end

    test "contract_required when the guild's skill level is below 1", %{castle: castle} do
      stub(GuildManager, :get, fn 1 -> {:ok, fixture_guild(1)} end)
      assert Services.hire_check(castle.id, 1) == {:error, :contract_required}
    end

    test "already_hired when the Kafra is already hired", %{castle: castle} do
      stub(GuildManager, :get, fn 1 -> {:ok, contracted_guild(1)} end)
      :ok = CastleStore.put_kafra(castle.id, true)
      assert Services.hire_check(castle.id, 1) == {:error, :already_hired}
    end

    test "ok when owned, contracted, and not yet hired", %{castle: castle} do
      stub(GuildManager, :get, fn 1 -> {:ok, contracted_guild(1)} end)
      assert Services.hire_check(castle.id, 1) == :ok
    end
  end

  describe "hire_kafra/2" do
    test "sets the store flag, persists, and enables the Kafra placement" do
      [castle | _] = CastleDb.all()
      :ok = CastleStore.hydrate(%{castle.id => row(1)})
      stub(GuildManager, :get, fn 1 -> {:ok, contracted_guild(1)} end)

      NpcRegistry.reload([Kafra])
      on_exit(fn -> NpcRegistry.reload() end)

      gid = kafra_gid(castle)
      on_exit(fn -> NpcSession.set_enabled(gid, true) end)

      assert Services.hire_kafra(castle.id, 1) == :ok
      assert CastleStore.kafra?(castle.id) == true
      assert NpcSession.enabled?(gid) == true
      assert Persistence.load_all()[castle.id].kafra == true
    end

    test "returns the hire_check error unchanged" do
      [castle | _] = CastleDb.all()
      assert Services.hire_kafra(castle.id, 999) == {:error, :not_owner}
    end

    test "skips the visibility change when the Kafra placement is not registered" do
      [castle | _] = CastleDb.all()
      :ok = CastleStore.hydrate(%{castle.id => row(1)})
      stub(GuildManager, :get, fn 1 -> {:ok, contracted_guild(1)} end)

      NpcRegistry.reload([])
      on_exit(fn -> NpcRegistry.reload() end)

      assert Services.hire_kafra(castle.id, 1) == :ok
      assert CastleStore.kafra?(castle.id) == true
    end
  end

  describe "fire_kafra/2" do
    test "not_owner when the guild does not hold the castle" do
      [castle | _] = CastleDb.all()
      :ok = CastleStore.hydrate(%{castle.id => row(1)})
      assert Services.fire_kafra(castle.id, 2) == {:error, :not_owner}
    end

    test "not_hired when the Kafra is not hired" do
      [castle | _] = CastleDb.all()
      :ok = CastleStore.hydrate(%{castle.id => row(1)})
      assert Services.fire_kafra(castle.id, 1) == {:error, :not_hired}
    end

    test "reverses hire_kafra/2" do
      [castle | _] = CastleDb.all()
      :ok = CastleStore.hydrate(%{castle.id => row(1)})
      stub(GuildManager, :get, fn 1 -> {:ok, contracted_guild(1)} end)

      NpcRegistry.reload([Kafra])
      on_exit(fn -> NpcRegistry.reload() end)

      gid = kafra_gid(castle)
      on_exit(fn -> NpcSession.set_enabled(gid, true) end)

      assert Services.hire_kafra(castle.id, 1) == :ok
      assert Services.fire_kafra(castle.id, 1) == :ok

      assert CastleStore.kafra?(castle.id) == false
      assert NpcSession.enabled?(gid) == false
      assert Persistence.load_all()[castle.id].kafra == false
    end
  end

  describe "on_conquest/1" do
    test "clears the flag, disables the placement, and broadcasts exactly one packet per flag" do
      {:ok, castle} = CastleDb.by_map("gefg_cas01")
      :ok = CastleStore.hydrate(%{castle.id => row(1, %{kafra: true})})

      NpcRegistry.reload([Kafra, OutsideFlag, InsideFlag])
      on_exit(fn -> NpcRegistry.reload() end)

      gid = kafra_gid(castle)
      on_exit(fn -> NpcSession.set_enabled(gid, true) end)

      expect(Broadcast, :to_in_range, 11, fn _map, _x, _y, _range, _packet -> :ok end)

      assert Services.on_conquest(castle) == :ok

      assert CastleStore.kafra?(castle.id) == false
      assert NpcSession.enabled?(gid) == false
      assert Persistence.load_all()[castle.id].kafra == false
    end

    test "broadcasts nothing for a castle with no registered flags" do
      {:ok, castle} = CastleDb.by_map("gefg_cas01")
      :ok = CastleStore.hydrate(%{castle.id => row(1, %{kafra: true})})

      NpcRegistry.reload([Kafra])
      on_exit(fn -> NpcRegistry.reload() end)

      gid = kafra_gid(castle)
      on_exit(fn -> NpcSession.set_enabled(gid, true) end)

      reject(&Broadcast.to_in_range/5)

      assert Services.on_conquest(castle) == :ok
    end
  end

  describe "on_release/1" do
    test "disables the placement, broadcasts exactly one packet per flag, and touches neither the store nor persistence" do
      {:ok, castle} = CastleDb.by_map("gefg_cas01")
      :ok = CastleStore.hydrate(%{castle.id => row(1, %{kafra: true})})

      NpcRegistry.reload([Kafra, OutsideFlag, InsideFlag])
      on_exit(fn -> NpcRegistry.reload() end)

      gid = kafra_gid(castle)
      on_exit(fn -> NpcSession.set_enabled(gid, true) end)

      reject(&CastleStore.put_kafra/2)
      reject(&Persistence.persist_kafra/2)
      expect(Broadcast, :to_in_range, 11, fn _map, _x, _y, _range, _packet -> :ok end)

      assert Services.on_release(castle) == :ok

      assert CastleStore.kafra?(castle.id) == true
      assert NpcSession.enabled?(gid) == false
    end

    test "broadcasts nothing for a castle with no registered flags" do
      {:ok, castle} = CastleDb.by_map("gefg_cas01")
      :ok = CastleStore.hydrate(%{castle.id => row(1, %{kafra: true})})

      NpcRegistry.reload([Kafra])
      on_exit(fn -> NpcRegistry.reload() end)

      gid = kafra_gid(castle)
      on_exit(fn -> NpcSession.set_enabled(gid, true) end)

      reject(&Broadcast.to_in_range/5)

      assert Services.on_release(castle) == :ok
    end
  end

  describe "sync_all/0" do
    test "after hydrate, enables the hired castle's Kafra and disables the rest" do
      [hired, other | _] = CastleDb.all()
      :ok = CastleStore.hydrate(%{hired.id => row(1, %{kafra: true}), other.id => row(2)})

      NpcRegistry.reload([Kafra])
      on_exit(fn -> NpcRegistry.reload() end)

      hired_gid = kafra_gid(hired)
      other_gid = kafra_gid(other)
      on_exit(fn -> NpcSession.set_enabled(hired_gid, true) end)
      on_exit(fn -> NpcSession.set_enabled(other_gid, true) end)

      assert Services.sync_all() == :ok

      assert NpcSession.enabled?(hired_gid) == true
      assert NpcSession.enabled?(other_gid) == false
    end
  end
end
