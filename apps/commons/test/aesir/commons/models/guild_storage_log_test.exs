defmodule Aesir.Commons.Models.GuildStorageLogTest do
  use Aesir.DataCase, async: true

  alias Aesir.Commons.Models.GuildStorageLog

  describe "changeset/2" do
    test "accepts a negative amount for a withdrawal" do
      changeset =
        GuildStorageLog.changeset(%GuildStorageLog{}, %{
          guild_id: 1,
          char_id: 2,
          nameid: 501,
          amount: -3,
          refine: 7,
          card0: 4001,
          card1: 4002,
          card2: 4003,
          card3: 4004,
          unique_id: 123
        })

      assert changeset.valid?
    end

    test "accepts a positive amount for a deposit" do
      changeset =
        GuildStorageLog.changeset(%GuildStorageLog{}, %{
          guild_id: 1,
          char_id: 2,
          nameid: 501,
          amount: 3
        })

      assert changeset.valid?
    end

    test "requires an amount" do
      changeset =
        GuildStorageLog.changeset(%GuildStorageLog{}, %{guild_id: 1, char_id: 2, nameid: 501})

      refute changeset.valid?
      assert %{amount: ["can't be blank"]} = errors_on(changeset)
    end

    test "persists withdrawal details with an insertion timestamp" do
      assert {:ok, log} =
               %GuildStorageLog{}
               |> GuildStorageLog.changeset(%{
                 guild_id: 1,
                 char_id: 2,
                 nameid: 501,
                 amount: -3,
                 refine: 7,
                 card0: 4001,
                 card1: 4002,
                 card2: 4003,
                 card3: 4004,
                 unique_id: 123
               })
               |> Repo.insert()

      assert %GuildStorageLog{
               guild_id: 1,
               char_id: 2,
               nameid: 501,
               amount: -3,
               refine: 7,
               card0: 4001,
               card1: 4002,
               card2: 4003,
               card3: 4004,
               unique_id: 123,
               inserted_at: %NaiveDateTime{}
             } = log
    end
  end
end
