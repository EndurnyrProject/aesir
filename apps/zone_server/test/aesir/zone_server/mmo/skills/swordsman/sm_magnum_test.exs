defmodule Aesir.ZoneServer.Mmo.Skills.Swordsman.SmMagnumTest do
  use ExUnit.Case, async: true
  import Mimic

  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skills.Swordsman.SmMagnum
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Mmo.StatusEffect.Registry, as: StatusRegistry
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.Stats
  alias Aesir.ZoneServer.Unit.Player.Stats.Modifiers

  setup :verify_on_exit!

  test "Catalog.active_module_for/1 resolves sm_magnum" do
    assert {:ok, SmMagnum} = Catalog.active_module_for(:sm_magnum)
  end

  @tag game_mode: :renewal
  test "cast/4 resolves caster-centered mob-native blow before raising the fire aura" do
    {:ok, definition} = Catalog.by_id(7)

    caster = %PlayerState{
      character_id: 42,
      x: 10,
      y: 20,
      stats: %Stats{
        modifiers: %Modifiers{equipment: %{{:add_skill_blow, definition.id} => 3}}
      }
    }

    level = 3
    duration = Enum.at(definition.duration, level - 1)

    expect(Combat, :execute_splash_attack, fn ^caster, {10, 20}, 2, opts ->
      assert caster.stats.modifiers.equipment[{:add_skill_blow, definition.id}] == 3
      assert opts[:skill_id] == definition.id
      assert opts[:skill_level] == level
      assert is_function(opts[:skill_ratio], 1)
      assert opts[:element] == :fire
      assert opts[:skip_crit] == true
      assert opts[:base_distance] == 2
      assert opts[:origin] == {10, 20}
      assert opts[:native_target_types] == [:mob]
      send(self(), :combined_blow_requested)
      [101, 102]
    end)

    reject(&Combat.knockback/5)

    expect(StatusInterpreter, :apply_status, fn :player, 42, :sc_sub_weaponproperty, params ->
      assert params[:val2] == 20
      assert_received :combined_blow_requested
      assert params[:val1] == 3
      assert params[:caster_id] == 42
      assert params[:duration] == duration
      :ok
    end)

    assert {:ok, ^caster} = SmMagnum.cast(caster, :self, level, definition)
  end

  test "renewal trades the long aftercast delay for a two second cooldown" do
    renewal = SmMagnum.definition(:renewal)

    assert renewal.after_cast_delay == List.duplicate(500, 10)
    assert renewal.cooldown == List.duplicate(2_000, 10)
  end

  test "classic locks the caster with a long aftercast delay and no cooldown" do
    classic = SmMagnum.definition(:pre_renewal)

    assert classic.after_cast_delay == List.duplicate(2_000, 10)
    assert classic.cooldown == List.duplicate(0, 10)
  end

  @tag game_mode: :renewal
  test "renewal casts regardless of how little health the caster has left" do
    assert SmMagnum.validate(caster_with_hp(1), :self, 1, definition()) == :ok
    assert SmMagnum.validate(caster_with_hp(1), :self, 10, definition()) == :ok
  end

  @tag game_mode: :pre_renewal
  test "classic refuses the cast unless the caster is above the level's health reserve" do
    assert SmMagnum.validate(caster_with_hp(21), :self, 1, definition()) == :ok

    assert SmMagnum.validate(caster_with_hp(20), :self, 1, definition()) ==
             {:error, :insufficient_hp}

    assert SmMagnum.validate(caster_with_hp(17), :self, 10, definition()) == :ok

    assert SmMagnum.validate(caster_with_hp(16), :self, 10, definition()) ==
             {:error, :insufficient_hp}
  end

  defp definition do
    {:ok, definition} = Catalog.by_id(7)
    definition
  end

  defp caster_with_hp(hp) do
    %PlayerState{
      character_id: 1,
      stats: %Stats{current_state: %{hp: hp, sp: 100}}
    }
  end

  test "charges the inner ring more than the outer ring, in both modes" do
    caster = %PlayerState{character_id: 42, x: 10, y: 20}

    for level <- [1, 5, 10] do
      expect(Combat, :execute_splash_attack, fn ^caster, {10, 20}, 2, opts ->
        ratio = opts[:skill_ratio]

        assert ratio.(0) == 100 + 20 * level
        assert ratio.(1) == 100 + 20 * level
        assert ratio.(2) == 100 + 10 * level

        assert opts[:hit_rate_bonus_pct] == 10 * level
        []
      end)

      stub(StatusInterpreter, :apply_status, fn :player, 42, _status, _params -> :ok end)

      assert {:ok, ^caster} = SmMagnum.cast(caster, :self, level, definition())
    end
  end

  @tag game_mode: :renewal
  test "renewal raises the aura in its own slot, so an endow survives the cast" do
    caster = %PlayerState{character_id: 42, x: 10, y: 20}
    stub(Combat, :execute_splash_attack, fn _c, _center, _radius, _opts -> [] end)

    expect(StatusInterpreter, :apply_status, fn :player, 42, :sc_sub_weaponproperty, params ->
      assert params[:val1] == 3
      assert params[:val2] == 20
      assert params[:duration] == 10_000
      :ok
    end)

    assert {:ok, ^caster} = SmMagnum.cast(caster, :self, 1, definition())

    # The aura's own status carries no endow in its replace-on-cast list, and no
    # endow names it, so an endow that was already up is untouched by the cast.
    aura = StatusRegistry.get_definition(:sc_sub_weaponproperty)

    assert aura.end_on_start == []
    refute :sc_sub_weaponproperty in StatusRegistry.get_definition(:sc_aspersio).end_on_start
  end

  @tag game_mode: :pre_renewal
  test "classic raises the aura in the shared endow slot, which replaces an endow" do
    caster = %PlayerState{character_id: 42, x: 10, y: 20}
    stub(Combat, :execute_splash_attack, fn _c, _center, _radius, _opts -> [] end)

    expect(StatusInterpreter, :apply_status, fn :player, 42, :sc_watk_element, params ->
      assert params[:val1] == 3
      assert params[:val2] == 20
      assert params[:duration] == 10_000
      :ok
    end)

    assert {:ok, ^caster} = SmMagnum.cast(caster, :self, 1, definition())

    # The shared slot ends every endow on cast, so classic cannot hold both.
    assert :sc_aspersio in StatusRegistry.get_definition(:sc_watk_element).end_on_start
  end
end
