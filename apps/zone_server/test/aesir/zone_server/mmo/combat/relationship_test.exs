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

  defp player(id), do: Combatant.new!(%{unit_type: :player, unit_id: id})

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
