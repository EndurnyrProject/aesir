defmodule Aesir.ZoneServer.Mmo.Skills.Hunter.HtBlitzbeatTest do
  use ExUnit.Case, async: true
  use Mimic

  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Option
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skill.Interpreter
  alias Aesir.ZoneServer.Mmo.Skills.Hunter.HtBlitzbeat
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.Stats
  alias Aesir.ZoneServer.Unit.Player.Stats.Equipment
  alias Aesir.ZoneServer.Unit.Player.Stats.PlayerProgression
  alias Aesir.ZoneServer.Unit.Stats.BaseStats
  alias Aesir.ZoneServer.Unit.Stats.CurrentState

  setup :verify_on_exit!

  @vulture_id 44
  @blitz_id 129
  @steel_crow_id 128
  @falcon_option Option.id(:falcon)

  defp player(opts \\ []) do
    blitz_level = Keyword.get(opts, :blitz_level, 5)
    steel_crow_level = Keyword.get(opts, :steel_crow_level, 10)
    vulture_level = Keyword.get(opts, :vulture_level, 0)

    learned =
      %{}
      |> maybe_learn(@vulture_id, vulture_level)
      |> maybe_learn(@blitz_id, blitz_level)
      |> maybe_learn(@steel_crow_id, steel_crow_level)

    stats = %Stats{
      base_stats: %BaseStats{
        str: 1,
        agi: Keyword.get(opts, :agi, 99),
        vit: 1,
        int: 1,
        dex: Keyword.get(opts, :dex, 99),
        luk: Keyword.get(opts, :luk, 3)
      },
      progression: %PlayerProgression{
        base_level: 50,
        job_level: Keyword.get(opts, :job_level, 50),
        job_id: 11,
        learned_skills: learned
      },
      equipment: %Equipment{},
      current_state: %CurrentState{hp: 100, sp: Keyword.get(opts, :sp, 100)}
    }

    %PlayerState{
      character_id: 1001,
      option: if(Keyword.get(opts, :falcon?, true), do: @falcon_option, else: 0),
      x: 150,
      y: 150,
      map_name: "prontera",
      stats: stats
    }
  end

  defp maybe_learn(learned, _skill_id, 0), do: learned
  defp maybe_learn(learned, skill_id, level), do: Map.put(learned, skill_id, level)

  describe "definition" do
    test "publishes the canonical Blitz Beat metadata and both capabilities" do
      definition = HtBlitzbeat.definition()

      assert definition.id == 129
      assert definition.name == :ht_blitzbeat
      assert definition.max_level == 5
      assert definition.target_type == :target_enemy
      assert definition.damage_type == :damage
      assert definition.damage_kind == :misc
      assert definition.element == :neutral
      assert definition.range == 5
      assert definition.sp_cost == [10, 13, 16, 19, 22]
      assert definition.cast_time == List.duplicate(800, 5)
      assert definition.fixed_cast_time == List.duplicate(200, 5)
      assert definition.after_cast_delay == List.duplicate(1_000, 5)
      assert definition.hit_count == 1
      assert definition.splash_radius == 1
      assert {:ok, HtBlitzbeat} = Catalog.active_module_for(:ht_blitzbeat)
      assert {:ok, HtBlitzbeat} = Catalog.passive_module_for(:ht_blitzbeat)
      assert {:ok, ^definition} = Catalog.by_id(129)
    end

    test "adds learned Vulture's Eye to the interpreter's base cast range" do
      definition = HtBlitzbeat.definition()

      assert Interpreter.effective_range(definition, player(vulture_level: 0), 5) == 5
      assert Interpreter.effective_range(definition, player(vulture_level: 3), 5) == 8
    end
  end

  describe "manual cast" do
    test "requires an equipped Falcon" do
      caster = player(falcon?: false)

      assert {:error, :falcon_not_equipped} =
               HtBlitzbeat.validate(caster, {:unit, 2001}, 5, HtBlitzbeat.definition())

      assert :ok =
               HtBlitzbeat.validate(player(), {:unit, 2001}, 5, HtBlitzbeat.definition())
    end

    test "delivers total Falcon damage through the shared one-cell misc splash" do
      caster = player()
      definition = HtBlitzbeat.definition()

      expect(Combat, :resolve_combatant, fn 2001 ->
        {:ok, %{position: {151, 150}}}
      end)

      expect(Combat, :execute_misc_splash, fn ^caster, {151, 150}, 1, opts ->
        assert opts == [
                 skill_id: 129,
                 skill_level: 5,
                 base_damage: 1_380,
                 element: :neutral,
                 display_hit_count: 5
               ]

        [2001, 2002]
      end)

      assert {:ok, ^caster} = HtBlitzbeat.cast(caster, {:unit, 2001}, 5, definition)
    end
  end

  describe "automatic proc" do
    setup do
      stub(Stats, :weapon_type, fn _equipment -> :bow end)
      :ok
    end

    test "the production callback delegates to the automatic proc path" do
      caster = player(luk: 300)
      hit = %{target_type: :mob, target_id: 2001, position: {151, 150}}

      assert :ok = HtBlitzbeat.after_normal_hit(caster, hit)
      assert_receive {:skill, {:deferred, HtBlitzbeat, %{center: {151, 150}, skill_level: 5}}}
    end

    test "uses an inclusive 0..999 threshold and Hunter job-level cap" do
      caster = player(blitz_level: 5, job_level: 11, luk: 3)
      hit = %{target_type: :mob, target_id: 2001, position: {151, 150}}

      assert :ok = HtBlitzbeat.after_normal_hit(caster, hit, rng: fn 1_000 -> 11 end)

      assert_receive {:skill, {:deferred, HtBlitzbeat, %{center: {151, 150}, skill_level: 2}}}

      assert :ok = HtBlitzbeat.after_normal_hit(caster, hit, rng: fn 1_000 -> 12 end)
      refute_receive {:skill, {:deferred, HtBlitzbeat, _}}
    end

    test "requires a bow, an equipped Falcon, and learned Blitz Beat" do
      hit = %{target_type: :mob, target_id: 2001, position: {151, 150}}

      stub(Stats, :weapon_type, fn
        %Equipment{right_hand: 1} -> :bow
        _equipment -> :dagger
      end)

      assert :ok =
               HtBlitzbeat.after_normal_hit(
                 player() |> put_in([Access.key!(:stats), Access.key!(:equipment)], %Equipment{}),
                 hit,
                 rng: fn 1_000 -> 0 end
               )

      falconless =
        player(falcon?: false)
        |> put_in([Access.key!(:stats), Access.key!(:equipment)], %Equipment{right_hand: 1})

      assert :ok = HtBlitzbeat.after_normal_hit(falconless, hit, rng: fn 1_000 -> 0 end)

      unlearned =
        player(blitz_level: 0)
        |> put_in([Access.key!(:stats), Access.key!(:equipment)], %Equipment{right_hand: 1})

      assert :ok = HtBlitzbeat.after_normal_hit(unlearned, hit, rng: fn 1_000 -> 0 end)
      refute_receive {:skill, {:deferred, HtBlitzbeat, _}}
    end

    test "queues delivery instead of synchronously calling combat" do
      caster = player()
      hit = %{target_type: :mob, target_id: 2001, position: {151, 150}}
      reject(&Combat.execute_misc_splash/4)

      assert :ok = HtBlitzbeat.after_normal_hit(caster, hit, rng: fn 1_000 -> 0 end)
      assert_receive {:skill, {:deferred, HtBlitzbeat, _}}
    end

    test "deferred delivery reuses the captured center without charging or changing caster state" do
      caster = player(sp: 3)

      expect(Combat, :execute_misc_splash, fn ^caster, {151, 150}, 1, opts ->
        assert opts[:base_damage] == 1_380
        assert opts[:display_hit_count] == 5
        [2002]
      end)

      assert :ok =
               HtBlitzbeat.deferred(%{center: {151, 150}, skill_level: 5}, caster)

      assert caster.stats.current_state.sp == 3
    end
  end
end
