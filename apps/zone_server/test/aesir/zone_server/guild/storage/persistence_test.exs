defmodule Aesir.ZoneServer.Guild.Storage.PersistenceTest do
  use Aesir.DataCase, async: true

  alias Aesir.Commons.Models.Guild
  alias Aesir.Commons.Models.GuildStorageLog
  alias Aesir.ZoneServer.Guild.Storage.Persistence

  setup do
    {:ok, guild} =
      %Guild{}
      |> Guild.changeset(%{
        name: "Guild #{System.unique_integer([:positive])}",
        master_char_id: 1
      })
      |> Repo.insert()

    %{guild: guild}
  end

  describe "load_storage/1" do
    test "returns a guild's rows ordered by id", %{guild: guild} do
      {:ok, first} = Persistence.insert_item(guild.id, %{nameid: 501, amount: 1})
      {:ok, second} = Persistence.insert_item(guild.id, %{nameid: 1201, amount: 1})

      assert [^first, ^second] = Persistence.load_storage(guild.id)
    end
  end

  describe "update_amount/4" do
    test "rejects an amount changed since it was read", %{guild: guild} do
      {:ok, item} = Persistence.insert_item(guild.id, %{nameid: 501, amount: 5})

      assert :ok = Persistence.update_amount(guild.id, item.id, 5, 3)
      assert {:error, :stale} = Persistence.update_amount(guild.id, item.id, 5, 1)
    end
  end

  describe "delete_item/3" do
    test "rejects an amount changed since it was read and a missing row", %{guild: guild} do
      {:ok, item} = Persistence.insert_item(guild.id, %{nameid: 501, amount: 5})

      assert {:error, :stale} = Persistence.delete_item(guild.id, item.id, 4)
      assert :ok = Persistence.delete_item(guild.id, item.id, 5)
      assert {:error, :stale} = Persistence.delete_item(guild.id, item.id, 5)
    end
  end

  describe "to_session_item/1 and to_row_attrs/1" do
    test "round-trips transfer metadata including craft", %{guild: guild} do
      expire_time = ~N[2027-01-01 00:00:00]
      craft = %{"creator" => "Blacksmith", "signature" => "Aesir"}

      {:ok, row} =
        Persistence.insert_item(guild.id, %{
          nameid: 501,
          amount: 3,
          identify: 1,
          refine: 7,
          attribute: 1,
          card0: 4001,
          card1: 4002,
          card2: 4003,
          card3: 4004,
          craft: craft,
          random_options: %{"1" => %{"val" => 5, "parm" => 0}},
          expire_time: expire_time,
          bound: 2,
          unique_id: 123_456_789,
          enchant_grade: 3
        })

      session_item = Persistence.to_session_item(row)
      attrs = Persistence.to_row_attrs(session_item)

      assert session_item.craft == craft
      assert attrs.craft == craft
      assert {:ok, copied_row} = Persistence.insert_item(guild.id, attrs)

      assert copied_row.random_options == row.random_options
      assert copied_row.craft == row.craft
      assert copied_row.bound == row.bound
      assert copied_row.unique_id == row.unique_id
      assert copied_row.enchant_grade == row.enchant_grade
      assert copied_row.expire_time == row.expire_time
    end
  end

  describe "transaction/1" do
    test "rolls back writes when the callback returns an error", %{guild: guild} do
      assert {:error, :rollback} =
               Persistence.transaction(fn ->
                 {:ok, _item} = Persistence.insert_item(guild.id, %{nameid: 501, amount: 1})
                 {:error, :rollback}
               end)

      assert [] = Persistence.load_storage(guild.id)
    end
  end

  describe "log/4" do
    test "appends signed deposits and withdrawals", %{guild: guild} do
      item = Persistence.to_session_item(%{insert_item!(guild) | amount: 3})

      assert :ok = Persistence.log(guild.id, 77, item, 3)
      assert :ok = Persistence.log(guild.id, 77, item, -3)

      assert [3, -3] =
               from(log in GuildStorageLog,
                 where: log.guild_id == ^guild.id,
                 order_by: log.id,
                 select: log.amount
               )
               |> Repo.all()
    end
  end

  test "does not expose a bulk-delete function" do
    refute function_exported?(Persistence, :delete_all_for_guild, 1)
  end

  defp insert_item!(guild) do
    {:ok, item} =
      Persistence.insert_item(guild.id, %{
        nameid: 501,
        amount: 1,
        refine: 7,
        card0: 4001,
        card1: 4002,
        card2: 4003,
        card3: 4004,
        unique_id: 123
      })

    item
  end
end
