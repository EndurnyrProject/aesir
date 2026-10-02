defmodule Aesir.ZoneServer.Mmo.Skills.Paladin.PaGospelTest do
  use ExUnit.Case, async: false
  use Mimic

  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skill.Unit
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Group
  alias Aesir.ZoneServer.Mmo.Skills.Paladin.PaGospel
  alias Aesir.ZoneServer.Mmo.StatusEffect.Dispel
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.PlayerStateFixture
  alias Aesir.ZoneServer.Unit.Mob.MobState

  @caster_id 45_001

  setup :set_mimic_from_context
  setup :verify_on_exit!

  setup do
    Aesir.TestEtsSetup.setup_ets_tables(%{})
    Mimic.copy(Dispel)
    Mimic.copy(Unit)

    caster =
      PlayerStateFixture.build(%{
        character_id: @caster_id,
        x: 120,
        y: 80,
        map_name: "prontera",
        stats: %{current_state: %{sp: 500}}
      })

    {:ok, definition} = Catalog.by_name(:pa_gospel)
    %{caster: caster, definition: definition}
  end

  test "definition: 10 levels, 80/100 SP, 60 s, self-targeted ground skill", %{
    definition: definition
  } do
    assert definition.id == 369
    assert definition.max_level == 10
    assert definition.sp_cost == [80, 80, 80, 80, 80, 100, 100, 100, 100, 100]
    assert definition.duration == List.duplicate(60_000, 10)
    assert definition.target_type == :self
    assert {:ok, PaGospel} = Catalog.ground_module_for(:pa_gospel)
  end

  test "the footprint is a 33-cell thick cross centred on the caster" do
    cells = PaGospel.thick_cross({120, 80})

    assert length(cells) == 33
    assert length(Enum.uniq(cells)) == 33
    assert {120, 80} in cells
    assert {117, 80} in cells and {123, 80} in cells
    assert {120, 77} in cells and {120, 83} in cells
    assert {121, 78} in cells
    refute {122, 78} in cells
    refute {118, 77} in cells
  end

  test "on_place describes a 60 s field ticking every 10 s", %{caster: _caster} do
    group = %Group{group_id: 1, skill_name: :pa_gospel, center: {120, 80}, level: 3}

    assert {:ok, %{cells: cells, interval: 10_000, duration: 60_000, state: %{}}} =
             PaGospel.on_place(group)

    assert length(cells) == 33
  end

  test "casting wipes the caster's statuses, plants the field, and locks the caster", %{
    caster: caster,
    definition: definition
  } do
    group = %Group{group_id: 501, skill_name: :pa_gospel}

    expect(Dispel, :dispel, fn {:player, @caster_id} -> :ok end)
    expect(Unit, :place, fn ^caster, :pa_gospel, 4, {120, 80} -> {:ok, group} end)

    expect(Interpreter, :apply_status, fn :player, @caster_id, :sc_gospel, params ->
      assert params[:val1] == 4
      assert params[:val2] == 501
      assert params[:duration] == 60_000
      assert params[:caster_id] == @caster_id
      :ok
    end)

    assert {:ok, ^caster} = PaGospel.cast(caster, :self, 4, definition)
  end

  test "a failed lock tears the freshly placed field down", %{
    caster: caster,
    definition: definition
  } do
    stub(Dispel, :dispel, fn _target -> :ok end)

    stub(Unit, :place, fn _c, _n, _l, _cell ->
      {:ok, %Group{group_id: 502, skill_name: :pa_gospel}}
    end)

    stub(Interpreter, :apply_status, fn :player, _id, :sc_gospel, _p -> {:error, :prevented} end)
    expect(Unit, :destroy_async, fn 502 -> :ok end)

    assert {:error, :prevented} = PaGospel.cast(caster, :self, 1, definition)
  end

  test "recasting while chanting ends the chant for free", %{
    caster: caster,
    definition: definition
  } do
    :ok = StatusStorage.apply_status(:player, @caster_id, :sc_gospel, val1: 1, val2: 503)
    reject(&Dispel.dispel/1)
    reject(&Unit.place/4)
    expect(Interpreter, :remove_status, fn :player, @caster_id, :sc_gospel -> :ok end)

    assert PaGospel.dynamic_cost(caster, :self, 1, definition).sp == 0
    assert {:ok, ^caster} = PaGospel.cast(caster, :self, 1, definition)
  end

  test "the cost is the full SP when not chanting", %{caster: caster, definition: definition} do
    assert PaGospel.dynamic_cost(caster, :self, 6, definition).sp == 100
  end

  test "the field ending removes the caster lock" do
    group = %Group{group_id: 504, skill_name: :pa_gospel, caster_id: @caster_id}

    expect(Interpreter, :remove_status, fn :player,
                                           @caster_id,
                                           :sc_gospel,
                                           owner_refresh: :notify ->
      :ok
    end)

    assert :ok = PaGospel.on_expire(group)
  end

  test "a mob caster is refused", %{definition: definition} do
    assert {:error, :player_only} =
             PaGospel.cast(struct(MobState, instance_id: 9), :self, 1, definition)
  end
end
