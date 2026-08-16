defmodule Aesir.ZoneServer.Mmo.Woe.PersistenceTest do
  use Aesir.DataCase, async: false

  alias Aesir.Commons.Models.GuildCastle
  alias Aesir.Repo
  alias Aesir.ZoneServer.Mmo.Woe.Persistence

  setup do
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

  describe "persist/2" do
    test "returns :ok immediately (fire-and-forget contract)" do
      assert :ok = Persistence.persist(0, 42)
      assert :ok = Persistence.persist(1, nil)
    end

    test "round-trips ownership through load_all/0" do
      :ok = Persistence.persist(5, 100)
      assert Persistence.load_all() == %{5 => 100}
    end

    test "releases a castle when guild_id is nil" do
      :ok = Persistence.persist(5, 100)
      assert Persistence.load_all() == %{5 => 100}

      :ok = Persistence.persist(5, nil)
      assert Persistence.load_all() == %{}
    end

    test "does not overwrite economy or defense fields" do
      castle =
        Repo.get_by!(GuildCastle, castle_id: 10)
        |> GuildCastle.changeset(%{economy: 5, defense: 3})
        |> Repo.update!()

      assert castle.economy == 5
      assert castle.defense == 3

      :ok = Persistence.persist(10, 500)

      updated = Repo.get_by!(GuildCastle, castle_id: 10)
      assert updated.guild_id == 500
      assert updated.economy == 5
      assert updated.defense == 3
    end

    test "real async path writes to the DB without blocking the caller" do
      Application.put_env(:zone_server, :inline_persistence, false)

      assert :ok = Persistence.persist(2, 999)

      wait_for_ownership(2, 999, 50, 10)
    end
  end

  describe "load_all/0" do
    test "returns only occupied castles" do
      assert Persistence.load_all() == %{}

      :ok = Persistence.persist(0, 10)
      :ok = Persistence.persist(1, 20)
      :ok = Persistence.persist(2, 30)

      assert Persistence.load_all() == %{0 => 10, 1 => 20, 2 => 30}

      :ok = Persistence.persist(1, nil)

      assert Persistence.load_all() == %{0 => 10, 2 => 30}
    end
  end

  defp wait_for_ownership(castle_id, expected_guild_id, retries, delay_ms) do
    cond do
      Persistence.load_all()[castle_id] == expected_guild_id ->
        :ok

      retries > 0 ->
        Process.sleep(delay_ms)
        wait_for_ownership(castle_id, expected_guild_id, retries - 1, delay_ms)

      true ->
        flunk(
          "Async persist did not write guild_id #{expected_guild_id} for castle #{castle_id} " <>
            "within #{retries * delay_ms}ms"
        )
    end
  end
end
