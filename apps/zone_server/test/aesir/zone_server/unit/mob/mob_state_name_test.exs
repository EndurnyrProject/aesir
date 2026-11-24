defmodule Aesir.ZoneServer.Unit.Mob.MobStateNameTest do
  use ExUnit.Case, async: true

  import Aesir.ZoneServer.Factory

  alias Aesir.ZoneServer.Unit.Mob.MobState

  defp mob(attrs \\ []) do
    build(:mob_state, mob_data: build(:mob_definition, Map.new(attrs)))
  end

  describe "set_name/2 (rAthena mob_parse_dataset)" do
    test "an unnamed spawn shows the database Name" do
      assert MobState.display_name(mob(name: "Poring")) == "Poring"
    end

    test "a script name replaces the database Name" do
      state = mob(name: "Elder") |> MobState.set_name("Guard")

      assert MobState.display_name(state) == "Guard"
    end

    test "nil leaves an earlier name in place" do
      state = mob() |> MobState.set_name("Guard") |> MobState.set_name(nil)

      assert MobState.display_name(state) == "Guard"
    end

    test "--en-- shows the database Name" do
      state = mob(name: "Elder") |> MobState.set_name("--en--")

      assert MobState.display_name(state) == "Elder"
    end

    test "--ja-- shows the JapaneseName, or the Name when the mob has none" do
      assert mob(name: "Elder", japanese_name: "Elder Wilow")
             |> MobState.set_name("--ja--")
             |> MobState.display_name() == "Elder Wilow"

      assert mob(name: "Elder") |> MobState.set_name("--ja--") |> MobState.display_name() ==
               "Elder"
    end

    test "a name past NAME_LENGTH keeps its first 23 bytes" do
      state = mob() |> MobState.set_name("Lune of the Eternal Glacier")

      assert MobState.display_name(state) == "Lune of the Eternal Gla"
    end

    test "the cap never splits a multi-byte character" do
      state = mob() |> MobState.set_name(String.duplicate("a", 22) <> "éé")

      assert MobState.display_name(state) == String.duplicate("a", 22)
    end
  end

  test "a class change drops the spawn name for the new form's Name (mob_class_change)" do
    state =
      mob(name: "Elder")
      |> MobState.set_name("Guard")
      |> MobState.change_form(build(:mob_definition, id: 1003, name: "Lunatic"))

    assert MobState.display_name(state) == "Lunatic"
  end
end
