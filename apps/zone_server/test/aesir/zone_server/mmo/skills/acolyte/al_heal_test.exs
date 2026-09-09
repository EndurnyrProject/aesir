defmodule Aesir.ZoneServer.Mmo.Skills.Acolyte.AlHealTest do
  use ExUnit.Case, async: true
  import Mimic

  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Combat.Combatant
  alias Aesir.ZoneServer.Mmo.MobManagement.MobDefinition
  alias Aesir.ZoneServer.Mmo.MobManagement.MobSpawn
  alias Aesir.ZoneServer.Mmo.MobManagement.MobSpawn.SpawnArea
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skills.Acolyte.AlHeal
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.UnitRegistry

  setup :verify_on_exit!

  @caster %PlayerState{character_id: 1000}
  @ally_id 2000

  describe "Catalog lookups" do
    test "by_id(28) resolves al_heal" do
      assert {:ok, def} = Catalog.by_id(28)
      assert def.name == :al_heal
    end

    test "by_name(:al_heal) resolves" do
      assert {:ok, def} = Catalog.by_name(:al_heal)
      assert def.id == 28
    end
  end

  describe "cast/4 — player/ally target" do
    @describetag game_mode: :renewal
    setup do
      stub(PlayerState, :to_combatant, fn _caster ->
        combatant(base_level: 50, int: 50, matk: 50)
      end)

      stub(Combat, :resolve_combatant, fn _id ->
        {:ok, %{race: :player_human}}
      end)

      {:ok, definition} = Catalog.by_id(28)
      {:ok, definition: definition}
    end

    test "healing self calls apply_heal on caster_id with the computed amount",
         %{definition: definition} do
      # div(div(50+50, 5) * 30 * 5, 10) + 50 = 300 + 50 = 350
      expect(Combat, :apply_heal, fn :player, 1000, 350, 1000 -> :ok end)

      assert {:ok, @caster} = AlHeal.cast(@caster, :self, 5, definition)
    end

    test "healing an ally calls apply_heal on target_id with source_id",
         %{definition: definition} do
      expect(Combat, :apply_heal, fn :player, @ally_id, 350, 1000 -> :ok end)

      assert {:ok, @caster} = AlHeal.cast(@caster, {:unit, @ally_id}, 5, definition)
    end
  end

  describe "cast/4 — target unit type is resolved generically" do
    @describetag game_mode: :renewal
    setup do
      stub(PlayerState, :to_combatant, fn _caster ->
        combatant(base_level: 50, int: 50, matk: 50)
      end)

      stub(Combat, :resolve_combatant, fn _id ->
        {:ok, %{race: :formless}}
      end)

      {:ok, definition} = Catalog.by_id(28)
      {:ok, definition: definition}
    end

    test "a mob target calls apply_heal with :mob, not the hardcoded :player",
         %{definition: definition} do
      stub(UnitRegistry, :unit_exists?, fn :mob, @ally_id -> true end)
      expect(Combat, :apply_heal, fn :mob, @ally_id, 350, 1000 -> :ok end)

      assert {:ok, @caster} = AlHeal.cast(@caster, {:unit, @ally_id}, 5, definition)
    end

    test "a typed Homunculus target remains exact despite a same-number mob",
         %{definition: definition} do
      expect(Combat, :resolve_combatant, fn {:homunculus, @ally_id} ->
        {:ok, %{race: :formless}}
      end)

      expect(Combat, :apply_heal, fn :homunculus, @ally_id, 350, 1000 -> :ok end)

      assert {:ok, @caster} =
               AlHeal.cast(@caster, {:unit, {:homunculus, @ally_id}}, 5, definition)
    end
  end

  describe "cast/4 — undead target deals holy damage instead of healing" do
    @describetag game_mode: :renewal

    setup do
      stub(PlayerState, :to_combatant, fn _caster ->
        combatant(base_level: 50, int: 50, matk: 50)
      end)

      {:ok, definition} = Catalog.by_id(28)
      {:ok, definition: definition}
    end

    test "an undead-element enemy calls execute_magic_damage with :holy, not apply_heal",
         %{definition: definition} do
      stub(Combat, :resolve_combatant, fn _id ->
        {:ok, enemy(%{race: :undead, element: {:undead, 1}})}
      end)

      # An offensive cast halves the base first: 300 / 2 + 50 = 200.
      expect(Combat, :execute_magic_damage, fn _caster, @ally_id, 200, opts ->
        assert Keyword.fetch!(opts, :element) == :holy
        assert Keyword.fetch!(opts, :skill_id) == 28
        assert Keyword.fetch!(opts, :skill_level) == 5
        {:ok, {:mob, @ally_id}}
      end)

      assert {:ok, @caster} = AlHeal.cast(@caster, {:unit, @ally_id}, 5, definition)
    end

    test "an undead defense element makes any race an offensive target",
         %{definition: definition} do
      stub(Combat, :resolve_combatant, fn _id ->
        {:ok, enemy(%{race: :demi_human, element: {:undead, 1}})}
      end)

      expect(Combat, :execute_magic_damage, fn _caster, @ally_id, 200, _opts ->
        {:ok, {:mob, @ally_id}}
      end)

      assert {:ok, @caster} = AlHeal.cast(@caster, {:unit, @ally_id}, 5, definition)
    end

    test "a demon-race target that is not undead is healed, not damaged",
         %{definition: definition} do
      stub(Combat, :resolve_combatant, fn _id ->
        {:ok, enemy(%{race: :demon, element: {:dark, 1}})}
      end)

      expect(Combat, :apply_heal, fn :player, @ally_id, 350, 1000 -> :ok end)

      assert {:ok, @caster} = AlHeal.cast(@caster, {:unit, @ally_id}, 5, definition)
    end

    test "an undead-race target with no undead element is healed, not damaged",
         %{definition: definition} do
      stub(Combat, :resolve_combatant, fn _id ->
        {:ok, enemy(%{race: :undead, element: {:ghost, 1}})}
      end)

      expect(Combat, :apply_heal, fn :player, @ally_id, 350, 1000 -> :ok end)

      assert {:ok, @caster} = AlHeal.cast(@caster, {:unit, @ally_id}, 5, definition)
    end

    test "an undead-element target friendly to the caster is healed, not damaged",
         %{definition: definition} do
      stub(Combat, :resolve_combatant, fn _id ->
        {:ok,
         struct(Combatant, %{
           unit_id: @ally_id,
           unit_type: :player,
           race: :player_human,
           element: {:undead, 1}
         })}
      end)

      expect(Combat, :apply_heal, fn :player, @ally_id, 350, 1000 -> :ok end)

      assert {:ok, @caster} = AlHeal.cast(@caster, {:unit, @ally_id}, 5, definition)
    end

    test "smatk on the caster's combat_stats does not change the heal-as-damage amount",
         %{definition: definition} do
      # Heal reads base_level/int (and heal_matk_min/max when present), never
      # smatk. execute_magic_damage/4 (Combat) applies element + min-1 clamp
      # directly to the precomputed heal value -- it never routes through
      # MagicDamageCalculator, so smatk cannot affect it either.
      stub(PlayerState, :to_combatant, fn _caster ->
        combatant(base_level: 50, int: 50, matk: 50)
      end)

      stub(Combat, :resolve_combatant, fn _id ->
        {:ok, enemy(%{race: :undead, element: {:undead, 1}})}
      end)

      expect(Combat, :execute_magic_damage, fn _caster, @ally_id, 200, _opts ->
        {:ok, {:mob, @ally_id}}
      end)

      assert {:ok, @caster} = AlHeal.cast(@caster, {:unit, @ally_id}, 5, definition)
    end
  end

  describe "cast/4 — undead target, pre-renewal" do
    @describetag game_mode: :pre_renewal

    setup do
      stub(PlayerState, :to_combatant, fn _caster ->
        combatant(base_level: 50, int: 50, matk: 50)
      end)

      {:ok, definition} = Catalog.by_id(28)
      {:ok, definition: definition}
    end

    test "halves the classic base and adds no MATK band", %{definition: definition} do
      stub(Combat, :resolve_combatant, fn _id ->
        {:ok, enemy(%{race: :undead, element: {:undead, 1}})}
      end)

      # div(100, 8) * (4 + 5 * 8) = 12 * 44 = 528, halved to 264.
      expect(Combat, :execute_magic_damage, fn _caster, @ally_id, 264, _opts ->
        {:ok, {:mob, @ally_id}}
      end)

      assert {:ok, @caster} = AlHeal.cast(@caster, {:unit, @ally_id}, 5, definition)
    end
  end

  describe "heal amount formula (renewal: base = div(lv+int,5)*30*lv/10 + matk)" do
    @describetag game_mode: :renewal
    setup do
      stub(Combat, :resolve_combatant, fn _id -> {:ok, %{race: :player_human}} end)
      {:ok, definition} = Catalog.by_id(28)
      {:ok, definition: definition}
    end

    test "lv1 @ base_level=10, int=10, matk=0 → 12", %{definition: definition} do
      stub(PlayerState, :to_combatant, fn _ -> combatant(base_level: 10, int: 10, matk: 0) end)
      # div(div(20,5)*30*1, 10) + 0 = div(4*30, 10) = 12
      expect(Combat, :apply_heal, fn :player, 1000, 12, 1000 -> :ok end)
      AlHeal.cast(@caster, :self, 1, definition)
    end

    test "lv10 @ base_level=99, int=50, matk=100 → 970", %{definition: definition} do
      stub(PlayerState, :to_combatant, fn _ -> combatant(base_level: 99, int: 50, matk: 100) end)
      # div(div(149,5)*30*10, 10) + 100 = div(29*300, 10) + 100 = 870 + 100 = 970
      expect(Combat, :apply_heal, fn :player, 1000, 970, 1000 -> :ok end)
      AlHeal.cast(@caster, :self, 10, definition)
    end

    test "lv5 @ base_level=50, int=50, matk=50 → 350", %{definition: definition} do
      stub(PlayerState, :to_combatant, fn _ -> combatant(base_level: 50, int: 50, matk: 50) end)
      # div(div(100,5)*30*5, 10) + 50 = div(20*150, 10) + 50 = 300 + 50 = 350
      expect(Combat, :apply_heal, fn :player, 1000, 350, 1000 -> :ok end)
      AlHeal.cast(@caster, :self, 5, definition)
    end

    test "rolls the heal MATK band within [base + heal_matk_min, base + heal_matk_max - 1]",
         %{definition: definition} do
      # base = div(div(100,5)*30*5, 10) = 300; heal band 10..20 -> heal in [310, 319].
      # Heal uses heal_matk_min/max (base_matk + weapon variance, NO flat MATK).
      stub(PlayerState, :to_combatant, fn _ ->
        combatant(base_level: 50, int: 50, matk: 999, heal_matk_min: 10, heal_matk_max: 20)
      end)

      test_pid = self()

      stub(Combat, :apply_heal, fn :player, 1000, amount, 1000 ->
        send(test_pid, {:heal, amount})
      end)

      for _ <- 1..200, do: AlHeal.cast(@caster, :self, 5, definition)
      amounts = for _ <- 1..200, do: receive(do: ({:heal, a} -> a))

      assert Enum.all?(amounts, fn a -> a >= 310 and a <= 319 end)
      assert length(Enum.uniq(amounts)) > 1
    end

    test "heal_matk_min == heal_matk_max heals the exact deterministic value",
         %{definition: definition} do
      stub(PlayerState, :to_combatant, fn _ ->
        combatant(base_level: 50, int: 50, matk: 999, heal_matk_min: 50, heal_matk_max: 50)
      end)

      # 300 + roll(50, 50) = 350; flat combat matk (999) is intentionally ignored
      expect(Combat, :apply_heal, fn :player, 1000, 350, 1000 -> :ok end)
      AlHeal.cast(@caster, :self, 5, definition)
    end
  end

  describe "hplus heal boost (row 14: heal + div(heal * hplus, 100))" do
    @describetag game_mode: :renewal
    setup do
      stub(Combat, :resolve_combatant, fn _id -> {:ok, %{race: :player_human}} end)
      {:ok, definition} = Catalog.by_id(28)
      {:ok, definition: definition}
    end

    test "hplus 10 boosts a 350 base heal to 385", %{definition: definition} do
      stub(PlayerState, :to_combatant, fn _ ->
        combatant(base_level: 50, int: 50, matk: 50, hplus: 10)
      end)

      # base heal is 350 (see the lv5 @ base_level=50 vector above);
      # 350 + div(350 * 10, 100) = 350 + 35 = 385
      expect(Combat, :apply_heal, fn :player, 1000, 385, 1000 -> :ok end)
      AlHeal.cast(@caster, :self, 5, definition)
    end

    test "hplus 0 leaves the heal unchanged", %{definition: definition} do
      stub(PlayerState, :to_combatant, fn _ ->
        combatant(base_level: 50, int: 50, matk: 50, hplus: 0)
      end)

      expect(Combat, :apply_heal, fn :player, 1000, 350, 1000 -> :ok end)
      AlHeal.cast(@caster, :self, 5, definition)
    end

    test "SPL still raises the heal via the MATK band (row 2 -> calculate_base_matk)",
         %{definition: definition} do
      # SPL flows into caster stats as a higher matk (calculate_base_matk, Task 8);
      # a higher matk band raises the heal even with hplus at 0.
      stub(PlayerState, :to_combatant, fn _ ->
        combatant(base_level: 50, int: 50, matk: 150, hplus: 0)
      end)

      # div(div(100,5)*30*5, 10) + 150 = 300 + 150 = 450
      expect(Combat, :apply_heal, fn :player, 1000, 450, 1000 -> :ok end)
      AlHeal.cast(@caster, :self, 5, definition)
    end
  end

  describe "heal_power (equipment bHealPower)" do
    @describetag game_mode: :renewal
    setup do
      stub(Combat, :resolve_combatant, fn _id -> {:ok, %{race: :player_human}} end)
      {:ok, definition} = Catalog.by_id(28)
      {:ok, definition: definition}
    end

    test "heal_power 20 raises the 300 base to 360 before the 50-point MATK band",
         %{definition: definition} do
      stub(PlayerState, :to_combatant, fn _ ->
        combatant(base_level: 50, int: 50, matk: 50, heal_power: 20)
      end)

      expect(Combat, :apply_heal, fn :player, 1000, 410, 1000 -> :ok end)
      AlHeal.cast(@caster, :self, 5, definition)
    end

    test "AL_HEAL-specific rate adds to generic heal power and ignores other skill ids",
         %{definition: definition} do
      stub(PlayerState, :to_combatant, fn _ ->
        combatant(
          base_level: 50,
          int: 50,
          matk: 50,
          heal_power: 10,
          skill_heal: 15,
          other_skill_heal: 100
        )
      end)

      # base 300 + 25 percent = 375, then the 50-point MATK band.
      expect(Combat, :apply_heal, fn :player, 1000, 425, 1000 -> :ok end)
      AlHeal.cast(@caster, :self, 5, definition)
    end

    test "heal_power and hplus are separate percent steps around the MATK band",
         %{definition: definition} do
      stub(PlayerState, :to_combatant, fn _ ->
        combatant(base_level: 50, int: 50, matk: 50, hplus: 10, heal_power: 20)
      end)

      # base 300 -> heal_power 20% -> 360 -> MATK band 50 -> 410 -> hplus 10% -> 451
      expect(Combat, :apply_heal, fn :player, 1000, 451, 1000 -> :ok end)
      AlHeal.cast(@caster, :self, 5, definition)
    end

    test "an absent heal_power leaves the heal unchanged", %{definition: definition} do
      stub(PlayerState, :to_combatant, fn _ ->
        combatant(base_level: 50, int: 50, matk: 50)
      end)

      expect(Combat, :apply_heal, fn :player, 1000, 350, 1000 -> :ok end)
      AlHeal.cast(@caster, :self, 5, definition)
    end
  end

  describe "heal amount formula, pre-renewal" do
    @describetag game_mode: :pre_renewal

    setup do
      stub(Combat, :resolve_combatant, fn _id -> {:ok, %{race: :player_human}} end)
      {:ok, definition} = Catalog.by_id(28)
      {:ok, definition: definition}
    end

    test "the classic base ignores the MATK band entirely", %{definition: definition} do
      stub(PlayerState, :to_combatant, fn _ -> combatant(base_level: 50, int: 50, matk: 50) end)
      # div(100, 8) * (4 + 5 * 8) = 12 * 44 = 528, with no MATK term.
      expect(Combat, :apply_heal, fn :player, 1000, 528, 1000 -> :ok end)
      AlHeal.cast(@caster, :self, 5, definition)
    end

    test "a rolled MATK band does not move the amount", %{definition: definition} do
      stub(PlayerState, :to_combatant, fn _ ->
        combatant(base_level: 50, int: 50, matk: 999, heal_matk_min: 10, heal_matk_max: 20)
      end)

      expect(Combat, :apply_heal, fn :player, 1000, 528, 1000 -> :ok end)
      AlHeal.cast(@caster, :self, 5, definition)
    end

    test "heal_power is a percentage of the classic base", %{definition: definition} do
      stub(PlayerState, :to_combatant, fn _ ->
        combatant(base_level: 50, int: 50, matk: 50, heal_power: 20)
      end)

      # 528 + div(528 * 20, 100) = 528 + 105 = 633
      expect(Combat, :apply_heal, fn :player, 1000, 633, 1000 -> :ok end)
      AlHeal.cast(@caster, :self, 5, definition)
    end

    test "the trait heal bonus has no effect", %{definition: definition} do
      stub(PlayerState, :to_combatant, fn _ ->
        combatant(base_level: 50, int: 50, matk: 50, hplus: 10)
      end)

      expect(Combat, :apply_heal, fn :player, 1000, 528, 1000 -> :ok end)
      AlHeal.cast(@caster, :self, 5, definition)
    end
  end

  describe "cast/4 — mob caster" do
    @describetag game_mode: :renewal
    setup do
      Aesir.TestEtsSetup.setup_ets_tables(%{})
      stub(Combat, :resolve_combatant, fn _id -> {:ok, %{race: :player_human}} end)
      {:ok, definition} = Catalog.by_id(28)
      {:ok, definition: definition}
    end

    test "reads INT/base level off the mob's own to_combatant, not PlayerState",
         %{definition: definition} do
      mob = mob_caster(base_level: 50, int: 50, matk: 50)

      # Same vector as the player lv5 @ base_level=50 test above: 350.
      expect(Combat, :apply_heal, fn :player, @ally_id, 350, 9001 -> :ok end)

      assert {:ok, ^mob} = AlHeal.cast(mob, {:unit, @ally_id}, 5, definition)
    end
  end

  # A real Combatant, because Heal's offensive branch runs the shared enemy
  # relationship check and a hand-built map cannot answer it.
  defp combatant(opts) do
    matk = Keyword.get(opts, :matk, 0)

    struct(Combatant, %{
      unit_id: Keyword.get(opts, :unit_id, 1000),
      unit_type: Keyword.get(opts, :unit_type, :player),
      progression: %{base_level: Keyword.fetch!(opts, :base_level)},
      base_stats: %{int: Keyword.fetch!(opts, :int)},
      combat_stats: %{
        matk: matk,
        heal_matk_min: Keyword.get(opts, :heal_matk_min, matk),
        heal_matk_max: Keyword.get(opts, :heal_matk_max, matk),
        hplus: Keyword.get(opts, :hplus, 0)
      },
      equip_modifiers: %{
        :heal_power => Keyword.get(opts, :heal_power, 0),
        {:skill_heal, 28} => Keyword.get(opts, :skill_heal, 0),
        {:skill_heal, 29} => Keyword.get(opts, :other_skill_heal, 0)
      }
    })
  end

  # An enemy mob standing in for whatever Combat.resolve_combatant would return.
  defp enemy(attrs) do
    struct(Combatant, Map.merge(%{unit_id: @ally_id, unit_type: :mob}, attrs))
  end

  defp mob_caster(opts) do
    mob_data = %MobDefinition{
      id: 1002,
      aegis_name: "test_healer",
      name: "Test Healer",
      level: Keyword.fetch!(opts, :base_level),
      hp: 1000,
      stats: %{str: 1, agi: 1, vit: 1, int: Keyword.fetch!(opts, :int), dex: 1, luk: 1},
      matk: Keyword.fetch!(opts, :matk),
      attack_range: 1,
      size: :medium,
      race: :formless,
      element: {:neutral, 1},
      walk_speed: 200,
      attack_delay: 1000,
      attack_motion: 500,
      client_attack_motion: 400,
      damage_motion: 300
    }

    spawn_ref = %MobSpawn{
      mob: 1002,
      amount: 1,
      respawn_time: 5000,
      spawn_area: %SpawnArea{x: 100, y: 100}
    }

    MobState.new(9001, mob_data, spawn_ref, "prontera", 100, 100)
  end
end
