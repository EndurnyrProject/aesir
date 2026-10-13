defmodule Aesir.ZoneServer.Mmo.Skills.Mage.MgThunderstormTest do
  use ExUnit.Case, async: false
  import Mimic

  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Group
  alias Aesir.ZoneServer.Mmo.Skills.Mage.MgThunderstorm

  setup :verify_on_exit!

  @caster_id 1000
  @map_name "prontera"
  @center {150, 150}

  @renewal_ratio 100
  @pre_renewal_ratio 80

  defp group(level, state \\ %{}) do
    %Group{
      group_id: 1,
      skill_id: 21,
      skill_name: :mg_thunderstorm,
      level: level,
      caster_id: @caster_id,
      caster_type: :player,
      map_name: @map_name,
      center: @center,
      cells: [],
      interval: 1_000,
      state: state
    }
  end

  defp stub_caster do
    stub(Combat, :resolve_combatant, fn @caster_id -> {:ok, %{unit_id: @caster_id}} end)
  end

  describe "skill data" do
    test "the cast time is slower and steeper per level in classic" do
      assert MgThunderstorm.definition(:renewal).cast_time ==
               [2700, 2900, 3100, 3300, 3500, 3700, 3900, 4100, 4300, 4500]

      assert MgThunderstorm.definition(:pre_renewal).cast_time ==
               [1000, 2000, 3000, 4000, 5000, 6000, 7000, 8000, 9000, 10_000]
    end
  end

  describe "skill_ratio/1" do
    test "renewal pulses at the full magic ratio" do
      assert MgThunderstorm.skill_ratio(:renewal) == @renewal_ratio
    end

    test "classic pulses at a reduced magic ratio" do
      assert MgThunderstorm.skill_ratio(:pre_renewal) == @pre_renewal_ratio
    end
  end

  describe "on_place/1" do
    test "returns one cell with a lifetime shorter than its strike interval" do
      assert {:ok, placement} = MgThunderstorm.on_place(group(10))
      assert placement.cells == [@center]
      refute Map.has_key?(placement, :initial_delay)
      assert placement.interval == 1_000
      assert placement.duration <= placement.interval
    end
  end

  describe "per-cell unit" do
    test "is one path-checked cell reaching two cells for one 100 ms pass" do
      assert {:ok, placement} = MgThunderstorm.on_place(group(10))
      assert placement.cells == [{150, 150}]
      assert %{unit_range: 2, path_check: true, duration: 100} = placement
    end

    test "a level 11 monster storm reaches three cells" do
      assert {:ok, %{unit_range: 3}} = MgThunderstorm.on_place(group(11))
    end
  end

  describe "on_unit_hit/4 - the burst" do
    @tag game_mode: :renewal
    test "delivers the level's whole hit count to each supplied target at once" do
      test_pid = self()
      stub_caster()

      stub(Combat, :apply_skill_unit_damage, fn caster,
                                                unit_type,
                                                target_id,
                                                21,
                                                7,
                                                :wind,
                                                @renewal_ratio,
                                                opts ->
        assert caster.unit_id == @caster_id
        send(test_pid, {:hit, unit_type, target_id, opts[:hit_divisions]})
        :ok
      end)

      assert {:ok, %Group{}} = MgThunderstorm.on_unit_hit(group(7), @center, {:mob, 2001}, 0)

      assert {:ok, %Group{}} = MgThunderstorm.on_unit_hit(group(7), @center, {:mob, 2002}, 0)
      assert_received {:hit, :mob, 2001, 7}
      assert_received {:hit, :mob, 2002, 7}
      refute_received {:hit, :player, @caster_id, _}
    end

    @tag game_mode: :pre_renewal
    test "bursts at the reduced classic ratio" do
      test_pid = self()
      stub_caster()

      stub(Combat, :apply_skill_unit_damage, fn _caster,
                                                _unit_type,
                                                target_id,
                                                21,
                                                7,
                                                :wind,
                                                @pre_renewal_ratio,
                                                opts ->
        send(test_pid, {:hit, target_id, opts[:hit_divisions]})
        :ok
      end)

      assert {:ok, %Group{}} = MgThunderstorm.on_unit_hit(group(7), @center, {:mob, 2001}, 0)
      assert_received {:hit, 2001, 7}
    end

    test "level 1 bursts for a single hit" do
      test_pid = self()
      stub_caster()

      stub(Combat, :apply_skill_unit_damage, fn _c, _ut, _tid, 21, 1, :wind, _ratio, opts ->
        send(test_pid, {:hits, opts[:hit_divisions]})
        :ok
      end)

      assert {:ok, %Group{}} = MgThunderstorm.on_unit_hit(group(1), @center, {:mob, 2001}, 0)
      assert_received {:hits, 1}
    end

    test "keeps no targets when the caster cannot be resolved" do
      stub(Combat, :resolve_combatant, fn @caster_id -> {:error, :target_not_found} end)

      reject(&Combat.splash_targets/4)
      reject(&Combat.apply_skill_unit_damage/8)

      assert [] = MgThunderstorm.unit_targets(group(3), @center, [{:mob, 2001}])
    end
  end
end
