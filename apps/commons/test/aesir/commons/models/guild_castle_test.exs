defmodule Aesir.Commons.Models.GuildCastleTest do
  use Aesir.DataCase, async: true

  alias Aesir.Commons.Models.GuildCastle

  defp valid_attrs(extra \\ %{}) do
    # The migration seed occupies castle_id 0..19, so tests stay above that range.
    Map.merge(
      %{
        castle_id: 100
      },
      extra
    )
  end

  describe "changeset/2" do
    test "accepts valid attrs" do
      changeset = GuildCastle.changeset(%GuildCastle{}, valid_attrs())
      assert changeset.valid?
    end

    test "requires castle_id" do
      changeset = GuildCastle.changeset(%GuildCastle{}, %{})

      refute changeset.valid?

      assert %{castle_id: ["can't be blank"]} = errors_on(changeset)
    end

    test "rejects negative economy and defense" do
      assert %{economy: _} =
               errors_on(GuildCastle.changeset(%GuildCastle{}, valid_attrs(%{economy: -1})))

      assert %{defense: _} =
               errors_on(GuildCastle.changeset(%GuildCastle{}, valid_attrs(%{defense: -1})))
    end

    test "rejects explicit nil economy and defense" do
      assert %{economy: _} =
               errors_on(GuildCastle.changeset(%GuildCastle{}, valid_attrs(%{economy: nil})))

      assert %{defense: _} =
               errors_on(GuildCastle.changeset(%GuildCastle{}, valid_attrs(%{defense: nil})))
    end

    test "rejects a duplicate castle_id as a changeset error, not a raised error" do
      assert {:ok, _castle} =
               %GuildCastle{}
               |> GuildCastle.changeset(valid_attrs())
               |> Repo.insert()

      assert {:error, changeset} =
               %GuildCastle{}
               |> GuildCastle.changeset(valid_attrs())
               |> Repo.insert()

      assert %{castle_id: ["has already been taken"]} = errors_on(changeset)
    end

    test "defaults economy and defense to 0 on insert" do
      assert {:ok, castle} =
               %GuildCastle{}
               |> GuildCastle.changeset(valid_attrs())
               |> Repo.insert()

      assert castle.economy == 0
      assert castle.defense == 0
    end
  end

  describe "new/1" do
    test "builds an insertable changeset from attrs" do
      changeset = GuildCastle.new(valid_attrs())
      assert changeset.valid?
    end
  end

  describe "seed" do
    test "migration seeds one unoccupied row per FE castle (0..19)" do
      castles = Repo.all(from c in GuildCastle, where: c.castle_id < 20, order_by: c.castle_id)

      assert Enum.map(castles, & &1.castle_id) == Enum.to_list(0..19)
      assert Enum.all?(castles, &is_nil(&1.guild_id))
    end
  end
end
