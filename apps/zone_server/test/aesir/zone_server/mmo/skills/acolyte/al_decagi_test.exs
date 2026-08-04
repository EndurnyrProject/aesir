defmodule Aesir.ZoneServer.Mmo.Skills.Acolyte.AlDecagiTest do
  use ExUnit.Case, async: true
  import Mimic

  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skills.Acolyte.AlDecagi
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.UnitRegistry

  setup :verify_on_exit!

  @target_id 2000
  @caster %{character_id: 1000}

  defp definition do
    {:ok, definition} = Catalog.by_name(:al_decagi)
    definition
  end

  describe "catalog registration" do
    test "by_id(30) resolves al_decagi" do
      assert {:ok, %{name: :al_decagi}} = Catalog.by_id(30)
    end

    test "by_name(:al_decagi) resolves" do
      assert {:ok, %{id: 30}} = Catalog.by_name(:al_decagi)
    end
  end

  describe "cast/4 — landing roll hit" do
    # Seed {1,2,3} yields :rand.uniform(100) == 27, below any reasonable Decrease AGI rate.
    setup do
      :rand.seed(:exsss, {1, 2, 3})
      stub(UnitRegistry, :unit_exists?, fn :mob, @target_id -> true end)
      stub(PlayerState, :get_stats, fn _ -> %{base_level: 50, int: 50} end)
      {:ok, definition: definition()}
    end

    test "applies sc_decreaseagi with correct val1 and duration on hit",
         %{definition: definition} do
      # level=5, base_level=50, int=50: rate = 50 + 15 + div(100, 5) = 85; 27 <= 85 → hit
      expected_duration = Enum.at(definition.duration, 4)

      expect(StatusInterpreter, :apply_status, fn :mob, @target_id, :sc_decreaseagi, params ->
        assert params[:val1] == 5
        assert params[:caster_id] == 1000
        assert params[:duration] == expected_duration
        :ok
      end)

      assert {:ok, @caster} = AlDecagi.cast(@caster, {:unit, @target_id}, 5, definition)
    end

    test "applies level-1 duration (40_000 ms) on hit", %{definition: definition} do
      expect(StatusInterpreter, :apply_status, fn _unit_type,
                                                  @target_id,
                                                  :sc_decreaseagi,
                                                  params ->
        assert params[:duration] == 40_000
        assert params[:val1] == 1
        :ok
      end)

      assert {:ok, @caster} = AlDecagi.cast(@caster, {:unit, @target_id}, 1, definition)
    end

    test "applies level-10 duration (130_000 ms) on hit", %{definition: definition} do
      expect(StatusInterpreter, :apply_status, fn _unit_type,
                                                  @target_id,
                                                  :sc_decreaseagi,
                                                  params ->
        assert params[:duration] == 130_000
        assert params[:val1] == 10
        :ok
      end)

      assert {:ok, @caster} = AlDecagi.cast(@caster, {:unit, @target_id}, 10, definition)
    end

    test "canonical extended level 48 retains val1 and clamps duration to level 10",
         %{definition: definition} do
      expect(StatusInterpreter, :apply_status, fn _unit_type,
                                                  @target_id,
                                                  :sc_decreaseagi,
                                                  params ->
        assert params[:duration] == 130_000
        assert params[:val1] == 48
        :ok
      end)

      assert {:ok, @caster} = AlDecagi.cast(@caster, {:unit, @target_id}, 48, definition)
    end
  end

  describe "cast/4 — landing roll miss" do
    # Seed {6,7,8} yields :rand.uniform(100) == 87.
    # At level=5, base_level=50, int=50: rate = 85; 87 > 85 → miss.
    setup do
      :rand.seed(:exsss, {6, 7, 8})
      stub(PlayerState, :get_stats, fn _ -> %{base_level: 50, int: 50} end)
      {:ok, definition: definition()}
    end

    test "returns {:ok, caster} without applying status on miss", %{definition: definition} do
      reject(&StatusInterpreter.apply_status/4)

      assert {:ok, @caster} = AlDecagi.cast(@caster, {:unit, @target_id}, 5, definition)
    end
  end

  describe "cast/4 — rate formula" do
    # base_level=60, int=60, level=5:
    # rate = 50 + (3 * 5) + div(60 + 60, 5) = 50 + 15 + 24 = 89
    # Seed {6,7,8} gives 87; 87 <= 89 → hit at this higher stat level.
    # Contrast: same seed at base_level=50, int=50 gives miss (rate=85, 87>85).
    test "higher base_level/int raises rate enough to turn a miss into a hit" do
      :rand.seed(:exsss, {6, 7, 8})
      stub(UnitRegistry, :unit_exists?, fn :mob, @target_id -> true end)
      stub(PlayerState, :get_stats, fn _ -> %{base_level: 60, int: 60} end)

      expect(StatusInterpreter, :apply_status, fn :mob, @target_id, :sc_decreaseagi, params ->
        assert params[:val1] == 5
        :ok
      end)

      assert {:ok, @caster} = AlDecagi.cast(@caster, {:unit, @target_id}, 5, definition())
    end
  end

  describe "target unit type resolution" do
    setup do
      :rand.seed(:exsss, {1, 2, 3})
      stub(PlayerState, :get_stats, fn _ -> %{base_level: 50, int: 50} end)
      {:ok, definition: definition()}
    end

    test "mob target resolves to :mob", %{definition: definition} do
      stub(UnitRegistry, :unit_exists?, fn :mob, @target_id -> true end)

      expect(StatusInterpreter, :apply_status, fn unit_type,
                                                  @target_id,
                                                  :sc_decreaseagi,
                                                  _params ->
        assert unit_type == :mob
        :ok
      end)

      AlDecagi.cast(@caster, {:unit, @target_id}, 5, definition)
    end

    test "player target resolves to :player", %{definition: definition} do
      stub(UnitRegistry, :unit_exists?, fn :mob, @target_id -> false end)

      expect(StatusInterpreter, :apply_status, fn unit_type,
                                                  @target_id,
                                                  :sc_decreaseagi,
                                                  _params ->
        assert unit_type == :player
        :ok
      end)

      AlDecagi.cast(@caster, {:unit, @target_id}, 5, definition)
    end
  end
end
