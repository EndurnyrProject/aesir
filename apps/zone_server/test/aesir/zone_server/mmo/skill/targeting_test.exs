defmodule Aesir.ZoneServer.Mmo.Skill.TargetingTest do
  use ExUnit.Case, async: false

  alias Aesir.ZoneServer.Map.MapFlags
  alias Aesir.ZoneServer.Mmo.Combat.Combatant
  alias Aesir.ZoneServer.Mmo.Skill.Targeting
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.UnitRegistry

  setup do
    Aesir.TestEtsSetup.setup_ets_tables(%{})
    :ok = MapFlags.reload()
  end

  defp player(id, attrs \\ %{}) do
    Map.merge(
      %{
        character_id: id,
        party_id: 0,
        guild_id: 0,
        action_state: :idle,
        stats: %{current_state: %{hp: 100}}
      },
      attrs
    )
  end

  defp mob(id, attrs \\ %{}) do
    Map.merge(%{instance_id: id, hp: 100, is_dead: false}, attrs)
  end

  defp homunculus(world_gid, owner_id, attrs \\ %{}) do
    Map.merge(
      %{
        owner_character_id: owner_id,
        world_gid: world_gid,
        map_name: "prontera",
        hp: 100,
        action_state: :idle
      },
      attrs
    )
  end

  defp combatant_homunculus(world_gid, owner_id, attrs \\ %{}) do
    Combatant.new!(
      Map.merge(
        %{
          unit_type: :homunculus,
          unit_id: world_gid,
          social_root: {:player, owner_id},
          reward_root: {:player, owner_id},
          map_name: "prontera",
          party_id: 0,
          guild_id: 0
        },
        attrs
      )
    )
  end

  defp register_owner(owner_id, party_id, guild_id) do
    state = %PlayerState{character_id: owner_id, party_id: party_id, guild_id: guild_id}
    :ok = UnitRegistry.register_unit(:player, owner_id, PlayerState, state, self())
  end

  test "a binary map with :pvp set is a versus map" do
    :ok = MapFlags.set_runtime("prontera", :pvp, true)
    assert Targeting.versus_map?("prontera")
  end

  test "a binary map with :gvg set is a versus map" do
    :ok = MapFlags.set_runtime("prontera", :gvg, true)
    assert Targeting.versus_map?("prontera")
  end

  test "a binary map with no versus flag set is not a versus map" do
    refute Targeting.versus_map?("prontera")
  end

  test "a non-binary input is never a versus map" do
    refute Targeting.versus_map?(:prontera)
  end

  test "another player is not a valid target until PvP map modes exist" do
    assert {:error, :invalid_target} = Targeting.validate_enemy(player(1000), player(2000))
  end

  test "self is never an enemy" do
    assert {:error, :invalid_target} = Targeting.validate_enemy(player(1000), player(1000))
  end

  test "members of the same nonzero party are not enemies" do
    assert {:error, :invalid_target} =
             Targeting.validate_enemy(
               player(1000, %{party_id: 10}),
               player(2000, %{party_id: 10})
             )
  end

  test "members of the same nonzero guild are not enemies" do
    assert {:error, :invalid_target} =
             Targeting.validate_enemy(
               player(1000, %{guild_id: 20}),
               player(2000, %{guild_id: 20})
             )
  end

  test "a living mob is an enemy of a player" do
    assert :ok = Targeting.validate_enemy(player(1000), mob(2000))
  end

  test "a mob may still target a living player" do
    assert :ok = Targeting.validate_enemy(mob(1000), player(2000))
  end

  test "a mob is never a valid target for another mob" do
    assert {:error, :invalid_target} = Targeting.validate_enemy(mob(1000), mob(2000))
  end

  test "dead players and mobs are not enemies" do
    assert {:error, :target_dead} =
             Targeting.validate_enemy(player(1000), player(2000, %{action_state: :dead}))

    assert {:error, :target_dead} =
             Targeting.validate_enemy(player(1000), mob(2000, %{hp: 0, is_dead: true}))
  end

  describe "versus context resolution" do
    test "two unrelated players are enemies on a :pvp map" do
      :ok = MapFlags.set_runtime("prontera", :pvp, true)

      assert :ok =
               Targeting.validate_enemy(
                 player(1000, %{map_name: "prontera"}),
                 player(2000, %{map_name: "prontera"})
               )
    end

    test "same-party players are protected on :pvp until :pvp_noparty" do
      :ok = MapFlags.set_runtime("prontera", :pvp, true)

      attacker = player(1000, %{map_name: "prontera", party_id: 10})
      target = player(2000, %{map_name: "prontera", party_id: 10})

      assert {:error, :invalid_target} = Targeting.validate_enemy(attacker, target)

      :ok = MapFlags.set_runtime("prontera", :pvp_noparty, true)
      assert :ok = Targeting.validate_enemy(attacker, target)
    end

    test "same-guild players are protected on :pvp until :pvp_noguild" do
      :ok = MapFlags.set_runtime("prontera", :pvp, true)

      attacker = player(1000, %{map_name: "prontera", guild_id: 20})
      target = player(2000, %{map_name: "prontera", guild_id: 20})

      assert {:error, :invalid_target} = Targeting.validate_enemy(attacker, target)

      :ok = MapFlags.set_runtime("prontera", :pvp_noguild, true)
      assert :ok = Targeting.validate_enemy(attacker, target)
    end

    test ":gvg takes precedence over :pvp and protects same party/guild unconditionally" do
      :ok = MapFlags.set_runtime("prontera", :pvp, true)
      :ok = MapFlags.set_runtime("prontera", :gvg, true)
      :ok = MapFlags.set_runtime("prontera", :pvp_noparty, true)
      :ok = MapFlags.set_runtime("prontera", :pvp_noguild, true)

      assert {:error, :invalid_target} =
               Targeting.validate_enemy(
                 player(1000, %{map_name: "prontera", party_id: 10}),
                 player(2000, %{map_name: "prontera", party_id: 10})
               )

      assert {:error, :invalid_target} =
               Targeting.validate_enemy(
                 player(3000, %{map_name: "prontera", guild_id: 20}),
                 player(4000, %{map_name: "prontera", guild_id: 20})
               )

      assert :ok =
               Targeting.validate_enemy(
                 player(5000, %{map_name: "prontera", guild_id: 20}),
                 player(6000, %{map_name: "prontera", guild_id: 30})
               )
    end

    test "non-binary or missing map names resolve to :off" do
      for map_name <- [nil, :prontera] do
        assert {:error, :invalid_target} =
                 Targeting.validate_enemy(
                   player(1000, %{map_name: map_name}),
                   player(2000, %{map_name: map_name})
                 )
      end
    end
  end

  describe "homunculus owner enrichment" do
    test "a homunculus inherits its owner's party and guild" do
      :ok = MapFlags.set_runtime("prontera", :pvp, true)
      register_owner(900, 10, 20)

      party_ally = player(1000, %{map_name: "prontera", party_id: 10})
      guild_ally = player(1100, %{map_name: "prontera", guild_id: 20})
      stranger = player(2000, %{map_name: "prontera"})
      companion = homunculus(500, 900)

      assert {:error, :invalid_target} = Targeting.validate_enemy(party_ally, companion)
      assert {:error, :invalid_target} = Targeting.validate_enemy(guild_ally, companion)
      assert :ok = Targeting.validate_enemy(stranger, companion)
    end

    test "a homunculus whose owner vanished is treated as unaffiliated" do
      :ok = MapFlags.set_runtime("prontera", :pvp, true)

      party_member = player(1000, %{map_name: "prontera", party_id: 10})
      companion = homunculus(500, 900)

      assert :ok = Targeting.validate_enemy(party_member, companion)
    end

    test "an owner and their own homunculus are never enemies, even on a versus map" do
      :ok = MapFlags.set_runtime("prontera", :pvp, true)

      owner = player(900, %{map_name: "prontera"})
      companion = homunculus(500, 900)

      assert {:error, :invalid_target} = Targeting.validate_enemy(owner, companion)
    end

    test "a production-shaped %Combatant{} homunculus inherits its owner's party and guild" do
      :ok = MapFlags.set_runtime("prontera", :pvp, true)
      register_owner(900, 10, 20)

      party_ally = player(1000, %{map_name: "prontera", party_id: 10})
      guild_ally = player(1100, %{map_name: "prontera", guild_id: 20})
      stranger = player(2000, %{map_name: "prontera"})
      companion = combatant_homunculus(500, 900)

      assert {:error, :invalid_target} = Targeting.validate_enemy(party_ally, companion)
      assert {:error, :invalid_target} = Targeting.validate_enemy(guild_ally, companion)
      assert :ok = Targeting.validate_enemy(stranger, companion)
    end

    test "a production-shaped homunculus whose owner vanished is forced to 0/0 affiliation" do
      :ok = MapFlags.set_runtime("prontera", :pvp, true)

      party_member = player(1000, %{map_name: "prontera", party_id: 10})
      companion = combatant_homunculus(500, 900, %{party_id: 10, guild_id: 20})

      assert :ok = Targeting.validate_enemy(party_member, companion)
    end
  end

  describe "fogged_out?/3" do
    alias Aesir.ZoneServer.Mmo.Skills.Acolyte.AlHeal
    alias Aesir.ZoneServer.Mmo.Skills.Mage.MgColdbolt
    alias Aesir.ZoneServer.Mmo.Skills.Professor.PfSoulchange
    alias Aesir.ZoneServer.Mmo.StatusStorage

    setup do
      :ok = UnitRegistry.register_unit(:mob, 9_901, PlayerState, mob(9_901), self())
      :ok = StatusStorage.apply_status(:mob, 9_901, :sc_fogwall)
      :ok
    end

    test "an attack-type skill aimed at a fog holder fails three times in four" do
      assert Targeting.fogged_out?({:unit, 9_901}, MgColdbolt.definition(), fn 100 -> 75 end)
      refute Targeting.fogged_out?({:unit, 9_901}, MgColdbolt.definition(), fn 100 -> 76 end)
      assert Targeting.fogged_out?({:unit, 9_901}, PfSoulchange.definition(), fn 100 -> 1 end)
    end

    test "support skills and targets outside the fog are unaffected" do
      refute Targeting.fogged_out?({:unit, 9_901}, AlHeal.definition(), fn 100 -> 1 end)
      refute Targeting.fogged_out?({:unit, 4_242}, MgColdbolt.definition(), fn 100 -> 1 end)
      refute Targeting.fogged_out?(:self, MgColdbolt.definition(), fn 100 -> 1 end)
    end
  end

  describe "validate_skill_use/4" do
    import Bitwise

    alias Aesir.ZoneServer.CombatTestHelper
    alias Aesir.ZoneServer.Mmo.Option
    alias Aesir.ZoneServer.Mmo.Skill.Definition
    alias Aesir.ZoneServer.Mmo.Skill.Origin
    alias Aesir.ZoneServer.Mmo.StatusStorage

    @phases [:cast_begin, :cast_end, :splash]

    defp skill(attrs \\ []) do
      [id: 5, name: :sm_bash, display_name: "Bash", max_level: 1]
      |> Keyword.merge(attrs)
      |> Definition.build!(__MODULE__)
    end

    defp player_target(id, option \\ 0) do
      :ok =
        UnitRegistry.register_unit(
          :player,
          id,
          PlayerState,
          %PlayerState{character_id: id, option: option},
          self()
        )

      CombatTestHelper.create_player_combatant(unit_id: id)
    end

    defp caster(attrs \\ []) do
      CombatTestHelper.create_mob_combatant(unit_id: 9_801)
      |> Map.merge(Map.new(attrs))
    end

    defp check(caster, target, definition, phases \\ @phases),
      do: Enum.map(phases, &Targeting.validate_skill_use(caster, target, definition, &1))

    test "Hiding blocks every phase unless the skill reaches hidden targets" do
      target = player_target(9_802)
      :ok = StatusStorage.apply_status(:player, 9_802, :sc_hiding)

      assert check(caster(), target, skill()) == List.duplicate({:error, :target_concealed}, 3)
      assert check(nil, target, skill()) == List.duplicate({:error, :target_concealed}, 3)
      assert check(caster(), target, skill(target_hidden: true)) == [:ok, :ok, :ok]
    end

    test "Cloaking blocks only the cast begin, even for a TargetHidden skill" do
      target = player_target(9_803)
      :ok = StatusStorage.apply_status(:player, 9_803, :sc_cloaking)

      assert check(caster(), target, skill()) == [{:error, :target_concealed}, :ok, :ok]

      assert check(caster(), target, skill(target_hidden: true)) ==
               [{:error, :target_concealed}, :ok, :ok]
    end

    test "a boss or a detector sees a concealed player, but not a GM-invisible one" do
      target = player_target(9_804)
      :ok = StatusStorage.apply_status(:player, 9_804, :sc_hiding)

      assert check(caster(class: :boss), target, skill()) == [:ok, :ok, :ok]
      assert check(caster(detector: true), target, skill()) == [:ok, :ok, :ok]

      invisible = player_target(9_805, Option.id(:invisible) ||| Option.id(:riding))

      assert check(caster(class: :boss, detector: true), invisible, skill(target_hidden: true)) ==
               List.duplicate({:error, :target_concealed}, 3)
    end

    test "a hidden non-player is seen only by a detector" do
      target = CombatTestHelper.create_mob_combatant(unit_id: 9_806)
      :ok = StatusStorage.apply_status(:mob, 9_806, :sc_hiding)

      assert check(caster(class: :boss), target, skill()) ==
               List.duplicate({:error, :target_concealed}, 3)

      assert check(caster(detector: true), target, skill()) == [:ok, :ok, :ok]
    end

    test "unit placement checks only the target's Hiding against TargetHidden" do
      hidden = player_target(9_807)
      :ok = StatusStorage.apply_status(:player, 9_807, :sc_hiding)
      cloaked = player_target(9_808)
      :ok = StatusStorage.apply_status(:player, 9_808, :sc_cloaking)
      boss = caster(class: :boss, detector: true)

      assert Targeting.validate_skill_use(boss, hidden, skill(), :unit_place) ==
               {:error, :target_concealed}

      assert Targeting.validate_skill_use(nil, hidden, skill(target_hidden: true), :unit_place) ==
               :ok

      assert Targeting.validate_skill_use(nil, cloaked, skill(), :unit_place) == :ok
    end

    test "a caster targeting itself is never concealed from itself" do
      target = player_target(9_809)
      :ok = StatusStorage.apply_status(:player, 9_809, :sc_hiding)

      assert check(target, target, skill(allow_when_hidden: true)) == [:ok, :ok, :ok]
    end

    test "a recipient check refuses a caster that cannot act, but not one waiting to petrify" do
      target = player_target(9_812)

      :ok = StatusStorage.apply_status(:mob, 9_801, :sc_stun)
      assert check(caster(), target, skill()) == [:ok, :ok, {:error, :caster_restricted}]

      :ok = StatusStorage.remove_status(:mob, 9_801, :sc_stun)
      :ok = StatusStorage.apply_status(:mob, 9_801, :sc_stonewait)
      assert check(caster(), target, skill()) == [:ok, :ok, :ok]
    end

    test "a hidden player's splash lands only for a skill usable while hidden" do
      caster = player_target(9_813)
      :ok = StatusStorage.apply_status(:player, 9_813, :sc_hiding)
      target = CombatTestHelper.create_mob_combatant(unit_id: 9_814)

      assert Targeting.validate_skill_use(caster, target, skill(), :splash) ==
               {:error, :caster_restricted}

      assert Targeting.validate_skill_use(caster, target, skill(allow_when_hidden: true), :splash) ==
               :ok
    end

    test "Storm Gust and Frost Nova pass over a frozen recipient" do
      target = player_target(9_815)
      :ok = StatusStorage.apply_status(:player, 9_815, :sc_freeze)

      for id <- [88, 89] do
        assert check(caster(), target, skill(id: id)) == [:ok, :ok, {:error, :target_restricted}]
      end

      assert check(caster(), target, skill()) == [:ok, :ok, :ok]
    end

    @tag game_mode: :pre_renewal
    test "classic Roki's Weil locks a splash except for the skill the caster is item-casting" do
      caster = player_target(9_816)
      :ok = StatusStorage.apply_status(:player, 9_816, :sc_rokisweil)
      target = CombatTestHelper.create_mob_combatant(unit_id: 9_817)
      item = %{invocation: :item, autocast_flag?: false}
      splash = fn -> Targeting.validate_skill_use(caster, target, skill(), :splash) end

      assert splash.() == {:error, :caster_restricted}

      assert Origin.with_skill(:sm_bash, {:player, 9_816}, item, splash) == :ok

      assert Origin.with_skill(:mg_firebolt, {:player, 9_816}, item, splash) ==
               {:error, :caster_restricted}

      assert Origin.with_skill(:sm_bash, {:player, 9_818}, item, splash) ==
               {:error, :caster_restricted}

      assert Origin.with_skill(:sm_bash, {:player, 9_816}, %{item | invocation: :normal}, splash) ==
               {:error, :caster_restricted}

      assert Origin.with_skill(:sm_bash, {:player, 9_816}, splash) == {:error, :caster_restricted}
    end

    @tag game_mode: :renewal
    test "renewal has no Roki's Weil lock" do
      caster = player_target(9_819)
      :ok = StatusStorage.apply_status(:player, 9_819, :sc_rokisweil)
      target = CombatTestHelper.create_mob_combatant(unit_id: 9_820)

      assert Targeting.validate_skill_use(caster, target, skill(), :splash) == :ok
    end

    @tag game_mode: :pre_renewal
    test "classic Pressure never reaches a hidden target after the cast begins" do
      target = player_target(9_810)
      :ok = StatusStorage.apply_status(:player, 9_810, :sc_hiding)
      pressure = skill(id: 367, name: :pa_pressure)

      assert check(caster(class: :boss), target, pressure) ==
               [:ok, {:error, :target_concealed}, {:error, :target_concealed}]
    end

    @tag game_mode: :renewal
    test "renewal Pressure follows the ordinary rule" do
      target = player_target(9_811)
      :ok = StatusStorage.apply_status(:player, 9_811, :sc_hiding)
      pressure = skill(id: 367, name: :pa_pressure)

      assert check(caster(class: :boss), target, pressure) == [:ok, :ok, :ok]
    end
  end

  describe "validate_delivery/4" do
    alias Aesir.ZoneServer.CombatTestHelper
    alias Aesir.ZoneServer.Mmo.Skill.Definition
    alias Aesir.ZoneServer.Mmo.StatusStorage

    defp splash_skill(attrs \\ []) do
      [id: 5, name: :sm_bash, display_name: "Bash", max_level: 1, damage_splash: true]
      |> Keyword.merge(attrs)
      |> Definition.build!(__MODULE__)
    end

    defp hidden_player(id) do
      :ok =
        UnitRegistry.register_unit(
          :player,
          id,
          PlayerState,
          %PlayerState{character_id: id},
          self()
        )

      :ok = StatusStorage.apply_status(:player, id, :sc_hiding)
      CombatTestHelper.create_player_combatant(unit_id: id)
    end

    defp boss, do: CombatTestHelper.create_mob_combatant(unit_id: 9_831) |> Map.put(:class, :boss)

    test "a direct hit is never re-checked; a unit hit always is" do
      target = hidden_player(9_832)

      assert Targeting.validate_delivery(boss(), target, splash_skill(), :direct) == :ok

      assert Targeting.validate_delivery(
               %{boss() | class: :normal},
               target,
               splash_skill(),
               :unit
             ) ==
               {:error, :target_concealed}

      assert Targeting.validate_delivery(boss(), target, splash_skill(), :unit) == :ok
    end

    test "an animated splash re-checks every recipient but the primary, for Splash non-NPC skills" do
      target = hidden_player(9_833)
      caster = %{boss() | class: :normal}

      assert Targeting.validate_delivery(
               caster,
               target,
               splash_skill(),
               {:splash, {:player, 9_833}}
             ) ==
               :ok

      assert Targeting.validate_delivery(caster, target, splash_skill(), {:splash, nil}) ==
               {:error, :target_concealed}

      for skill <- [splash_skill(damage_splash: false), splash_skill(is_npc: true)] do
        assert Targeting.validate_delivery(caster, target, skill, {:splash, nil}) == :ok
      end
    end

    test "an area attack checks secondaries without a caster, so a boss does not see them" do
      target = hidden_player(9_834)

      assert Targeting.validate_delivery(boss(), target, splash_skill(), {:area, nil}) ==
               {:error, :target_concealed}

      assert Targeting.validate_delivery(
               boss(),
               target,
               splash_skill(),
               {:area, {:player, 9_834}}
             ) ==
               :ok
    end

    test "placement reaches a hidden unit only for a TargetHidden skill" do
      hidden_player(9_835)

      refute Targeting.placement_reaches?(splash_skill(), {:player, 9_835})
      assert Targeting.placement_reaches?(splash_skill(target_hidden: true), {:player, 9_835})
      assert Targeting.placement_reaches?(splash_skill(), {:player, 9_836})
    end
  end

  describe "attack_visible?/2" do
    alias Aesir.ZoneServer.Mmo.StatusStorage

    test "a normal attack sees through neither Hiding nor Cloaking without boss or detector" do
      :ok =
        UnitRegistry.register_unit(
          :player,
          9_820,
          PlayerState,
          %PlayerState{character_id: 9_820},
          self()
        )

      :ok = StatusStorage.apply_status(:player, 9_820, :sc_cloaking)
      target = %{unit_type: :player, unit_id: 9_820}

      refute Targeting.attack_visible?(%{class: :normal, detector: false}, target)
      assert Targeting.attack_visible?(%{class: :boss, detector: false}, target)
      assert Targeting.attack_visible?(%{class: :normal, detector: true}, target)
    end
  end
end
