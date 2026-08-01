defmodule Aesir.ZoneServer.Mmo.Skills.Hunter.HunterTrapMatrixTest do
  @moduledoc """
  Table-driven guard over the ten Hunter floor traps.

  One canonical row per trap holds the values the renewal skill tables specify:
  catalog identity, level cap, SP and catalyst cost, the armed duration table,
  placement visibility, cast timing, effect radius and the manager-owned trap
  lifecycle metadata. Every value is read back from `Skill.Catalog` and from the
  module's own `on_place/1` placement, so a silent edit to any single trap
  module fails here instead of only in that trap's own test.
  """
  use ExUnit.Case, async: true

  import Mimic

  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Group
  alias Aesir.ZoneServer.Mmo.Skill.Unit.TrapState
  alias Aesir.ZoneServer.Mmo.Skills.Hunter.HtAnklesnare
  alias Aesir.ZoneServer.Mmo.Skills.Hunter.HtBlastmine
  alias Aesir.ZoneServer.Mmo.Skills.Hunter.HtClaymoretrap
  alias Aesir.ZoneServer.Mmo.Skills.Hunter.HtFlasher
  alias Aesir.ZoneServer.Mmo.Skills.Hunter.HtFreezingtrap
  alias Aesir.ZoneServer.Mmo.Skills.Hunter.HtLandmine
  alias Aesir.ZoneServer.Mmo.Skills.Hunter.HtSandman
  alias Aesir.ZoneServer.Mmo.Skills.Hunter.HtShockwave
  alias Aesir.ZoneServer.Mmo.Skills.Hunter.HtSkidtrap
  alias Aesir.ZoneServer.Mmo.Skills.Hunter.HtTalkiebox
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @caster_id 7000
  @center {50, 50}
  @trap_item 1065

  # Traps whose placement carries a variable cast bar; every other trap places
  # instantly.
  @timed_cast %{
    cast_time: List.duplicate(500, 5),
    fixed_cast_time: List.duplicate(300, 5),
    after_cast_delay: List.duplicate(1_000, 5)
  }

  @instant_cast %{cast_time: [], fixed_cast_time: [], after_cast_delay: []}

  @traps [
    %{
      module: HtSkidtrap,
      name: :ht_skidtrap,
      id: 115,
      max_level: 5,
      sp: 10,
      items: 1,
      durations: [300_000, 240_000, 180_000, 120_000, 60_000],
      visibility: :party_only,
      splash_radius: 0,
      cast: @instant_cast,
      natural_expiry: :drop_item,
      claymore_spendable?: false
    },
    %{
      module: HtLandmine,
      name: :ht_landmine,
      id: 116,
      max_level: 5,
      sp: 10,
      items: 1,
      durations: [200_000, 160_000, 120_000, 80_000, 40_000],
      visibility: :party_only,
      splash_radius: 0,
      cast: @timed_cast,
      natural_expiry: :drop_item,
      claymore_spendable?: true
    },
    %{
      module: HtAnklesnare,
      name: :ht_anklesnare,
      id: 117,
      max_level: 5,
      sp: 12,
      items: 1,
      durations: [250_000, 200_000, 150_000, 100_000, 50_000],
      visibility: :party_only,
      splash_radius: 0,
      cast: @instant_cast,
      natural_expiry: :drop_item,
      claymore_spendable?: false
    },
    %{
      module: HtShockwave,
      name: :ht_shockwave,
      id: 118,
      max_level: 5,
      sp: 45,
      items: 2,
      durations: [200_000, 160_000, 120_000, 80_000, 40_000],
      visibility: :party_only,
      splash_radius: 0,
      cast: @instant_cast,
      natural_expiry: :drop_item,
      claymore_spendable?: true
    },
    %{
      module: HtSandman,
      name: :ht_sandman,
      id: 119,
      max_level: 5,
      sp: 12,
      items: 1,
      durations: [150_000, 120_000, 90_000, 60_000, 30_000],
      visibility: :party_only,
      splash_radius: 2,
      cast: @instant_cast,
      natural_expiry: :drop_item,
      claymore_spendable?: true
    },
    %{
      module: HtFlasher,
      name: :ht_flasher,
      id: 120,
      max_level: 5,
      sp: 12,
      items: 2,
      durations: [150_000, 120_000, 90_000, 60_000, 30_000],
      visibility: :party_only,
      splash_radius: 0,
      cast: @instant_cast,
      natural_expiry: :drop_item,
      claymore_spendable?: true
    },
    %{
      module: HtFreezingtrap,
      name: :ht_freezingtrap,
      id: 121,
      max_level: 5,
      sp: 10,
      items: 2,
      durations: [150_000, 120_000, 90_000, 60_000, 30_000],
      visibility: :party_only,
      splash_radius: 1,
      cast: @instant_cast,
      natural_expiry: :drop_item,
      claymore_spendable?: true
    },
    %{
      module: HtBlastmine,
      name: :ht_blastmine,
      id: 122,
      max_level: 5,
      sp: 10,
      items: 2,
      durations: [25_000, 20_000, 15_000, 10_000, 5_000],
      visibility: :public,
      splash_radius: 1,
      cast: @timed_cast,
      natural_expiry: :become_used,
      claymore_spendable?: true
    },
    %{
      module: HtClaymoretrap,
      name: :ht_claymoretrap,
      id: 123,
      max_level: 5,
      sp: 15,
      items: 2,
      durations: [20_000, 40_000, 60_000, 80_000, 100_000],
      visibility: :public,
      splash_radius: 2,
      cast: @timed_cast,
      natural_expiry: :become_used,
      claymore_spendable?: true
    },
    %{
      module: HtTalkiebox,
      name: :ht_talkiebox,
      id: 125,
      max_level: 1,
      sp: 1,
      items: 1,
      durations: [600_000],
      visibility: :party_only,
      splash_radius: 0,
      cast: @instant_cast,
      natural_expiry: :drop_item,
      claymore_spendable?: false
    }
  ]

  setup :verify_on_exit!

  setup do
    stub(UnitRegistry, :get_unit_info, fn :player, @caster_id ->
      {:ok, %{stats: %{dex: 50, int: 40, base_level: 50}}}
    end)

    :ok
  end

  test "the trap matrix covers every catalogued Hunter floor trap exactly once" do
    covered = MapSet.new(@traps, & &1.name)

    catalogued =
      Catalog.all()
      |> Enum.filter(
        &(&1.item_cost == [%{id: @trap_item, amount: 1}] or
            &1.item_cost == [%{id: @trap_item, amount: 2}])
      )
      |> MapSet.new(& &1.name)

    assert covered == catalogued
    assert MapSet.size(covered) == 10
  end

  for trap <- @traps do
    @trap trap
    @natural_expiry_callback? trap.natural_expiry == :become_used

    describe "#{trap.name}" do
      test "declares its canonical catalog row" do
        assert {:ok, definition} = Catalog.by_name(@trap.name)
        assert Catalog.ground_module_for(@trap.name) == {:ok, @trap.module}

        assert definition.id == @trap.id
        assert definition.name == @trap.name
        assert definition.max_level == @trap.max_level
        assert definition.target_type == :ground
        assert definition.range == 3
        assert definition.hit_interval == 1_000
        assert definition.splash_radius == @trap.splash_radius
        assert definition.unit_duration == @trap.durations
        assert length(definition.unit_duration) == @trap.max_level

        assert definition.sp_cost == List.duplicate(@trap.sp, @trap.max_level)
        assert definition.item_cost == [%{id: @trap_item, amount: @trap.items}]

        assert definition.cast_time == @trap.cast.cast_time
        assert definition.fixed_cast_time == @trap.cast.fixed_cast_time
        assert definition.after_cast_delay == @trap.cast.after_cast_delay
      end

      test "places one hidden-or-visible cell with its level's armed duration" do
        for level <- 1..@trap.max_level do
          assert {:ok, placement} = @trap.module.on_place(group(@trap.name, level))

          assert placement.cells == [@center]
          assert placement.visibility == @trap.visibility
          assert placement.interval == 1_000
          assert placement.duration == Enum.at(@trap.durations, level - 1)
          assert placement.state.ignore_land_protector == true
        end
      end

      test "stamps the manager-owned trap lifecycle metadata" do
        assert {:ok, placement} = @trap.module.on_place(group(@trap.name, 1))

        assert %TrapState{
                 phase: :armed,
                 reclaim_item_id: @trap_item,
                 natural_expiry: natural_expiry,
                 claymore_spendable?: claymore_spendable?,
                 link_id: nil
               } = placement.state.trap

        assert natural_expiry == @trap.natural_expiry
        assert claymore_spendable? == @trap.claymore_spendable?
      end

      test "only a natural become_used trap owns a natural-expiry callback" do
        Code.ensure_loaded!(@trap.module)

        assert function_exported?(@trap.module, :on_natural_expiry, 1) ==
                 @natural_expiry_callback?
      end
    end
  end

  defp group(skill_name, level) do
    %Group{
      group_id: 1,
      skill_name: skill_name,
      level: level,
      caster_id: @caster_id,
      caster_type: :player,
      map_name: "prontera",
      center: @center,
      cells: [@center],
      next_tick_at: 0,
      expires_at: 0,
      interval: 1_000,
      state: %{cast_origin: :normal, paid_return?: true}
    }
  end
end
