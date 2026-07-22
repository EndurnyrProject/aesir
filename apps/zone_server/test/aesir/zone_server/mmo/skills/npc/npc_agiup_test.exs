defmodule Aesir.ZoneServer.Mmo.Skills.Npc.NpcAgiupTest do
  use ExUnit.Case, async: true
  import Mimic

  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skills.Npc.NpcAgiup
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter

  setup :verify_on_exit!

  @caster_id 9001

  describe "Catalog lookups" do
    test "by_id(350) resolves npc_agiup" do
      assert {:ok, definition} = Catalog.by_id(350)
      assert definition.name == :npc_agiup
    end

    test "by_name(:npc_agiup) resolves" do
      assert {:ok, definition} = Catalog.by_name(:npc_agiup)
      assert definition.id == 350
    end

    test "active_module_for/1 resolves npc_agiup" do
      assert {:ok, NpcAgiup} = Catalog.active_module_for(:npc_agiup)
    end
  end

  describe "cast/4" do
    setup do
      {:ok, definition} = Catalog.by_id(350)
      {:ok, definition: definition}
    end

    test "applies :sc_increaseagi to the casting mob with val1/val2=level",
         %{definition: definition} do
      caster = %{instance_id: @caster_id}

      expect(StatusInterpreter, :apply_status, fn :mob, @caster_id, :sc_increaseagi, params ->
        assert params[:val1] == 3
        assert params[:val2] == 3
        assert params[:caster_id] == @caster_id
        assert params[:source_id] == @caster_id
        :ok
      end)

      assert {:ok, ^caster} = NpcAgiup.cast(caster, {:unit, @caster_id}, 3, definition)
    end

    test "propagates an error from apply_status", %{definition: definition} do
      caster = %{instance_id: @caster_id}

      stub(StatusInterpreter, :apply_status, fn :mob, @caster_id, :sc_increaseagi, _params ->
        {:error, :immune}
      end)

      assert {:error, :immune} = NpcAgiup.cast(caster, {:unit, @caster_id}, 3, definition)
    end
  end
end
