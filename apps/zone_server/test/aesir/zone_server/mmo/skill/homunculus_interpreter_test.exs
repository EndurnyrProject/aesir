defmodule Aesir.ZoneServer.Mmo.Skill.HomunculusInterpreterTest do
  use ExUnit.Case, async: false

  import Aesir.TestEtsSetup
  import Mimic

  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skill.Definition
  alias Aesir.ZoneServer.Mmo.Skill.Interpreter
  alias Aesir.ZoneServer.Mmo.Skills.Homunculus.HlifAvoid
  alias Aesir.ZoneServer.Mmo.Skills.Homunculus.HlifBrain
  alias Aesir.ZoneServer.Mmo.Skills.Homunculus.HlifChange
  alias Aesir.ZoneServer.Mmo.Skills.Homunculus.HlifHeal
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit.Homunculus.Handlers.CastingHandler
  alias Aesir.ZoneServer.Unit.Homunculus.HomunculusState
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.SessionState
  alias Aesir.ZoneServer.Unit.Player.Stats, as: PlayerStats
  alias Aesir.ZoneServer.Unit.Player.Stats.PlayerProgression
  alias Aesir.ZoneServer.Unit.SpatialIndex
  alias Aesir.ZoneServer.Unit.Stats.BaseStats
  alias Aesir.ZoneServer.Unit.Stats.CombatStats
  alias Aesir.ZoneServer.Unit.Stats.CurrentState
  alias Aesir.ZoneServer.Unit.Stats.DerivedStats
  alias Aesir.ZoneServer.Unit.UnitRegistry

  defmodule MalformedCasterResultSkill do
    @behaviour Aesir.ZoneServer.Mmo.Skill.Active

    @impl true
    def cast(_caster, _target, _level, _definition), do: {:ok, %{}}

    @impl true
    def validate(_caster, _target, _level, _definition), do: :ok
  end

  defmodule AutoCastProbeSkill do
    @behaviour Aesir.ZoneServer.Mmo.Skill.Active

    @impl true
    def cast(caster, :self, 1, _definition) do
      send(self(), {:auto_cast_sp, caster.sp})
      {:ok, caster}
    end

    @impl true
    def validate(_caster, _target, _level, _definition), do: :ok
  end

  setup :setup_ets_tables
  setup :verify_on_exit!

  setup do
    on_exit(&Catalog.reload/0)
    Catalog.reload()
    :ok
  end

  test "catalog discovers the production Lif kit with canonical definitions" do
    assert {:ok, %{id: 8_001, target_type: :self, item_cost: [%{id: 545, amount: 1}]}} =
             Catalog.by_name(:hlif_heal)

    assert {:ok, HlifHeal} = Catalog.active_module_for(:hlif_heal)
    assert {:ok, HlifAvoid} = Catalog.active_module_for(:hlif_avoid)
    assert {:ok, HlifChange} = Catalog.active_module_for(:hlif_change)
    assert :error = Catalog.active_module_for(:hlif_brain)

    assert HlifHeal.definition().sp_cost == [13, 16, 19, 22, 25]
    assert HlifHeal.definition().cooldown == List.duplicate(20_000, 5)
    assert HlifAvoid.definition().sp_cost == [20, 25, 30, 35, 40]
    assert HlifAvoid.definition().cooldown == List.duplicate(35_000, 5)
    assert HlifAvoid.definition().duration == [40_000, 35_000, 30_000, 25_000, 20_000]
    assert HlifBrain.definition().target_type == :passive
    assert HlifChange.definition().sp_cost == [100, 100, 100]
    assert HlifChange.definition().duration == [60_000, 180_000, 300_000]
    assert HlifChange.definition().cooldown == [600_000, 900_000, 1_200_000]
    assert {:ok, %{id: 8_005, name: :hami_castle}} = Catalog.by_id(8_005)
    assert :error = Catalog.by_id(8_017)
  end

  test "auto-cast charges a Homunculus only two thirds SP and skips other requirements" do
    definition = %Definition{
      id: 9_999_901,
      name: :auto_cast_probe,
      display_name: "Auto Cast Probe",
      max_level: 1,
      target_type: :self,
      damage_type: :no_damage,
      requires: [:player_state, :inventory, :zeny],
      sp_cost: [12],
      zeny_cost: [100],
      item_cost: [%{id: 716, amount: 1}],
      requires_ammo: true
    }

    stub(Catalog, :by_id, fn
      9_999_901 -> {:ok, definition}
      other -> call_original(Catalog, :by_id, [other])
    end)

    stub(Catalog, :active_module_for, fn
      :auto_cast_probe -> {:ok, AutoCastProbeSkill}
      other -> call_original(Catalog, :active_module_for, [other])
    end)

    assert {:ok, updated} = Interpreter.auto_cast(homunculus(), definition.id, 1, :self)
    assert updated.sp == 92
    assert_received {:auto_cast_sp, 100}
  end

  test "Healing Touch returns the exact owner cost marker and owner-only heal" do
    caster = homunculus(%{level: 20, int: 5, learned_skills: %{8_001 => 5, 8_003 => 3}})
    caster = %{caster | combat_stats: %{caster.combat_stats | matk_min: 77, matk_max: 77}}
    register_active(caster, owner())

    assert {:instant, updated, effects} =
             Interpreter.begin_cast(caster, 8_001, 5, :self)

    assert updated.sp == 75
    assert updated.cooldowns[8_001] > System.monotonic_time(:millisecond)

    assert effects == [
             {:owner_item_cost, 545, 1},
             {:player, {:apply_heal, 156, {:homunculus, caster.world_gid}}}
           ]
  end

  test "restricted begin rejects caster, species, rank, SP, cooldown, passive, and target errors" do
    now = System.monotonic_time(:millisecond)
    caster = homunculus()

    for {updated, expected} <- [
          {%{caster | lifecycle: :dead, hp: 0, action_state: :dead}, :dead},
          {%{caster | movement_state: :moving}, :moving},
          {%{caster | action_state: :attacking}, :busy},
          {%{caster | class_id: 6_002}, :wrong_species},
          {%{caster | learned_skills: %{}}, :skill_not_learned},
          {%{caster | sp: 12}, :insufficient_sp},
          {%{caster | cooldowns: %{8_001 => now + 10_000}}, :on_cooldown}
        ] do
      assert {:error, ^expected} =
               Interpreter.begin_cast(updated, 8_001, 1, :self)
    end

    assert {:error, :skill_not_learned} =
             Interpreter.begin_cast(caster, 8_001, 2, :self)

    assert {:error, :passive_skill} =
             Interpreter.begin_cast(caster, 8_003, 1, :self)

    register_active(caster, owner())

    assert {:error, :invalid_target} =
             Interpreter.begin_cast(caster, 8_001, 1, {:unit, {:player, 100}})

    assert {:error, :unknown_skill} =
             Interpreter.begin_cast(caster, 8_017, 1, :self)
  end

  test "learned Mental Change remains castable after intimacy falls but requires evolved form" do
    original = homunculus(%{learned_skills: %{8_004 => 1}, sp: 100, intimacy_hundredths: 0})
    evolved = %{original | class_id: 6_009}
    register_active(evolved, owner())

    assert {:error, :skill_not_learned} =
             Interpreter.begin_cast(original, 8_004, 1, :self)

    assert {:instant, updated, []} =
             Interpreter.begin_cast(evolved, 8_004, 1, :self)

    assert updated.sp == 0
    assert StatusStorage.has_status?(:homunculus, evolved.world_gid, :sc_change)
  end

  test "completion revalidates definition level and active kind" do
    caster = homunculus(%{action_state: :casting, learned_skills: %{8_001 => 99, 8_003 => 1}})

    assert {:error, :invalid_level} =
             Interpreter.complete_cast(caster, 8_001, 99, :self)

    assert {:error, :passive_skill} =
             Interpreter.complete_cast(caster, 8_003, 1, :self)
  end

  test "malformed caster results return the restricted-path fail-safe" do
    caster = homunculus(%{action_state: :casting})
    register_active(caster, owner())

    stub(Catalog, :active_module_for, fn :hlif_heal -> {:ok, MalformedCasterResultSkill} end)

    assert {:error, :invalid_caster_result} =
             Interpreter.complete_cast(caster, 8_001, 1, :self)
  end

  test "status gates remain mandatory after skill and target validation" do
    caster = homunculus()
    register_active(caster, owner())
    StatusStorage.apply_status(:homunculus, caster.world_gid, :sc_stun)

    assert {:error, :unknown_skill} =
             Interpreter.begin_cast(caster, 8_017, 1, :self)

    assert {:error, :passive_skill} =
             Interpreter.begin_cast(caster, 8_003, 1, :self)

    assert {:error, :wrong_species} =
             Interpreter.begin_cast(%{caster | class_id: 6_002}, 8_001, 1, :self)

    assert {:error, :invalid_target} =
             Interpreter.begin_cast(caster, 8_001, 1, {:unit, {:player, 100}})

    assert {:error, :status_blocked} =
             Interpreter.begin_cast(caster, 8_001, 1, :self)
  end

  test "Homunculus module validation follows status cooldown and SP gates" do
    caster = %{homunculus() | class_id: 6_002, learned_skills: %{8_005 => 1}}

    StatusStorage.apply_status(:homunculus, caster.world_gid, :sc_stun)

    assert {:error, :status_blocked} =
             Interpreter.begin_cast(caster, 8_005, 1, :self)

    StatusStorage.remove_status(:homunculus, caster.world_gid, :sc_stun)
    now = System.monotonic_time(:millisecond)

    assert {:error, :on_cooldown} =
             Interpreter.begin_cast(
               %{caster | cooldowns: %{8_005 => now + 10_000}},
               8_005,
               1,
               :self
             )

    assert {:error, :insufficient_sp} =
             Interpreter.begin_cast(%{caster | sp: 0}, 8_005, 1, :self)
  end

  test "CastingHandler applies Avoid to exactly owner and Lif" do
    session = session()
    register_active(session.homunculus, session.game_state)

    assert {:ok, cast} = CastingHandler.begin(session, 8_002, 3, :self)
    assert cast.homunculus.sp == 70
    assert cast.homunculus.cooldowns[8_002] > System.monotonic_time(:millisecond)

    owner_status = StatusStorage.get_status(:player, 100, :sc_avoid)
    hom_status = StatusStorage.get_status(:homunculus, 1_500_001, :sc_avoid)
    assert owner_status.val1 == 3
    assert owner_status.val2 == 30
    assert hom_status.val1 == 3
    assert hom_status.val2 == 120
  end

  test "cancel clears a lower-level timed-cast setup without settling resources" do
    token = make_ref()
    timer_ref = :erlang.start_timer(60_000, self(), :unused)
    casting = %{token: token, skill_id: 8_002, level: 1, target: :self}
    session = session()
    homunculus = %{session.homunculus | action_state: :casting, casting: casting}
    runtime = %{session.homunculus_runtime | cast_timer_ref: timer_ref}

    cancelled =
      CastingHandler.cancel(%{session | homunculus: homunculus, homunculus_runtime: runtime})

    assert cancelled.homunculus.sp == 100
    assert cancelled.homunculus.cooldowns == %{}
    assert cancelled.homunculus.action_state == :idle
    assert cancelled.homunculus.casting == nil
    assert cancelled.homunculus_runtime.cast_timer_ref == nil
  end

  defp session do
    %SessionState{game_state: owner(), connection_pid: self(), homunculus: homunculus()}
  end

  defp owner do
    %PlayerState{
      character_id: 100,
      map_name: "hom_cast_map",
      x: 10,
      y: 10,
      dir: 0,
      action_state: :idle,
      movement_state: :standing,
      inventory: %{},
      stats: %PlayerStats{
        base_stats: %BaseStats{str: 1, agi: 1, vit: 1, int: 1, dex: 1, luk: 1},
        derived_stats: %DerivedStats{max_hp: 100, max_sp: 100, aspd: 150},
        combat_stats: %CombatStats{
          atk: 1,
          matk: 1,
          matk_min: 1,
          matk_max: 1,
          heal_matk_min: 1,
          heal_matk_max: 1,
          def: 1,
          mdef: 1,
          hit: 1,
          flee: 1,
          critical: 1
        },
        current_state: %CurrentState{hp: 50, sp: 100},
        progression: %PlayerProgression{
          base_level: 20,
          job_level: 20,
          learned_skills: %{}
        }
      }
    }
  end

  defp register_active(homunculus, player) do
    UnitRegistry.register_unit(
      :homunculus,
      homunculus.world_gid,
      HomunculusState,
      homunculus,
      self()
    )

    SpatialIndex.add_unit(
      :homunculus,
      homunculus.world_gid,
      homunculus.x,
      homunculus.y,
      homunculus.map_name
    )

    UnitRegistry.register_unit(:player, player.character_id, PlayerState, player, self())
    SpatialIndex.add_unit(:player, player.character_id, player.x, player.y, player.map_name)
  end

  defp homunculus(overrides \\ %{}) do
    struct!(
      HomunculusState,
      Map.merge(
        %{
          id: 1,
          owner_character_id: 100,
          owner_session_pid: self(),
          class_id: 6_001,
          name: "Lif",
          lifecycle: :active,
          level: 20,
          hp: 50,
          max_hp: 100,
          sp: 100,
          max_sp: 100,
          dex: 1,
          int: 1,
          learned_skills: %{8_001 => 1, 8_002 => 3, 8_003 => 1},
          world_gid: 1_500_001,
          map_name: "hom_cast_map",
          x: 10,
          y: 10,
          action_state: :idle,
          movement_state: :standing
        },
        overrides
      )
    )
  end
end
