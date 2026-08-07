defmodule Aesir.ZoneServer.Integration.AssassinMobCastIntegrationTest do
  use Aesir.ZoneServer.IntegrationCase

  @moduletag :integration
  @moduletag :capture_log

  alias Aesir.ZoneServer.Mmo.Combat.HitCalculations
  alias Aesir.ZoneServer.Mmo.MobSkill.Db
  alias Aesir.ZoneServer.Mmo.MobSkill.Selector
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Group
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Storage
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit.Mob.Handlers.CastingHandler
  alias Aesir.ZoneServer.Unit.Mob.MobState

  @map "prontera"
  @cloaking_mob_id 3_230
  @sonic_blow_mob_id 2_475
  @grimtooth_mob_id 1_304
  @venom_dust_mob_id 2_850
  @splasher_mob_id 3_740

  setup :set_mimic_private
  setup :verify_on_exit!

  setup do
    Mimic.copy(HitCalculations)
    stub(HitCalculations, :calculate_hit_result, fn _attacker, _target -> :hit end)
    :ok
  end

  test "Gertie Wie selects and completes her level 1 Cloaking row without player state" do
    row = row!(@cloaking_mob_id, "AS_CLOAKING", state: :attack)
    assert_row(row, level: 1, target: :self, cast_time: 200, delay: 10_000, rate: 200)
    assert definition!(135).target_type == :self

    mob = spawn_test_mob(@map, {150, 150}, mob_id: @cloaking_mob_id)
    caster_id = get_mob_state(mob.pid).instance_id
    on_exit(fn -> StatusStorage.clear_unit_statuses(:mob, caster_id) end)

    drive_selected_cast(mob, row)

    assert_eventually(fn ->
      case StatusStorage.get_status(:mob, caster_id, :sc_cloaking) do
        %{val1: 1, source_id: ^caster_id, source_type: :mob, state: state} = status ->
          status.expires_at - status.started_at == 10_000 and
            state == %{adjacent_impassable?: false}

        _other ->
          false
      end
    end)
  end

  test "Corrupted Soul and Giant Spider execute Sonic Blow and Grimtooth at imported levels" do
    target =
      start_player_session(
        id: 9_871,
        name: "AssassinMobTarget",
        map_name: @map,
        position: {151, 150},
        hp: 1_000_000,
        max_hp: 1_000_000
      )

    target_id = target.character.id
    initial_hp = current_hp(target.pid)

    sonic_row = row!(@sonic_blow_mob_id, "AS_SONICBLOW", state: :attack)
    assert_row(sonic_row, level: 10, target: :target, cast_time: 800, delay: 5_000, rate: 500)
    assert definition!(136).range == 1

    sonic = spawn_test_mob(@map, {150, 150}, mob_id: @sonic_blow_mob_id)
    Mimic.allow(HitCalculations, self(), sonic.pid)
    drive_selected_cast(sonic, sonic_row, {:player, target_id})
    assert_eventually(fn -> current_hp(target.pid) < initial_hp end, 2_000)

    after_sonic = current_hp(target.pid)
    grimtooth_row = row!(@grimtooth_mob_id, "AS_GRIMTOOTH", state: :chase)

    assert_row(grimtooth_row,
      level: 5,
      target: :target,
      cast_time: 0,
      delay: 5_000,
      rate: 2_000
    )

    assert Enum.at(definition!(137).range, grimtooth_row.level - 1) == 7

    grimtooth = spawn_test_mob(@map, {144, 150}, mob_id: @grimtooth_mob_id)
    Mimic.allow(HitCalculations, self(), grimtooth.pid)
    drive_selected_cast(grimtooth, grimtooth_row, {:player, target_id})

    assert_eventually(fn -> current_hp(target.pid) < after_sonic end)
  end

  test "Dolomedes Ringleader places Venom Dust without a gemstone or player resources" do
    target =
      start_player_session(
        id: 9_872,
        name: "VenomDustTarget",
        map_name: @map,
        position: {151, 150},
        sp: 777,
        max_sp: 777
      )

    row = row!(@venom_dust_mob_id, "AS_VENOMDUST", state: :angry)
    assert_row(row, level: 1, target: :target, cast_time: 1_500, delay: 5_000, rate: 500)
    assert definition!(140).range == 2

    mob = spawn_test_mob(@map, {150, 150}, mob_id: @venom_dust_mob_id)
    caster_id = get_mob_state(mob.pid).instance_id
    sp_before = current_sp(target.pid)

    drive_selected_cast(mob, row, {:player, target.character.id})

    assert_eventually(
      fn ->
        Enum.any?(Storage.all(), fn
          %Group{skill_name: :as_venomdust, caster_type: :mob, caster_id: ^caster_id} = group ->
            group.level == 1 and group.expires_at - group.created_at == 5_000 and
              length(group.cells) == 5

          _other ->
            false
        end)
      end,
      2_500
    )

    assert current_sp(target.pid) == sp_before

    Storage.all()
    |> Enum.filter(&(&1.caster_type == :mob and &1.caster_id == caster_id))
    |> Enum.each(&Storage.delete(&1.group_id))
  end

  test "Gaster selects its real Venom Splasher row without a learned passive" do
    target =
      start_player_session(
        id: 9_873,
        name: "SplasherTarget",
        map_name: @map,
        position: {151, 150},
        sp: 555,
        max_sp: 555
      )

    row = row!(@splasher_mob_id, "AS_SPLASHER", state: :attack)
    assert_row(row, level: 5, target: :target, cast_time: 0, delay: 5_000, rate: 100)
    assert definition!(141).range == 1

    mob = spawn_test_mob(@map, {150, 150}, mob_id: @splasher_mob_id)
    caster_id = get_mob_state(mob.pid).instance_id
    target_id = target.character.id
    sp_before = current_sp(target.pid)
    on_exit(fn -> StatusStorage.clear_unit_statuses(:player, target_id) end)

    drive_selected_cast(mob, row, {:player, target_id})

    assert %{
             val1: 5,
             source_id: ^caster_id,
             source_type: :mob,
             state: %{remaining_ms: 7_000, poison_react_level: 0}
           } = StatusStorage.get_status(:player, target_id, :sc_splasher)

    assert current_sp(target.pid) == sp_before
  end

  defp row!(mob_id, skill, filters) do
    row =
      Enum.find(Db.rows_for(mob_id), fn row ->
        row.skill == skill and
          Enum.all?(filters, fn {key, value} -> Map.fetch!(row, key) == value end)
      end)

    assert row != nil, "mob #{mob_id} must retain its #{skill} fixture row"
    row
  end

  defp assert_row(row, expected) do
    Enum.each(expected, fn {key, value} -> assert Map.fetch!(row, key) == value end)
    assert row.condition.type == :always
    assert row.condition.value == 0
  end

  defp drive_selected_cast(mob, row, target_ref \\ nil) do
    test_pid = self()
    now = System.system_time(:millisecond)

    :sys.replace_state(mob.pid, fn state ->
      state = prepare_state(state, row.state, target_ref)
      selected = Selector.select(state, [row], now: now, rng: fn _maximum -> 1 end)
      send(test_pid, {:selected_assassin_row, selected})

      case selected do
        {:cast, selected_row} ->
          {:ok, updated} = CastingHandler.begin_cast(state, selected_row, now)
          updated

        nil ->
          state
      end
    end)

    assert_receive {:selected_assassin_row, {:cast, ^row}}

    if row.cast_time > 0 do
      assert %{casting: %{row: ^row, complete_at: complete_at}} = :sys.get_state(mob.pid)
      assert complete_at == now + row.cast_time
      send(mob.pid, {:casting, :complete})
    end
  end

  defp prepare_state(state, row_state, target_ref) do
    {ai_state, initiated_by_self?} =
      case row_state do
        :attack -> {:combat, false}
        :angry -> {:combat, true}
        :chase -> {:chase, false}
        :idle -> {:idle, false}
      end

    state = %{state | ai_state: ai_state, initiated_by_self?: initiated_by_self?}

    case target_ref do
      nil ->
        state

      {target_type, target_id} ->
        state
        |> MobState.set_target(target_id)
        |> Map.put(:target_ref, {target_type, target_id})
    end
  end

  defp definition!(skill_id) do
    assert {:ok, definition} = Catalog.by_id(skill_id)
    definition
  end

  defp current_hp(pid), do: get_player_state(pid).stats.current_state.hp
  defp current_sp(pid), do: get_player_state(pid).stats.current_state.sp
end
