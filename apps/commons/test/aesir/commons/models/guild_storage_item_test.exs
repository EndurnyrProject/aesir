defmodule Aesir.Commons.Models.GuildStorageItemTest do
  use Aesir.DataCase, async: true

  alias Aesir.Commons.Models.Guild
  alias Aesir.Commons.Models.GuildStorageItem

  defp guild! do
    {:ok, guild} =
      %Guild{}
      |> Guild.changeset(%{name: "Guild Storage Test", master_char_id: 1})
      |> Repo.insert()

    guild
  end

  describe "changeset/2" do
    test "casts and round-trips craft metadata" do
      guild = guild!()
      craft = %{"creator" => "Blacksmith"}

      changeset =
        GuildStorageItem.changeset(%GuildStorageItem{}, %{
          guild_id: guild.id,
          nameid: 501,
          amount: 3,
          craft: craft
        })

      assert changeset.valid?
      assert Ecto.Changeset.get_change(changeset, :craft) == craft
      assert {:ok, item} = Repo.insert(changeset)
      assert %GuildStorageItem{craft: ^craft} = Repo.get!(GuildStorageItem, item.id)
    end

    test "rejects a non-positive amount" do
      changeset =
        GuildStorageItem.changeset(%GuildStorageItem{amount: 5}, %{
          guild_id: 1,
          nameid: 501,
          amount: 0
        })

      refute changeset.valid?
      assert %{amount: ["must be greater than 0"]} = errors_on(changeset)
    end

    test "requires guild_id, nameid and amount" do
      changeset = GuildStorageItem.changeset(%GuildStorageItem{}, %{})

      refute changeset.valid?
      assert Enum.sort(changeset.required) == [:amount, :guild_id, :nameid]
      assert %{guild_id: ["can't be blank"]} = errors_on(changeset)
    end

    test "returns a changeset error for an unknown guild" do
      assert {:error, changeset} =
               %GuildStorageItem{}
               |> GuildStorageItem.changeset(%{guild_id: 999_999, nameid: 501, amount: 1})
               |> Repo.insert()

      assert %{guild_id: ["does not exist"]} = errors_on(changeset)
    end

    test "deleting a guild deletes its storage items" do
      guild = guild!()

      {:ok, item} =
        %GuildStorageItem{}
        |> GuildStorageItem.changeset(%{guild_id: guild.id, nameid: 501, amount: 1})
        |> Repo.insert()

      assert {:ok, _guild} = Repo.delete(guild)
      assert Repo.get(GuildStorageItem, item.id) == nil
    end
  end
end
