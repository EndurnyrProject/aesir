defmodule Aesir.ZoneServer.Mmo.Skills.AlCrucisTest do
  use ExUnit.Case, async: true
  import Mimic

  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skills.AlCrucis
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.SpatialIndex

  setup :verify_on_exit!

  @caster %{character_id: 1000}
  @caster_pos {:ok, {100, 100, "prontera"}}
  @caster_base_level 50
  @map "prontera"
  @center {100, 100}
  @radius 15

  defp definition do
    {:ok, definition} = Catalog.by_name(:al_crucis)
    definition
  end

  defp make_combatant(base_level) do
    %{progression: %{base_level: base_level}}
  end

  describe "catalog registration" do
    test "by_id(32) resolves al_crucis" do
      assert {:ok, %{name: :al_crucis}} = Catalog.by_id(32)
    end

    test "by_name(:al_crucis) resolves" do
      assert {:ok, %{id: 32}} = Catalog.by_name(:al_crucis)
    end
  end

  describe "cast/4 — no targets" do
    setup do
      stub(PlayerState, :get_stats, fn _ -> %{base_level: @caster_base_level} end)
      stub(SpatialIndex, :get_unit_position, fn :player, 1000 -> @caster_pos end)
      stub(Combat, :splash_targets, fn @map, @center, @radius, 1000 -> [] end)
      :ok
    end

    test "returns {:ok, caster} with empty splash" do
      reject(&StatusInterpreter.apply_status/4)
      assert {:ok, @caster} = AlCrucis.cast(@caster, :self, 5, definition())
    end

    test "returns {:ok, caster} when caster position not found" do
      stub(SpatialIndex, :get_unit_position, fn :player, 1000 -> {:error, :not_found} end)
      reject(&StatusInterpreter.apply_status/4)
      assert {:ok, @caster} = AlCrucis.cast(@caster, :self, 5, definition())
    end
  end

  describe "cast/4 — landing roll hit" do
    # Seed {1, 2, 3} yields :rand.uniform(100) == 27 on the first draw.
    # caster_base_level=50, target_base_level=10, level=5 → rate = 25 + 20 + 40 = 85
    # 27 <= 85 → hit.
    setup do
      :rand.seed(:exsss, {1, 2, 3})
      stub(PlayerState, :get_stats, fn _ -> %{base_level: @caster_base_level} end)
      stub(SpatialIndex, :get_unit_position, fn :player, 1000 -> @caster_pos end)
      stub(Combat, :resolve_combatant, fn _id -> {:ok, make_combatant(10)} end)
      :ok
    end

    test "applies sc_signumcrucis with correct val1 and val2 on hit" do
      stub(Combat, :splash_targets, fn @map, @center, @radius, 1000 -> [{:mob, 2001}] end)

      expect(StatusInterpreter, :apply_status, fn :mob, 2001, :sc_signumcrucis, params ->
        assert params[:val1] == 5
        assert params[:val2] == 30
        assert params[:caster_id] == 1000
        :ok
      end)

      assert {:ok, @caster} = AlCrucis.cast(@caster, :self, 5, definition())
    end

    test "val2 is 10 + 4 * level — level 1 gives val2=14" do
      stub(Combat, :splash_targets, fn @map, @center, @radius, 1000 -> [{:mob, 2001}] end)

      expect(StatusInterpreter, :apply_status, fn :mob, 2001, :sc_signumcrucis, params ->
        assert params[:val2] == 14
        :ok
      end)

      assert {:ok, @caster} = AlCrucis.cast(@caster, :self, 1, definition())
    end

    test "val2 is 10 + 4 * level — level 10 gives val2=50" do
      stub(Combat, :splash_targets, fn @map, @center, @radius, 1000 -> [{:mob, 2001}] end)

      expect(StatusInterpreter, :apply_status, fn :mob, 2001, :sc_signumcrucis, params ->
        assert params[:val2] == 50
        :ok
      end)

      assert {:ok, @caster} = AlCrucis.cast(@caster, :self, 10, definition())
    end

    test "apply_status is called without a duration key (permanent)" do
      stub(Combat, :splash_targets, fn @map, @center, @radius, 1000 -> [{:mob, 2001}] end)

      expect(StatusInterpreter, :apply_status, fn :mob, 2001, :sc_signumcrucis, params ->
        refute Keyword.has_key?(params, :duration)
        :ok
      end)

      assert {:ok, @caster} = AlCrucis.cast(@caster, :self, 5, definition())
    end
  end

  describe "cast/4 — landing roll miss" do
    # Seed {6, 7, 8} yields :rand.uniform(100) == 87 on the first draw.
    # caster_base_level=50, target_base_level=10, level=5 → rate = 85; 87 > 85 → miss.
    setup do
      :rand.seed(:exsss, {6, 7, 8})
      stub(PlayerState, :get_stats, fn _ -> %{base_level: @caster_base_level} end)
      stub(SpatialIndex, :get_unit_position, fn :player, 1000 -> @caster_pos end)
      stub(Combat, :splash_targets, fn @map, @center, @radius, 1000 -> [{:mob, 2001}] end)
      stub(Combat, :resolve_combatant, fn _id -> {:ok, make_combatant(10)} end)
      :ok
    end

    test "does not apply status on miss, returns {:ok, caster}" do
      reject(&StatusInterpreter.apply_status/4)
      assert {:ok, @caster} = AlCrucis.cast(@caster, :self, 5, definition())
    end
  end

  describe "cast/4 — two targets, one hit one miss" do
    # Seed {1, 2, 3}: first rand=27.
    # Target 2001, base_level=10: rate = 25 + 20 + (50-10) = 85 → 27 <= 85 → HIT.
    # Target 2002, base_level=200: rate = 25 + 20 + (50-200) = -105 → always miss.
    setup do
      :rand.seed(:exsss, {1, 2, 3})
      stub(PlayerState, :get_stats, fn _ -> %{base_level: @caster_base_level} end)
      stub(SpatialIndex, :get_unit_position, fn :player, 1000 -> @caster_pos end)

      stub(Combat, :splash_targets, fn @map, @center, @radius, 1000 ->
        [{:mob, 2001}, {:mob, 2002}]
      end)

      stub(Combat, :resolve_combatant, fn
        2001 -> {:ok, make_combatant(10)}
        2002 -> {:ok, make_combatant(200)}
      end)

      :ok
    end

    test "apply_status called only for the target that passes the roll" do
      expect(StatusInterpreter, :apply_status, fn :mob, 2001, :sc_signumcrucis, params ->
        assert params[:val2] == 30
        :ok
      end)

      assert {:ok, @caster} = AlCrucis.cast(@caster, :self, 5, definition())
    end
  end

  describe "cast/4 — rate formula" do
    # caster_base_level=50, level=5.
    # Seed {6, 7, 8} → first rand=87.
    # target_base_level=10:  rate = 85 → miss (87 > 85).
    # target_base_level=5:   rate = 90 → hit  (87 <= 90).
    # This shows a lower-level target is easier to land on.
    test "lower target base_level raises the rate enough to turn a miss into a hit" do
      :rand.seed(:exsss, {6, 7, 8})
      stub(PlayerState, :get_stats, fn _ -> %{base_level: @caster_base_level} end)
      stub(SpatialIndex, :get_unit_position, fn :player, 1000 -> @caster_pos end)
      stub(Combat, :splash_targets, fn @map, @center, @radius, 1000 -> [{:mob, 2001}] end)
      stub(Combat, :resolve_combatant, fn 2001 -> {:ok, make_combatant(5)} end)

      expect(StatusInterpreter, :apply_status, fn :mob, 2001, :sc_signumcrucis, _params ->
        :ok
      end)

      assert {:ok, @caster} = AlCrucis.cast(@caster, :self, 5, definition())
    end

    test "higher target base_level lowers the rate and causes a miss" do
      :rand.seed(:exsss, {6, 7, 8})
      stub(PlayerState, :get_stats, fn _ -> %{base_level: @caster_base_level} end)
      stub(SpatialIndex, :get_unit_position, fn :player, 1000 -> @caster_pos end)
      stub(Combat, :splash_targets, fn @map, @center, @radius, 1000 -> [{:mob, 2001}] end)
      stub(Combat, :resolve_combatant, fn 2001 -> {:ok, make_combatant(10)} end)

      reject(&StatusInterpreter.apply_status/4)
      assert {:ok, @caster} = AlCrucis.cast(@caster, :self, 5, definition())
    end
  end
end
