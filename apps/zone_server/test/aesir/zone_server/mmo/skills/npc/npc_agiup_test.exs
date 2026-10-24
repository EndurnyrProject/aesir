defmodule Aesir.ZoneServer.Mmo.Skills.Npc.NpcAgiupTest do
  use ExUnit.Case, async: true
  import Mimic

  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skills.Npc.NpcAgiup
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.Player.PlayerState

  setup :verify_on_exit!

  @caster_id 9001

  setup do
    {:ok, definition} = Catalog.by_id(350)
    {:ok, definition: definition}
  end

  test "starts SC_AGIUP on the casting mob with a 50% haste, 100% FLEE and ten seconds per level",
       %{definition: definition} do
    caster = struct(MobState, instance_id: @caster_id)

    expect(StatusInterpreter, :apply_status, fn :mob, @caster_id, :sc_agiup, params ->
      assert {params[:val1], params[:val2], params[:duration]} == {50, 100, 30_000}
      assert params[:caster_id] == @caster_id
      :ok
    end)

    assert {:ok, ^caster} = NpcAgiup.cast(caster, {:unit, @caster_id}, 3, definition)
  end

  test "lands on a player caster's own unit", %{definition: definition} do
    caster = struct(PlayerState, character_id: 77)

    expect(StatusInterpreter, :apply_status, fn :player, 77, :sc_agiup, params ->
      assert params[:duration] == 100_000
      :ok
    end)

    assert {:ok, ^caster} = NpcAgiup.cast(caster, :self, 10, definition)
  end

  test "propagates an error from apply_status", %{definition: definition} do
    caster = struct(MobState, instance_id: @caster_id)

    stub(StatusInterpreter, :apply_status, fn :mob, @caster_id, :sc_agiup, _params ->
      {:error, :immune}
    end)

    assert {:error, :immune} = NpcAgiup.cast(caster, {:unit, @caster_id}, 3, definition)
  end
end
