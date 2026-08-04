defmodule Aesir.ZoneServer.Unit.Homunculus.ProgressionHandlerTest do
  use Aesir.DataCase, async: true
  use Mimic

  alias Aesir.Commons.Models.Account
  alias Aesir.Commons.Models.Character
  alias Aesir.Commons.Models.Homunculus
  alias Aesir.ZoneServer.Mmo.Homunculus.Ai.Config
  alias Aesir.ZoneServer.Mmo.Homunculus.Catalog
  alias Aesir.ZoneServer.Mmo.Homunculus.ExpTable
  alias Aesir.ZoneServer.Mmo.Homunculus.Growth
  alias Aesir.ZoneServer.Unit.Homunculus.Handlers.ProgressionHandler
  alias Aesir.ZoneServer.Unit.Homunculus.HomunculusState
  alias Aesir.ZoneServer.Unit.Homunculus.Persistence

  setup :verify_on_exit!
  setup :set_mimic_from_context

  setup do
    Mimic.copy(Repo)
    :ok
  end

  setup do
    suffix = System.unique_integer([:positive])
    username = "progression#{suffix}"

    {:ok, account} =
      %Account{}
      |> Account.changeset(%{
        username: username,
        userid: username,
        user_pass: "password",
        email: "progression#{suffix}@example.com"
      })
      |> Repo.insert()

    {:ok, character} =
      %Character{}
      |> Character.changeset(%{
        account_id: account.id,
        char_num: 0,
        name: "Progression#{suffix}",
        class: 1,
        base_level: 99,
        str: 10,
        agi: 10,
        vit: 10,
        int: 10,
        dex: 10,
        luk: 10
      })
      |> Repo.insert()

    %{character: character}
  end

  test "growth rolls every inclusive species range independently" do
    {:ok, species} = Catalog.by_id(6_001)

    roll = fn min, max ->
      send(self(), {:rolled, min, max})
      min
    end

    assert %{
             hp: 60,
             sp: 4,
             str: 0,
             agi: 0,
             vit: 0,
             int: 0,
             dex: 0,
             luk: 0
           } = Growth.level(species, roll: roll)

    assert_received {:rolled, 60, 100}
    assert_received {:rolled, 4, 9}
    assert_received {:rolled, 5, 19}
    assert_received {:rolled, 5, 19}
    assert_received {:rolled, 5, 19}
    assert_received {:rolled, 4, 20}
    assert_received {:rolled, 6, 20}
    assert_received {:rolled, 6, 20}

    assert %{hp: 100, sp: 9, str: 1, agi: 1, vit: 1, int: 2, dex: 2, luk: 2} =
             Growth.level(species, roll: fn _min, max -> max end)
  end

  test "Growth rejects injected rolls outside the requested inclusive range" do
    {:ok, species} = Catalog.by_id(6_001)

    assert_raise ArgumentError, ~r/inclusive range/, fn ->
      Growth.level(species, roll: fn min, _max -> min - 1 end)
    end

    assert_raise ArgumentError, ~r/inclusive range/, fn ->
      Growth.evolution(species, roll: fn _min, max -> max + 1 end)
    end
  end

  test "one EXP gain crosses multiple thresholds, rolls every level, heals, and persists", %{
    character: character
  } do
    row = insert_homunculus(character.id, %{level: 1, exp: 100, hp: 1, sp: 2})
    state = state(row)
    {:ok, level_one_exp} = ExpTable.exp_for(1)
    {:ok, level_two_exp} = ExpTable.exp_for(2)

    assert {:ok, progressed} =
             ProgressionHandler.gain_exp(
               state,
               level_one_exp - 100 + level_two_exp,
               roll: fn min, _max -> min end
             )

    assert progressed.level == 3
    assert progressed.exp == 0
    assert progressed.skill_points == 1
    assert progressed.max_hp == 220
    assert progressed.max_sp == 58
    assert progressed.hp == progressed.max_hp
    assert progressed.sp == progressed.max_sp
    assert progressed.str == 10

    reloaded = Persistence.load_for_character(character.id)
    assert reloaded.level == progressed.level
    assert reloaded.exp == progressed.exp
    assert reloaded.max_hp == progressed.max_hp
    assert reloaded.max_sp == progressed.max_sp
    assert reloaded.str == progressed.str
  end

  test "one gain awards a skill point at every crossed level divisible by three", %{
    character: character
  } do
    row = insert_homunculus(character.id, %{skill_points: 2})
    amount = Enum.reduce(1..9, 0, fn level, total -> total + elem(ExpTable.exp_for(level), 1) end)

    assert {:ok, progressed} =
             ProgressionHandler.gain_exp(state(row), amount, roll: fn min, _max -> min end)

    assert progressed.level == 10
    assert progressed.skill_points == 5
    assert Persistence.load_for_character(character.id).skill_points == 5
  end

  test "level 99 persists zero EXP and further gains never roll", %{character: character} do
    row = insert_homunculus(character.id, %{level: 98, exp: 0})
    state = state(row)
    {:ok, required} = ExpTable.exp_for(98)

    assert {:ok, level_99} =
             ProgressionHandler.gain_exp(state, required + 50, roll: fn min, _max -> min end)

    assert level_99.level == 99
    assert level_99.exp == 0
    assert Persistence.load_for_character(character.id).exp == 0

    Process.put(:rolled, false)

    assert {:ok, unchanged} =
             ProgressionHandler.gain_exp(level_99, 1_000,
               roll: fn _min, _max ->
                 Process.put(:rolled, true)
                 0
               end
             )

    refute Process.get(:rolled)
    assert unchanged == level_99
    assert Persistence.load_for_character(character.id).exp == 0
  end

  test "a level 99 state with stale EXP persists zero without rolling", %{character: character} do
    row = insert_homunculus(character.id, %{level: 99, exp: 77})
    Process.put(:rolled, false)

    assert {:ok, cleared} =
             ProgressionHandler.gain_exp(state(row), 0,
               roll: fn _min, _max ->
                 Process.put(:rolled, true)
                 0
               end
             )

    refute Process.get(:rolled)
    assert cleared.exp == 0
    assert Persistence.load_for_character(character.id).exp == 0
  end

  test "a semantic-save failure returns error without advancing DB or caller state", %{
    character: character
  } do
    row = insert_homunculus(character.id, %{level: 1, exp: 0})
    original = state(row)
    {:ok, required} = ExpTable.exp_for(1)

    stub(Repo, :update, fn %Ecto.Changeset{data: %Homunculus{}} = changeset ->
      {:error, Ecto.Changeset.add_error(changeset, :base, "injected failure")}
    end)

    assert {:error, {:persistence, %Ecto.Changeset{}}} =
             ProgressionHandler.gain_exp(original, required, roll: fn min, _max -> min end)

    assert original == state(row)
    reloaded = Persistence.load_for_character(character.id)
    assert reloaded.level == 1
    assert reloaded.exp == 0
    assert reloaded.max_hp == row.max_hp
  end

  test "skill learning enforces tree gates and atomically adds a manual AI row", %{
    character: character
  } do
    row =
      insert_homunculus(character.id, %{
        skill_points: 2,
        learned_skills: %{"8001" => 2},
        ai_config: Config.default() |> Config.encode()
      })

    state = %{state(row) | learned_skills: %{8_001 => 2}, ai_config: Config.default()}

    assert {:error, :prerequisites} = ProgressionHandler.learn_skill(state, 8_002)
    assert Persistence.load_for_character(character.id).skill_points == 2

    state = %{state | learned_skills: %{8_001 => 3}}
    assert {:ok, learned} = ProgressionHandler.learn_skill(state, 8_002)
    assert learned.skill_points == 1
    assert learned.learned_skills[8_002] == 1
    assert learned.ai_config.skills[8_002].mode == :manual
    assert learned.ai_config.skills[8_002].priority == 50

    reloaded = Persistence.load_for_character(character.id)
    assert reloaded.skill_points == 1
    assert reloaded.learned_skills == %{"8001" => 3, "8002" => 1}
    assert Enum.find(reloaded.ai_config["skills"], &(&1["skill_id"] == 8_002))["mode"] == "manual"
  end

  test "rank increases preserve an existing configured AI row", %{character: character} do
    configured_row = %{
      mode: :auto,
      priority: 17,
      self_hp_threshold: 63,
      owner_hp_threshold: nil,
      target_hp_range: nil
    }

    config = %{Config.default() | skills: %{8_001 => configured_row}}

    row =
      insert_homunculus(character.id, %{
        skill_points: 1,
        learned_skills: %{"8001" => 1},
        ai_config: Config.encode(config)
      })

    original = %{state(row) | skill_points: 1, learned_skills: %{8_001 => 1}, ai_config: config}
    assert {:ok, learned} = ProgressionHandler.learn_skill(original, 8_001)
    assert learned.ai_config.skills[8_001] == configured_row

    reloaded = Persistence.load_for_character(character.id)
    expected_row = Enum.find(Config.encode(config)["skills"], &(&1["skill_id"] == 8_001))
    persisted_row = Enum.find(reloaded.ai_config["skills"], &(&1["skill_id"] == 8_001))
    assert persisted_row == expected_row

    specs = [%{id: 8_001, target: :self, allowed_thresholds: [:self_hp]}]
    assert {:ok, decoded} = Config.decode(reloaded.ai_config, specs)
    assert decoded.skills[8_001] == configured_row
  end

  test "skill learning rejects species, points, max rank, level, form, and intimacy gates", %{
    character: character
  } do
    row = insert_homunculus(character.id)
    original = %{state(row) | skill_points: 1, ai_config: Config.default()}

    assert {:error, :wrong_species} = ProgressionHandler.learn_skill(original, 8_005)

    assert {:error, :skill_points} =
             ProgressionHandler.learn_skill(%{original | skill_points: 0}, 8_001)

    assert {:error, :max_rank} =
             ProgressionHandler.learn_skill(%{original | learned_skills: %{8_001 => 5}}, 8_001)

    assert {:error, :form} = ProgressionHandler.learn_skill(original, 8_004)

    evolved = %{original | class_id: 6_009, intimacy_hundredths: 90_999}
    assert {:error, :intimacy} = ProgressionHandler.learn_skill(evolved, 8_004)

    required_level_entry = %{
      class_id: 6_001,
      skill_id: 8_001,
      max_level: 5,
      required_level: 2,
      required_intimacy: 0,
      form: :any,
      requires: []
    }

    assert {:error, :level} =
             ProgressionHandler.validate_learning(original, required_level_entry)
  end

  test "evolution validates eligibility, rolls once, preserves progression, and survives reload",
       %{
         character: character
       } do
    row =
      insert_homunculus(character.id, %{
        level: 42,
        exp: 123,
        skill_points: 4,
        learned_skills: %{"8001" => 3},
        intimacy_hundredths: 91_100,
        hp: 25,
        sp: 10
      })

    original = %{state(row) | learned_skills: %{8_001 => 3}, ai_config: Config.default()}
    Process.put(:evolution_rolls, 0)

    assert {:ok, evolved} =
             ProgressionHandler.evolve(original,
               roll: fn min, _max ->
                 Process.put(:evolution_rolls, Process.get(:evolution_rolls) + 1)
                 min
               end
             )

    assert Process.get(:evolution_rolls) == 8
    assert evolved.class_id == 6_009
    assert evolved.size == :medium
    assert evolved.race == :demi_human
    assert evolved.element == {:neutral, 1}
    assert evolved.attack_delay_ms == 623
    assert evolved.intimacy_hundredths == 1_000
    assert evolved.level == 42
    assert evolved.exp == 123
    assert evolved.skill_points == 4
    assert evolved.learned_skills == %{8_001 => 3}
    assert evolved.max_hp == original.max_hp + 800
    assert evolved.max_sp == original.max_sp + 220
    assert evolved.str == original.str + 10
    assert evolved.agi == original.agi + 10
    assert evolved.vit == original.vit + 20
    assert evolved.int == original.int + 30
    assert evolved.dex == original.dex + 20
    assert evolved.luk == original.luk + 10

    preserved_fields = [
      :id,
      :owner_character_id,
      :owner_session_pid,
      :name,
      :rename_available,
      :lifecycle,
      :level,
      :exp,
      :skill_points,
      :hp,
      :sp,
      :hunger,
      :active_remaining_ms,
      :learned_skills,
      :cooldowns,
      :ai_config,
      :world_gid,
      :map_name,
      :x,
      :y,
      :dir,
      :action_state,
      :movement_state,
      :target,
      :casting,
      :attack_range
    ]

    assert Map.take(evolved, preserved_fields) == Map.take(original, preserved_fields)

    attrs = ProgressionHandler.persistence_attrs(evolved)

    assert Map.keys(attrs) |> MapSet.new() ==
             MapSet.new([
               :class_id,
               :name,
               :rename_available,
               :lifecycle,
               :level,
               :exp,
               :skill_points,
               :hp,
               :max_hp,
               :sp,
               :max_sp,
               :str,
               :agi,
               :vit,
               :int,
               :dex,
               :luk,
               :hunger,
               :intimacy_hundredths,
               :active_remaining_ms,
               :learned_skills,
               :cooldowns,
               :ai_config
             ])

    assert attrs.lifecycle == "active"
    assert attrs.ai_config == Config.encode(evolved.ai_config)
    refute Map.has_key?(attrs, :world_gid)
    refute Map.has_key?(attrs, :map_name)
    refute Map.has_key?(attrs, :owner_session_pid)
    assert {:ok, _persisted} = Persistence.save_semantic(row, attrs)

    reloaded = Persistence.load_for_character(character.id)
    assert reloaded.class_id == evolved.class_id
    assert reloaded.max_hp == evolved.max_hp
    assert reloaded.max_sp == evolved.max_sp
    assert reloaded.str == evolved.str
    assert reloaded.intimacy_hundredths == 1_000
  end

  test "evolution rejects inactive, dead, non-Loyal, and already evolved states", %{
    character: character
  } do
    row = insert_homunculus(character.id, %{intimacy_hundredths: 91_100})
    original = state(row)

    assert {:error, :invalid_lifecycle} =
             ProgressionHandler.evolve(%{original | lifecycle: :rested})

    assert {:error, :not_living} = ProgressionHandler.evolve(%{original | hp: 0})

    assert {:error, :intimacy} =
             ProgressionHandler.evolve(%{original | intimacy_hundredths: 91_099})

    assert {:error, :already_evolved} = ProgressionHandler.evolve(%{original | class_id: 6_009})
  end

  defp insert_homunculus(character_id, attrs \\ %{}) do
    defaults = %{
      character_id: character_id,
      class_id: 6_001,
      name: "Lif",
      lifecycle: "active",
      level: 1,
      exp: 0,
      skill_points: 0,
      hp: 100,
      max_hp: 100,
      sp: 50,
      max_sp: 50,
      str: 10,
      agi: 10,
      vit: 10,
      int: 10,
      dex: 10,
      luk: 10,
      intimacy_hundredths: 2_100,
      learned_skills: %{},
      ai_config: Config.default() |> Config.encode()
    }

    {:ok, homunculus} =
      %Homunculus{}
      |> Homunculus.changeset(Map.merge(defaults, attrs))
      |> Repo.insert()

    homunculus
  end

  defp state(row) do
    %HomunculusState{
      id: row.id,
      owner_character_id: row.character_id,
      class_id: row.class_id,
      name: row.name,
      lifecycle: String.to_existing_atom(row.lifecycle),
      level: row.level,
      exp: row.exp,
      skill_points: row.skill_points,
      hp: row.hp,
      max_hp: row.max_hp,
      sp: row.sp,
      max_sp: row.max_sp,
      str: row.str,
      agi: row.agi,
      vit: row.vit,
      int: row.int,
      dex: row.dex,
      luk: row.luk,
      intimacy_hundredths: row.intimacy_hundredths,
      learned_skills: row.learned_skills,
      ai_config: Config.default(),
      world_gid: nil,
      map_name: "progression_test",
      x: 10,
      y: 10,
      action_state: :idle,
      movement_state: :standing,
      race: :demi_human,
      element: {:neutral, 1},
      size: :small,
      attack_delay_ms: 700
    }
  end
end
