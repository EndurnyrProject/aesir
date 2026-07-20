defmodule Aesir.ZoneServer.Mmo.Skills.Acolyte.AlBlessingTest do
  use ExUnit.Case, async: true
  import Mimic

  alias Aesir.ZoneServer.Mmo.Combat.TargetResolver
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skills.Acolyte.AlBlessing
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Unit.UnitRegistry

  setup :verify_on_exit!

  setup do
    Mimic.copy(TargetResolver)
  end

  test "Catalog.by_id/1 resolves al_blessing" do
    assert {:ok, definition} = Catalog.by_id(34)
    assert definition.name == :al_blessing
    assert definition.max_level == 10
    assert definition.target_type == :target_ally
    assert length(definition.sp_cost) == 10
    assert length(definition.duration) == 10
  end

  test "Catalog.by_name/1 resolves al_blessing" do
    assert {:ok, %{id: 34}} = Catalog.by_name(:al_blessing)
  end

  test "Catalog.active_module_for/1 resolves al_blessing" do
    assert {:ok, AlBlessing} = Catalog.active_module_for(:al_blessing)
  end

  test "cast/4 applies sc_blessing with val1=level, val2=level at level 1" do
    {:ok, definition} = Catalog.by_id(34)
    caster = %{character_id: 1000}

    expect(StatusInterpreter, :apply_status, fn :player, 1000, :sc_blessing, params ->
      assert params[:val1] == 1
      assert params[:val2] == 1
      assert params[:caster_id] == 1000
      assert params[:duration] == 60_000
      :ok
    end)

    assert {:ok, ^caster} = AlBlessing.cast(caster, :self, 1, definition)
  end

  test "cast/4 applies sc_blessing with val1=level, val2=level at level 10" do
    {:ok, definition} = Catalog.by_id(34)
    caster = %{character_id: 2000}

    expect(StatusInterpreter, :apply_status, fn :player, 2000, :sc_blessing, params ->
      assert params[:val1] == 10
      assert params[:val2] == 10
      assert params[:caster_id] == 2000
      assert params[:duration] == 240_000
      :ok
    end)

    assert {:ok, ^caster} = AlBlessing.cast(caster, :self, 10, definition)
  end

  test "cast/4 propagates error from StatusInterpreter" do
    {:ok, definition} = Catalog.by_id(34)
    caster = %{character_id: 3000}

    expect(StatusInterpreter, :apply_status, fn :player, 3000, :sc_blessing, _params ->
      {:error, :already_applied}
    end)

    assert {:error, :already_applied} = AlBlessing.cast(caster, :self, 5, definition)
  end

  test "cast/4 halves an undead mob's STR, INT, DEX, and HIT through val2 zero" do
    {:ok, definition} = Catalog.by_id(34)
    caster = %{character_id: 4000}
    target_id = 5000

    stub(UnitRegistry, :unit_exists?, fn :mob, ^target_id -> true end)

    stub(TargetResolver, :resolve_combatant, fn :mob, ^target_id ->
      {:ok, %{race: :undead}}
    end)

    expect(StatusInterpreter, :apply_status, fn :mob, ^target_id, :sc_blessing, params ->
      assert params[:val1] == 10
      assert params[:val2] == 0
      assert params[:caster_id] == 4000
      :ok
    end)

    assert {:ok, ^caster} = AlBlessing.cast(caster, {:unit, target_id}, 10, definition)
  end

  test "cast/4 halves a mob with undead defense element through val2 zero" do
    {:ok, definition} = Catalog.by_id(34)
    caster = %{character_id: 4000}
    target_id = 5000

    stub(UnitRegistry, :unit_exists?, fn :mob, ^target_id -> true end)

    stub(TargetResolver, :resolve_combatant, fn :mob, ^target_id ->
      {:ok, %{race: :formless, element: {:undead, 1}}}
    end)

    expect(StatusInterpreter, :apply_status, fn :mob, ^target_id, :sc_blessing, params ->
      assert params[:val1] == 10
      assert params[:val2] == 0
      assert params[:caster_id] == 4000
      :ok
    end)

    assert {:ok, ^caster} = AlBlessing.cast(caster, {:unit, target_id}, 10, definition)
  end

  test "cast/4 resolves a colliding target id as the selected mob" do
    {:ok, definition} = Catalog.by_id(34)
    caster = %{character_id: 4_000}
    target_id = 5_000

    stub(UnitRegistry, :unit_exists?, fn :mob, ^target_id -> true end)
    reject(&TargetResolver.resolve_combatant/1)

    expect(TargetResolver, :resolve_combatant, fn :mob, ^target_id ->
      {:ok, %{race: :undead}}
    end)

    expect(StatusInterpreter, :apply_status, fn :mob, ^target_id, :sc_blessing, params ->
      assert params[:val2] == 0
      :ok
    end)

    assert {:ok, ^caster} = AlBlessing.cast(caster, {:unit, target_id}, 10, definition)
  end
end
