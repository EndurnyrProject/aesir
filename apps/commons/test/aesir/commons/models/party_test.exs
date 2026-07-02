defmodule Aesir.Commons.Models.PartyTest do
  use Aesir.DataCase, async: true

  alias Aesir.Commons.Models.Party

  defp valid_attrs(extra \\ %{}) do
    Map.merge(
      %{
        name: "Bravehearts",
        leader_char_id: 1
      },
      extra
    )
  end

  describe "changeset/2" do
    test "accepts valid attrs" do
      changeset = Party.changeset(%Party{}, valid_attrs())
      assert changeset.valid?
    end

    test "requires name and leader_char_id" do
      changeset = Party.changeset(%Party{}, %{})

      refute changeset.valid?

      assert %{name: ["can't be blank"], leader_char_id: ["can't be blank"]} =
               errors_on(changeset)
    end

    test "rejects a blank name after trimming" do
      changeset = Party.changeset(%Party{}, valid_attrs(%{name: "   "}))

      refute changeset.valid?
      assert %{name: [_ | _]} = errors_on(changeset)
    end

    test "rejects a duplicate name as a changeset error, not a raised error" do
      assert {:ok, _party} =
               %Party{}
               |> Party.changeset(valid_attrs())
               |> Repo.insert()

      assert {:error, changeset} =
               %Party{}
               |> Party.changeset(valid_attrs(%{leader_char_id: 2}))
               |> Repo.insert()

      assert %{name: ["has already been taken"]} = errors_on(changeset)
    end

    test "defaults exp_share to false on insert" do
      assert {:ok, party} =
               %Party{}
               |> Party.changeset(valid_attrs())
               |> Repo.insert()

      assert party.exp_share == false
    end
  end

  describe "new/1" do
    test "builds an insertable changeset from attrs" do
      changeset = Party.new(valid_attrs())
      assert changeset.valid?
    end
  end
end
