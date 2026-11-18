defmodule Aesir.ZoneServer.Mmo.Homunculus.Ai.DecisionTest do
  use ExUnit.Case, async: true

  import Aesir.ZoneServer.Factory

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
    target = build(:ai_candidate_snapshot)
    ready = build(:ai_homunculus_snapshot, target: target.ref)
    assert {:attack, target.ref} == Decision.next(build(:ai_owner_snapshot), ready, [target])

    for not_ready <- [
          %{ready | busy?: true},
          %{ready | lifecycle: :rested},
          %{ready | alive?: false}
        ] do
      assert :idle = Decision.next(build(:ai_owner_snapshot), not_ready, [target])
    end
  end

  test "feeds before combat and falls through when food is absent" do
    target = build(:ai_candidate_snapshot)

    homunculus =
      build(:ai_homunculus_snapshot,
        ai_config: config(auto_feed: true),
        hunger: 11,
        food_available?: true,
        target: target.ref
      )

    assert :feed = Decision.next(build(:ai_owner_snapshot), homunculus, [target])

    assert {:attack, target.ref} ==
             Decision.next(build(:ai_owner_snapshot), %{homunculus | food_available?: false}, [
               target
             ])
  end

  test "follows the owner outside the leash" do
    owner = build(:ai_owner_snapshot)
    homunculus = build(:ai_homunculus_snapshot, position: {11, 0})

    assert {:follow, owner.ref} == Decision.next(owner, homunculus, [])
  end

  test "standby blocks target selection while passive retains explicit targets" do
    target = build(:ai_candidate_snapshot)
    owner = build(:ai_owner_snapshot)

    assert :idle =
             Decision.next(
               owner,
               build(:ai_homunculus_snapshot, standby?: true, target: target.ref),
               [target]
             )

    config = config(stance: :passive)

    assert {:attack, target.ref} ==
             Decision.next(
               owner,
               build(:ai_homunculus_snapshot, ai_config: config, target: target.ref),
               [target]
             )

    assert :idle =
             Decision.next(owner, build(:ai_homunculus_snapshot, ai_config: config), [target])
  end

  test "accepts only unclaimed or exact-owner claim roots" do
    owner = build(:ai_owner_snapshot)
    other_player = build(:ai_owner_snapshot)

    for {claim_root, attacks?} <- [
          {nil, true},
          {owner.ref, true},
          {other_player.ref, false},
          {{:mob, 1}, false}
        ] do
      candidate = build(:ai_candidate_snapshot, claim_root: claim_root)
      homunculus = build(:ai_homunculus_snapshot, target: candidate.ref)
      expected = if attacks?, do: {:attack, candidate.ref}, else: :idle

      assert expected == Decision.next(owner, homunculus, [candidate])
    end
  end

  test "filters claim-unsafe, denied, boss, and dead candidates before target policy" do
    owner = build(:ai_owner_snapshot)
    other_player = build(:ai_owner_snapshot)

    denied =
      config(stance: :aggressive, allowed_mob_class_ids: [1_001], denied_mob_class_ids: [1_001])

    assert :idle =
             Decision.next(owner, build(:ai_homunculus_snapshot, ai_config: denied), [
               build(:ai_candidate_snapshot, class_id: 1_001)
             ])

    aggressive = build(:ai_homunculus_snapshot, ai_config: config(stance: :aggressive))

    for candidate <- [
          build(:ai_candidate_snapshot, claim_root: other_player.ref),
          build(:ai_candidate_snapshot, boss?: true),
          build(:ai_candidate_snapshot, hp: 0)
        ] do
      assert :idle = Decision.next(owner, aggressive, [candidate])
    end
  end

  test "aggressive stance picks the nearest candidate and breaks distance ties by ref" do
    nearest = build(:ai_candidate_snapshot, ref: {:mob, 9}, position: {2, 0})
    tied = build(:ai_candidate_snapshot, ref: {:mob, 8}, position: {0, 2})
    farther = build(:ai_candidate_snapshot, ref: {:mob, 7}, position: {3, 0})
    aggressive = build(:ai_homunculus_snapshot, ai_config: config(stance: :aggressive))

    assert {:chase, {:mob, 8}} =
             Decision.next(build(:ai_owner_snapshot), aggressive, [farther, nearest, tied])
  end

  test "orders retained, owner, and retaliation targets deterministically" do
    current = build(:ai_candidate_snapshot)
    owner_target = build(:ai_candidate_snapshot)
    retaliation = build(:ai_candidate_snapshot)
    outside = build(:ai_candidate_snapshot)

    assert {:attack, current.ref} ==
             Decision.next(
               build(:ai_owner_snapshot, target: owner_target.ref),
               build(:ai_homunculus_snapshot,
                 target: current.ref,
                 retaliation_target: retaliation.ref
               ),
               [current, owner_target, retaliation]
             )

    assert {:attack, owner_target.ref} ==
             Decision.next(
               build(:ai_owner_snapshot, target: owner_target.ref),
               build(:ai_homunculus_snapshot, retaliation_target: retaliation.ref),
               [owner_target, retaliation]
             )

    assert {:attack, retaliation.ref} ==
             Decision.next(
               build(:ai_owner_snapshot, target: outside.ref),
               build(:ai_homunculus_snapshot, retaliation_target: retaliation.ref),
               [retaliation]
             )

    assert {:attack, retaliation.ref} ==
             Decision.next(
               build(:ai_owner_snapshot, alive?: false, target: owner_target.ref),
               build(:ai_homunculus_snapshot, retaliation_target: retaliation.ref),
               [owner_target, retaliation]
             )
  end

  test "casts the highest-priority eligible auto skill" do
    config =
      config(
        skills: %{
          8_001 => auto_row(priority: 50, self_hp_threshold: 50),
          8_002 => auto_row(priority: 100, owner_hp_threshold: 50),
          8_003 => auto_row(priority: 100, target_hp_range: %{min_percent: 10, max_percent: 90})
        }
      )

    target = build(:ai_candidate_snapshot, hp: 50)

    homunculus =
      build(:ai_homunculus_snapshot,
        ai_config: config,
        hp: 40,
        target: target.ref,
        skills: [
          build(:ai_skill_snapshot, id: 8_001, level: 1, target: :self, sp_cost: 20),
          build(:ai_skill_snapshot, id: 8_002, level: 2, target: :owner, sp_cost: 20),
          build(:ai_skill_snapshot, id: 8_003, level: 3, target: :enemy, sp_cost: 20)
        ]
      )

    assert {:cast, 8_003, 3, target.ref} ==
             Decision.next(build(:ai_owner_snapshot), homunculus, [target])
  end

  test "requires every configured self and owner threshold" do
    config = combined_config()
    skill = build(:ai_skill_snapshot, id: 8_004)

    for {homunculus_hp, owner_hp, casts?} <- [{50, 50, true}, {51, 50, false}, {50, 51, false}] do
      homunculus =
        build(:ai_homunculus_snapshot, ai_config: config, hp: homunculus_hp, skills: [skill])

      expected = if casts?, do: {:cast, 8_004, 1, homunculus.ref}, else: :idle
      assert expected == Decision.next(build(:ai_owner_snapshot, hp: owner_hp), homunculus, [])
    end
  end

  test "uses inclusive target HP and SP reserve boundaries" do
    target_config =
      config(skills: %{8_003 => auto_row(target_hp_range: %{min_percent: 30, max_percent: 70})})

    skill = build(:ai_skill_snapshot, id: 8_003, target: :enemy)

    for {hp, casts?} <- [{30, true}, {70, true}, {29, false}, {71, false}] do
      target = build(:ai_candidate_snapshot, hp: hp)

      homunculus =
        build(:ai_homunculus_snapshot,
          ai_config: target_config,
          target: target.ref,
          skills: [skill]
        )

      expected = if casts?, do: {:cast, 8_003, 1, target.ref}, else: {:attack, target.ref}
      assert expected == Decision.next(build(:ai_owner_snapshot), homunculus, [target])
    end

    reserve_config = config(auto_cast_sp_reserve_percent: 20, skills: %{8_001 => auto_row([])})
    reserve_skill = build(:ai_skill_snapshot, id: 8_001, sp_cost: 20)

    for {sp, casts?} <- [{40, true}, {39, false}] do
      homunculus =
        build(:ai_homunculus_snapshot, ai_config: reserve_config, sp: sp, skills: [reserve_skill])

      expected = if casts?, do: {:cast, 8_001, 1, homunculus.ref}, else: :idle
      assert expected == Decision.next(build(:ai_owner_snapshot), homunculus, [])
    end
  end

  test "attacks in range, chases outside range, and idles without a selected target" do
    owner = build(:ai_owner_snapshot)
    near = build(:ai_candidate_snapshot)
    far = build(:ai_candidate_snapshot, position: {2, 0})

    assert {:attack, near.ref} ==
             Decision.next(owner, build(:ai_homunculus_snapshot, target: near.ref), [near])

    assert {:chase, far.ref} ==
             Decision.next(owner, build(:ai_homunculus_snapshot, target: far.ref), [far])

    assert :idle = Decision.next(owner, build(:ai_homunculus_snapshot), [])
  end

  defp config(overrides), do: struct!(Config.default(), overrides)

  defp auto_row(overrides) do
    Map.merge(
      %{
        mode: :auto,
        priority: 50,
        self_hp_threshold: nil,
        owner_hp_threshold: nil,
        target_hp_range: nil
      },
      Map.new(overrides)
    )
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
end
