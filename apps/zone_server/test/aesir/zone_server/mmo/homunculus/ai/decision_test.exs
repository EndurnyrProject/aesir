defmodule Aesir.ZoneServer.Mmo.Homunculus.Ai.DecisionTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Mmo.Homunculus.Ai.Config
  alias Aesir.ZoneServer.Mmo.Homunculus.Ai.Decision

  @skill_specs [
    %{id: 8_001, target: :self, allowed_thresholds: [:self_hp]},
    %{id: 8_002, target: :owner, allowed_thresholds: MapSet.new([:owner_hp])},
    %{id: 8_003, target: :enemy, allowed_thresholds: [:target_hp]}
  ]

  test "uses the approved defaults and manual rows" do
    assert %Config{
             stance: :assist,
             leash_distance: 10,
             join_owner_target: true,
             retaliate: true,
             avoid_bosses: true,
             allowed_mob_class_ids: [],
             denied_mob_class_ids: [],
             auto_feed: false,
             auto_feed_threshold: 11,
             auto_cast_sp_reserve_percent: 20,
             skills: %{8_001 => %{mode: :manual, priority: 50}}
           } = Config.default([hd(@skill_specs)])
  end

  test "round trips a complete replacement through a stable persisted map" do
    assert {:ok, config} = Config.decode(config_map(), @skill_specs)
    encoded = Config.encode(config)

    assert encoded["allowed_mob_class_ids"] == [1_001, 1_002]
    assert Enum.map(encoded["skills"], & &1["skill_id"]) == [8_001, 8_002, 8_003]

    assert %{"target_hp_range" => %{"min_percent" => 10, "max_percent" => 90}} =
             Enum.find(encoded["skills"], &(&1["skill_id"] == 8_003))

    assert {:ok, ^config} = Config.decode(encoded, @skill_specs)
  end

  test "rejects every out-of-range global and skill value" do
    for {path, value} <- [
          {["leash_distance"], 1},
          {["leash_distance"], 15},
          {["auto_feed_threshold"], 0},
          {["auto_feed_threshold"], 76},
          {["auto_cast_sp_reserve_percent"], -1},
          {["auto_cast_sp_reserve_percent"], 101},
          {["skills", Access.at(0), "priority"], 0},
          {["skills", Access.at(0), "self_hp_threshold"], 0},
          {["skills", Access.at(0), "target_hp_range", "max_percent"], 101}
        ] do
      assert {:error, :invalid_ai_config} =
               Config.decode(put_in(config_map(), path, value), @skill_specs)
    end
  end

  test "rejects whole replacements with unknown, duplicate, missing, or inapplicable rows" do
    assert {:error, :invalid_ai_config} =
             Config.decode(Map.put(config_map(), "claim_safety", false), @skill_specs)

    duplicate = put_in(config_map(), ["skills"], List.duplicate(hd(config_map()["skills"]), 3))
    assert {:error, :invalid_ai_config} = Config.decode(duplicate, @skill_specs)

    assert {:error, :invalid_ai_config} =
             Config.decode(
               put_in(config_map(), ["skills"], Enum.take(config_map()["skills"], 2)),
               @skill_specs
             )

    inapplicable = put_in(config_map(), ["skills", Access.at(0), "owner_hp_threshold"], 50)
    assert {:error, :invalid_ai_config} = Config.decode(inapplicable, @skill_specs)

    duplicate_class = put_in(config_map(), ["allowed_mob_class_ids"], [1_001, 1_001])
    assert {:error, :invalid_ai_config} = Config.decode(duplicate_class, @skill_specs)
  end

  test "returns idle before every other action for inactive, dead, or busy companions" do
    assert :idle = Decision.next(owner(), %{homunculus() | busy?: true, hunger: 1}, [candidate()])
    assert :idle = Decision.next(owner(), %{homunculus() | lifecycle: :rested}, [candidate()])
    assert :idle = Decision.next(owner(), %{homunculus() | alive?: false}, [candidate()])
  end

  test "feeds before combat and falls through when food is absent" do
    homunculus =
      %{
        homunculus()
        | ai_config: config(auto_feed: true),
          hunger: 11,
          food_available?: true,
          target: candidate().ref
      }

    assert :feed = Decision.next(owner(), homunculus, [candidate()])

    assert {:attack, {:mob, 9}} =
             Decision.next(owner(), %{homunculus | food_available?: false}, [candidate()])
  end

  test "recovers after three seconds of separation and follows outside the leash" do
    assert {:recover, {0, 0}} =
             Decision.next(owner(), %{homunculus() | separated_ms: 3_000, position: {20, 0}}, [])

    assert {:follow, {:player, 1}} =
             Decision.next(owner(), %{homunculus() | position: {11, 0}}, [])
  end

  test "standby blocks target selection while passive retains explicit targets" do
    assert :idle =
             Decision.next(owner(), %{homunculus() | standby?: true, target: candidate().ref}, [
               candidate()
             ])

    config = config(stance: :passive)

    assert {:attack, {:mob, 9}} =
             Decision.next(
               owner(),
               %{homunculus() | ai_config: config, target: candidate().ref},
               [candidate()]
             )

    assert :idle = Decision.next(owner(), %{homunculus() | ai_config: config}, [candidate()])
  end

  test "accepts only unclaimed or exact-owner claim roots" do
    for {claim_root, expected} <- [
          {{:player, 1}, {:attack, {:mob, 9}}},
          {{:player, 2}, :idle},
          {:missing, :idle},
          {{:mob, 9}, :idle}
        ] do
      candidate =
        case claim_root do
          :missing -> Map.delete(candidate(), :claim_root)
          claim_root -> candidate(claim_root: claim_root)
        end

      assert expected == Decision.next(owner(), %{homunculus() | target: {:mob, 9}}, [candidate])
    end
  end

  test "filters claim-unsafe, denied, boss, and dead candidates before target policy" do
    config =
      config(stance: :aggressive, allowed_mob_class_ids: [1_001], denied_mob_class_ids: [1_001])

    assert :idle =
             Decision.next(owner(), %{homunculus() | ai_config: config}, [
               candidate(class_id: 1_001)
             ])

    unsafe = candidate(claim_root: {:player, 2})

    assert :idle =
             Decision.next(owner(), %{homunculus() | ai_config: config(stance: :aggressive)}, [
               unsafe
             ])

    boss = candidate(boss?: true)

    assert :idle =
             Decision.next(owner(), %{homunculus() | ai_config: config(stance: :aggressive)}, [
               boss
             ])

    dead = candidate(hp: 0)

    assert :idle =
             Decision.next(owner(), %{homunculus() | ai_config: config(stance: :aggressive)}, [
               dead
             ])
  end

  test "selects owner target, retaliation, then nearest deterministic aggressive candidate" do
    candidate = candidate()
    owner_target = owner(target: candidate.ref)
    assert {:attack, {:mob, 9}} = Decision.next(owner_target, homunculus(), [candidate])

    assert {:attack, {:mob, 9}} =
             Decision.next(owner(), %{homunculus() | retaliation_target: candidate.ref}, [
               candidate
             ])

    nearest = candidate(position: {2, 0})
    tied = candidate(ref: {:mob, 8}, position: {0, 2})
    aggressive = %{homunculus() | ai_config: config(stance: :aggressive)}
    assert {:chase, {:mob, 8}} = Decision.next(owner(), aggressive, [nearest, tied])
  end

  test "orders retained, owner, and retaliation targets deterministically" do
    current = candidate(ref: {:mob, 9})
    owner_target = candidate(ref: {:mob, 8})
    retaliation = candidate(ref: {:mob, 7})

    assert {:attack, {:mob, 9}} =
             Decision.next(
               owner(target: owner_target.ref),
               %{homunculus() | target: current.ref, retaliation_target: retaliation.ref},
               [current, owner_target, retaliation]
             )

    assert {:attack, {:mob, 8}} =
             Decision.next(
               owner(target: owner_target.ref),
               %{homunculus() | retaliation_target: retaliation.ref},
               [owner_target, retaliation]
             )

    assert {:attack, {:mob, 7}} =
             Decision.next(
               owner(target: {:mob, 99}),
               %{homunculus() | retaliation_target: retaliation.ref},
               [retaliation]
             )

    assert {:attack, {:mob, 7}} =
             Decision.next(
               owner(alive?: false, target: owner_target.ref),
               %{homunculus() | retaliation_target: retaliation.ref},
               [owner_target, retaliation]
             )
  end

  test "casts eligible auto skills by priority with conjunctive thresholds and exact reserve" do
    config =
      config(
        skills: %{
          8_001 => %{
            mode: :auto,
            priority: 50,
            self_hp_threshold: 50,
            owner_hp_threshold: nil,
            target_hp_range: nil
          },
          8_002 => %{
            mode: :auto,
            priority: 100,
            self_hp_threshold: nil,
            owner_hp_threshold: 50,
            target_hp_range: nil
          },
          8_003 => %{
            mode: :auto,
            priority: 100,
            self_hp_threshold: nil,
            owner_hp_threshold: nil,
            target_hp_range: %{min_percent: 10, max_percent: 90}
          }
        }
      )

    homunculus = %{
      homunculus()
      | ai_config: config,
        hp: 40,
        skills: skills(),
        target: candidate().ref
    }

    assert {:cast, 8_003, 3, {:mob, 9}} =
             Decision.next(owner(hp: 100), homunculus, [candidate(hp: 50)])

    reserve = %{homunculus | sp: 39, max_sp: 100, skills: [%{hd(skills()) | sp_cost: 20}]}
    assert {:attack, {:mob, 9}} = Decision.next(owner(hp: 100), reserve, [candidate()])
  end

  test "requires every configured self and owner threshold" do
    config = combined_config()
    skill = %{id: 8_004, level: 1, target: :self, sp_cost: 0, cooldown_ready?: true}

    for {homunculus_hp, owner_hp, expected} <- [
          {50, 50, {:cast, 8_004, 1, {:homunculus, 2}}},
          {51, 50, :idle},
          {50, 51, :idle}
        ] do
      homunculus = %{homunculus() | ai_config: config, hp: homunculus_hp, skills: [skill]}
      assert expected == Decision.next(owner(hp: owner_hp), homunculus, [])
    end
  end

  test "uses inclusive target HP and SP reserve boundaries" do
    target_config =
      config(
        skills: %{
          8_003 => %{
            mode: :auto,
            priority: 50,
            self_hp_threshold: nil,
            owner_hp_threshold: nil,
            target_hp_range: %{min_percent: 30, max_percent: 70}
          }
        }
      )

    skill = %{id: 8_003, level: 1, target: :enemy, sp_cost: 0, cooldown_ready?: true}

    for {hp, expected} <- [
          {30, {:cast, 8_003, 1, {:mob, 9}}},
          {70, {:cast, 8_003, 1, {:mob, 9}}},
          {29, {:attack, {:mob, 9}}},
          {71, {:attack, {:mob, 9}}}
        ] do
      target = candidate(hp: hp)
      homunculus = %{homunculus() | ai_config: target_config, target: target.ref, skills: [skill]}

      assert expected == Decision.next(owner(), homunculus, [target])
    end

    reserve_config =
      config(
        auto_cast_sp_reserve_percent: 20,
        skills: %{
          8_001 => %{
            mode: :auto,
            priority: 50,
            self_hp_threshold: nil,
            owner_hp_threshold: nil,
            target_hp_range: nil
          }
        }
      )

    reserve_skill = %{id: 8_001, level: 1, target: :self, sp_cost: 20, cooldown_ready?: true}

    for {sp, expected} <- [{40, {:cast, 8_001, 1, {:homunculus, 2}}}, {39, :idle}] do
      assert expected ==
               Decision.next(
                 owner(),
                 %{homunculus() | ai_config: reserve_config, sp: sp, skills: [reserve_skill]},
                 []
               )
    end
  end

  test "attacks in range, chases outside range, and idles without a selected target" do
    assert {:attack, {:mob, 9}} =
             Decision.next(owner(), %{homunculus() | target: candidate().ref}, [candidate()])

    assert {:chase, {:mob, 9}} =
             Decision.next(owner(), %{homunculus() | target: candidate().ref}, [
               candidate(position: {2, 0})
             ])

    assert :idle = Decision.next(owner(), homunculus(), [])
  end

  defp config(overrides \\ []) do
    Config.default()
    |> Map.from_struct()
    |> Map.merge(Map.new(overrides))
    |> then(&struct!(Config, &1))
  end

  defp combined_config do
    map =
      Config.default()
      |> Config.encode()
      |> Map.put("skills", [
        %{
          "skill_id" => 8_004,
          "mode" => "auto",
          "priority" => 50,
          "self_hp_threshold" => 50,
          "owner_hp_threshold" => 50,
          "target_hp_range" => nil
        }
      ])

    assert {:ok, config} =
             Config.decode(map, [
               %{id: 8_004, target: :self, allowed_thresholds: [:self_hp, :owner_hp]}
             ])

    config
  end

  defp config_map do
    %{
      "stance" => "aggressive",
      "leash_distance" => 14,
      "join_owner_target" => true,
      "retaliate" => true,
      "avoid_bosses" => true,
      "allowed_mob_class_ids" => [1_002, 1_001],
      "denied_mob_class_ids" => [1_003],
      "auto_feed" => true,
      "auto_feed_threshold" => 75,
      "auto_cast_sp_reserve_percent" => 100,
      "skills" => [
        %{
          "skill_id" => 8_003,
          "mode" => "auto",
          "priority" => 100,
          "self_hp_threshold" => nil,
          "owner_hp_threshold" => nil,
          "target_hp_range" => %{"min_percent" => 10, "max_percent" => 90}
        },
        %{
          "skill_id" => 8_001,
          "mode" => "auto",
          "priority" => 50,
          "self_hp_threshold" => 25,
          "owner_hp_threshold" => nil,
          "target_hp_range" => nil
        },
        %{
          "skill_id" => 8_002,
          "mode" => "manual",
          "priority" => 50,
          "self_hp_threshold" => nil,
          "owner_hp_threshold" => nil,
          "target_hp_range" => nil
        }
      ]
    }
  end

  defp owner(overrides \\ []) do
    Map.merge(
      %{ref: {:player, 1}, alive?: true, position: {0, 0}, hp: 100, max_hp: 100, target: nil},
      Map.new(overrides)
    )
  end

  defp homunculus do
    %{
      ref: {:homunculus, 2},
      lifecycle: :active,
      alive?: true,
      busy?: false,
      standby?: false,
      position: {0, 0},
      separated_ms: nil,
      hp: 100,
      max_hp: 100,
      sp: 100,
      max_sp: 100,
      hunger: 50,
      food_available?: false,
      target: nil,
      retaliation_target: nil,
      attack_range: 1,
      ai_config: config(),
      skills: []
    }
  end

  defp candidate(overrides \\ []) do
    Map.merge(
      %{
        ref: {:mob, 9},
        class_id: 1_001,
        boss?: false,
        position: {1, 0},
        hp: 100,
        max_hp: 100,
        claim_root: nil
      },
      Map.new(overrides)
    )
  end

  defp skills do
    [
      %{id: 8_001, level: 1, target: :self, sp_cost: 20, cooldown_ready?: true},
      %{id: 8_002, level: 2, target: :owner, sp_cost: 20, cooldown_ready?: true},
      %{id: 8_003, level: 3, target: :enemy, sp_cost: 20, cooldown_ready?: true}
    ]
  end
end
