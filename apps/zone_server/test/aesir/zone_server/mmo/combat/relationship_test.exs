defmodule Aesir.ZoneServer.Mmo.Combat.RelationshipTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Mmo.Combat.Combatant
  alias Aesir.ZoneServer.Mmo.Combat.Relationship
  alias Aesir.ZoneServer.Mmo.Skill.Targeting
  alias Aesir.ZoneServer.Unit.Ref

  test "validates canonical typed unit references" do
    assert {:ok, {:homunculus, 42}} = Ref.new(:homunculus, 42)
    assert {:error, :invalid_unit_type} = Ref.new(:invalid, 42)
    assert {:error, :invalid_unit_id} = Ref.new(:homunculus, 0)

    for ref <- [nil, :homunculus, {}, {:invalid, 42}, {:homunculus, 0}, {:homunculus, "42"}] do
      refute Ref.valid?(ref)
    end

    assert Ref.equal?({:homunculus, 42}, {:homunculus, 42})

    for {left, right} <- [
          {nil, nil},
          {:homunculus, nil},
          {{:homunculus, 0}, {:homunculus, 0}},
          {{:invalid, 42}, {:invalid, 42}}
        ] do
      refute Ref.equal?(left, right)
    end
  end

  test "rejects invalid Homunculus ids and relationship roots" do
    for unit_id <- [nil, 0, -1, "42"] do
      assert {:error, "Invalid combatant relationship roots"} =
               Combatant.new(%{
                 unit_type: :homunculus,
                 unit_id: unit_id,
                 social_root: {:player, 10},
                 reward_root: {:player, 10}
               })
    end

    for {social_root, reward_root} <- [
          {nil, {:player, 10}},
          {{:player, 10}, nil},
          {{:player, 10}, {:player, 20}},
          {{:player, 0}, {:player, 10}},
          {{:player, "10"}, {:player, 10}},
          {{:mob, 10}, {:player, 10}}
        ] do
      assert {:error, "Invalid combatant relationship roots"} =
               Combatant.new(%{
                 unit_type: :homunculus,
                 unit_id: 42,
                 social_root: social_root,
                 reward_root: reward_root
               })
    end
  end

  test "owner and companion are neutral while player sides are hostile to mobs" do
    owner = player(10)
    companion = homunculus(100, 10)
    foreign_player = player(20)
    foreign_companion = homunculus(200, 20)
    mob = mob(300)

    refute Relationship.enemy?(owner, companion)
    refute Relationship.enemy?(companion, owner)
    refute Relationship.enemy?(foreign_player, companion)
    refute Relationship.enemy?(companion, foreign_player)
    refute Relationship.enemy?(companion, foreign_companion)
    assert Relationship.enemy?(companion, mob)
    assert Relationship.enemy?(mob, companion)
    refute Targeting.enemy?(owner, companion)
    assert {:error, :invalid_target} = Targeting.validate_enemy(owner, companion)
    assert {:error, :invalid_target} = Targeting.validate_enemy(companion, owner)
    assert {:error, :invalid_target} = Targeting.validate_enemy(foreign_player, companion)
    assert {:error, :invalid_target} = Targeting.validate_enemy(companion, foreign_player)
    assert :ok = Targeting.validate_enemy(companion, mob)
    assert :ok = Targeting.validate_enemy(mob, companion)
  end

  test "only the exact owner may directly support a companion" do
    owner = player(10)
    companion = homunculus(100, 10)
    foreign_player = player(20)

    assert Relationship.direct_support?(owner, companion)
    refute Relationship.direct_support?(foreign_player, companion)
    assert Targeting.direct_support?(owner, companion)
  end

  test "ground selection is determined by its explicit typed selector" do
    companion = homunculus(100, 10)
    target_ref = {:homunculus, 100}

    owner_only = fn
      {:homunculus, 100} -> true
      _target -> false
    end

    assert Relationship.ground_selected?(owner_only, target_ref)
    refute Relationship.ground_selected?(owner_only, {:homunculus, 101})
    assert Targeting.ground_selected?(owner_only, target_ref)
    assert Ref.equal?(target_ref, {:homunculus, companion.unit_id})
  end

  test "player and ordinary mob roots preserve current ownership semantics" do
    player = player(10)
    owned_mob = mob(300)

    assert Relationship.social_root(player) == {:player, 10}
    assert Relationship.reward_root(player) == {:player, 10}
    assert Relationship.social_root(owned_mob) == {:mob, 300}
    assert Relationship.reward_root(owned_mob) == nil
    assert Relationship.enemy?(owned_mob, player)
  end

  test "enemy?/2 is the :off PvE entry across the whole matrix" do
    pairs = [
      {player(10), player(10)},
      {player(10), player(20)},
      {player(10), homunculus(100, 10)},
      {homunculus(100, 10), homunculus(200, 20)},
      {homunculus(100, 10), mob(300)},
      {mob(300), player(10)},
      {mob(300), mob(301)},
      {player(10, party_id: 7), player(20, party_id: 7)},
      {player(10, guild_id: 3), player(20, guild_id: 3)}
    ]

    for {attacker, target} <- pairs do
      assert Relationship.enemy?(attacker, target) ==
               Relationship.enemy?(attacker, target, :off)
    end
  end

  test "versus matrix: same social root is never an enemy in any context" do
    owner = player(10)
    companion = homunculus(100, 10)

    for versus <-
          [
            :off,
            :gvg,
            {:pvp, false, false},
            {:pvp, true, false},
            {:pvp, false, true},
            {:pvp, true, true}
          ] do
      refute Relationship.enemy?(player(10), player(10), versus)
      refute Relationship.enemy?(owner, companion, versus)
      refute Relationship.enemy?(companion, owner, versus)
    end
  end

  test "versus matrix: same nonzero party protects under gvg and pvp unless noparty" do
    attacker = player(10, party_id: 7)
    target = player(20, party_id: 7)

    refute Relationship.enemy?(attacker, target, :gvg)
    refute Relationship.enemy?(attacker, target, {:pvp, false, false})
    refute Relationship.enemy?(attacker, target, {:pvp, false, true})
    assert Relationship.enemy?(attacker, target, {:pvp, true, false})
    assert Relationship.enemy?(attacker, target, {:pvp, true, true})
    refute Relationship.enemy?(attacker, target, :off)
  end

  test "versus matrix: same nonzero guild protects under gvg and pvp unless noguild" do
    attacker = player(10, guild_id: 3)
    target = player(20, guild_id: 3)

    refute Relationship.enemy?(attacker, target, :gvg)
    refute Relationship.enemy?(attacker, target, {:pvp, false, false})
    refute Relationship.enemy?(attacker, target, {:pvp, true, false})
    assert Relationship.enemy?(attacker, target, {:pvp, false, true})
    assert Relationship.enemy?(attacker, target, {:pvp, true, true})
    refute Relationship.enemy?(attacker, target, :off)
  end

  test "versus matrix: gvg protection is unconditional while pvp overrides apply per flag" do
    same_party = {player(10, party_id: 7), player(20, party_id: 7)}
    same_guild = {player(10, guild_id: 3), player(20, guild_id: 3)}

    for {attacker, target} <- [same_party, same_guild] do
      refute Relationship.enemy?(attacker, target, :gvg)
    end

    {party_a, party_b} = same_party
    assert Relationship.enemy?(party_a, party_b, {:pvp, true, false})

    {guild_a, guild_b} = same_guild
    assert Relationship.enemy?(guild_a, guild_b, {:pvp, false, true})

    {a, b} = {player(10, party_id: 7, guild_id: 3), player(20, party_id: 7, guild_id: 3)}
    assert Relationship.enemy?(a, b, {:pvp, true, true})
    {c, d} = {player(10, party_id: 7), player(20, party_id: 7, guild_id: 3)}
    refute Relationship.enemy?(c, d, {:pvp, false, true})
  end

  test "versus matrix: zero party/guild ids never protect" do
    attacker = player(10)
    target = player(20)

    assert Relationship.enemy?(attacker, target, :gvg)
    assert Relationship.enemy?(attacker, target, {:pvp, false, false})
    assert Relationship.enemy?(attacker, target, {:pvp, true, false})

    one_sided_party = {player(10, party_id: 7), player(20)}
    one_sided_guild = {player(10, guild_id: 3), player(20)}

    for {a, b} <- [one_sided_party, one_sided_guild] do
      assert Relationship.enemy?(a, b, :gvg)
      assert Relationship.enemy?(a, b, {:pvp, false, false})
    end
  end

  test "versus matrix: mob and homunculus branches are identical to :off" do
    player_side = player(10)
    companion = homunculus(100, 10)
    mob = mob(300)
    other_mob = mob(301)

    for versus <- [:gvg, {:pvp, false, false}, {:pvp, true, true}] do
      for {attacker, target} <- [
            {mob, player_side},
            {player_side, mob},
            {companion, mob},
            {mob, companion},
            {mob, other_mob}
          ] do
        assert Relationship.enemy?(attacker, target, versus) ==
                 Relationship.enemy?(attacker, target, :off)
      end

      refute Relationship.enemy?(mob, other_mob, versus)
    end
  end

  defp player(id, overrides \\ []) do
    Combatant.new!(Map.merge(%{unit_type: :player, unit_id: id}, Map.new(overrides)))
  end

  defp mob(id), do: Combatant.new!(%{unit_type: :mob, unit_id: id})

  defp homunculus(id, owner_id) do
    Combatant.new!(%{
      unit_type: :homunculus,
      unit_id: id,
      social_root: {:player, owner_id},
      reward_root: {:player, owner_id}
    })
  end
end
