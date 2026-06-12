defmodule Aesir.ZoneServer.Mmo.MobManagement.DefinitionTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Mmo.MobManagement.Definition
  alias Aesir.ZoneServer.Mmo.MobManagement.MobDefinition
  alias Aesir.ZoneServer.Mmo.MobManagement.MobDrop

  defmodule TestMob do
    use Aesir.ZoneServer.Mmo.MobManagement.Definition,
      id: 9001,
      aegis_name: :TEST_MOB,
      name: "Test Mob",
      level: 5,
      hp: 100,
      atk_min: 10,
      atk_max: 20,
      stats: %{str: 1, agi: 2, vit: 3, int: 4, dex: 5, luk: 6},
      attack_range: 1,
      size: :medium,
      race: :plant,
      element: {:water, 1},
      walk_speed: 400,
      attack_delay: 1_872,
      attack_motion: 672,
      client_attack_motion: 288,
      damage_motion: 480,
      drops: [
        %{item: "Jellopy", rate: 7_000},
        %{item: "Test_Card", rate: 20, steal_protected: true}
      ]
  end

  defp valid_opts do
    [
      id: 9100,
      aegis_name: :VALID_MOB,
      name: "Valid Mob",
      level: 1,
      hp: 10,
      atk_min: 1,
      atk_max: 2,
      stats: %{str: 1, agi: 1, vit: 1, int: 1, dex: 1, luk: 1},
      attack_range: 1,
      size: :small,
      race: :brute,
      element: {:neutral, 1},
      walk_speed: 200,
      attack_delay: 1_000,
      attack_motion: 500,
      client_attack_motion: 250,
      damage_motion: 400
    ]
  end

  describe "use macro" do
    test "generates mob/0 returning the full struct" do
      assert %MobDefinition{
               id: 9001,
               aegis_name: :TEST_MOB,
               name: "Test Mob",
               level: 5,
               hp: 100,
               atk_min: 10,
               atk_max: 20,
               size: :medium,
               race: :plant,
               element: {:water, 1}
             } = TestMob.mob()
    end

    test "generates id/0" do
      assert TestMob.id() == 9001
    end

    test "fills schema defaults" do
      mob = TestMob.mob()

      assert mob.sp == 0
      assert mob.base_exp == 0
      assert mob.job_exp == 0
      assert mob.def == 0
      assert mob.mdef == 0
      assert mob.skill_range == 10
      assert mob.chase_range == 12
      assert mob.ai_type == 0
      assert mob.modes == []
    end

    test "builds drops into MobDrop structs" do
      assert [
               %MobDrop{item: "Jellopy", rate: 7_000, steal_protected: false},
               %MobDrop{item: "Test_Card", rate: 20, steal_protected: true}
             ] = TestMob.mob().drops
    end

    test "raises at compile time on unknown keys" do
      assert_raise ArgumentError, ~r/unknown/i, fn ->
        defmodule UnknownKey do
          use Aesir.ZoneServer.Mmo.MobManagement.Definition,
            id: 9002,
            aegis_name: :UNKNOWN_KEY,
            name: "Unknown Key",
            level: 1,
            hp: 10,
            atk_min: 1,
            atk_max: 1,
            stats: %{str: 1, agi: 1, vit: 1, int: 1, dex: 1, luk: 1},
            attack_range: 1,
            size: :small,
            race: :brute,
            element: {:neutral, 1},
            walk_speed: 200,
            attack_delay: 1_000,
            attack_motion: 500,
            client_attack_motion: 250,
            damage_motion: 400,
            hitpoints: 99
        end
      end
    end
  end

  describe "build!/2 validation" do
    test "builds a valid definition" do
      assert %MobDefinition{id: 9100, aegis_name: :VALID_MOB} =
               Definition.build!(valid_opts(), __MODULE__)
    end

    test "raises when a required field is missing" do
      assert_raise ArgumentError, ~r/hp/, fn ->
        Definition.build!(Keyword.delete(valid_opts(), :hp), __MODULE__)
      end
    end

    test "raises on invalid race" do
      assert_raise ArgumentError, ~r/race/, fn ->
        Definition.build!(Keyword.put(valid_opts(), :race, :alien), __MODULE__)
      end
    end

    test "raises on invalid size" do
      assert_raise ArgumentError, ~r/size/, fn ->
        Definition.build!(Keyword.put(valid_opts(), :size, :huge), __MODULE__)
      end
    end

    test "raises on invalid element level" do
      assert_raise ArgumentError, ~r/element/, fn ->
        Definition.build!(Keyword.put(valid_opts(), :element, {:water, 5}), __MODULE__)
      end
    end

    test "raises on drop rate out of range" do
      opts = Keyword.put(valid_opts(), :drops, [%{item: "Jellopy", rate: 20_000}])

      assert_raise ArgumentError, ~r/rate/, fn ->
        Definition.build!(opts, __MODULE__)
      end
    end

    test "raises on unknown drop keys" do
      opts = Keyword.put(valid_opts(), :drops, [%{item: "Jellopy", rate: 100, chance: 5}])

      assert_raise ArgumentError, ~r/unknown.*chance/is, fn ->
        Definition.build!(opts, __MODULE__)
      end
    end

    test "raises on unknown stats keys" do
      stats = %{str: 1, agi: 1, vit: 1, int: 1, dex: 1, luk: 1, wis: 1}

      assert_raise ArgumentError, ~r/unknown.*wis/is, fn ->
        Definition.build!(Keyword.put(valid_opts(), :stats, stats), __MODULE__)
      end
    end

    test "raises when atk_min is greater than atk_max" do
      opts = valid_opts() |> Keyword.put(:atk_min, 5) |> Keyword.put(:atk_max, 2)

      assert_raise ArgumentError, ~r/atk_min/, fn ->
        Definition.build!(opts, __MODULE__)
      end
    end

    test "raises on unknown mode" do
      assert_raise ArgumentError, ~r/modes/, fn ->
        Definition.build!(Keyword.put(valid_opts(), :modes, [:agressive]), __MODULE__)
      end
    end
  end
end
