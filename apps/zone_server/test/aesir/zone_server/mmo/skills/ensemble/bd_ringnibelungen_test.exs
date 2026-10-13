defmodule Aesir.ZoneServer.Mmo.Skills.Ensemble.BdRingnibelungenTest do
  use ExUnit.Case, async: false
  use Mimic

  import Aesir.TestEtsSetup

  alias Aesir.Commons.Models.Character
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skill.Cost
  alias Aesir.ZoneServer.Mmo.Skills.Ensemble.BdRingnibelungen
  alias Aesir.ZoneServer.Mmo.StatusEffect.Effects.Nibelungen
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Mmo.StatusEntry
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Party.Manager, as: PartyManager
  alias Aesir.ZoneServer.Party.Member
  alias Aesir.ZoneServer.Party.State, as: PartyState
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.Stats.Calculator
  alias Aesir.ZoneServer.Unit.UnitRegistry

  Mimic.copy(PartyManager)

  @player_id 81_310
  @ensemble_statuses [
    :sc_richmankim,
    :sc_eternalchaos,
    :sc_drumbattle,
    :sc_nibelungen,
    :sc_rokisweil,
    :sc_intoabyss,
    :sc_siegfried
  ]

  setup :verify_on_exit!
  setup :set_mimic_from_context
  setup :setup_ets_tables

  setup do
    Catalog.reload()
    state = PlayerState.new(character(@player_id))
    :ok = UnitRegistry.register_unit(:player, @player_id, PlayerState, state, self())
    :ok
  end

  @tag game_mode: :renewal
  test "definition matches the pinned Ring of Nibelungen data, including decreasing SP" do
    assert {:ok, definition} = Catalog.by_id(310)

    assert definition.max_level == 5
    assert definition.target_type == :self
    assert definition.damage_type == :no_damage
    assert definition.damage_kind == :misc
    assert definition.hit_count == 1
    assert definition.splash_radius == 15
    assert definition.sp_cost == [64, 60, 56, 52, 48]
    assert definition.duration == List.duplicate(60_000, 5)
    assert definition.cast_time == List.duplicate(3_000, 5)
    assert definition.fixed_cast_time == List.duplicate(500, 5)
    assert definition.after_cast_delay == List.duplicate(300, 5)
    assert definition.cooldown == List.duplicate(20_000, 5)
    assert definition.require_weapon == [:musical, :whip]
    assert definition.range == 0
    assert definition.unit_duration == []
    assert Catalog.ensemble?(310)
  end

  @tag game_mode: :renewal
  test "status rolls each of the eleven bonuses into val2 and adds the value as mastery ATK" do
    outcomes = [
      %{aspd_rate: 20},
      %{batk_rate: 20},
      %{matk_rate: 20},
      %{max_hp_rate: 30},
      %{max_sp_rate: 30},
      %{str: 15, agi: 15, vit: 15, int: 15, dex: 15, luk: 15},
      %{hit: 50},
      %{flee: 50},
      %{},
      %{hp_regen: 100},
      %{sp_regen: 100}
    ]

    for {expected_modifiers, roll} <- Enum.with_index(outcomes, 1) do
      assert :ok = apply_rolled(roll)

      assert %{val2: ^roll, state: state} =
               StatusStorage.get_status(:player, @player_id, :sc_nibelungen)

      refute Map.has_key?(state, :rng)

      assert StatusInterpreter.get_all_modifiers(:player, @player_id) ==
               Map.put(expected_modifiers, :mastery_atk, roll)
    end
  end

  @tag game_mode: :renewal
  test "outcome 0 is held but grants nothing, and a roll outside 0..11 is rejected" do
    assert :ok = apply_rolled(0)
    assert %{val2: 0} = StatusStorage.get_status(:player, @player_id, :sc_nibelungen)
    assert StatusInterpreter.get_all_modifiers(:player, @player_id) == %{}

    assert_raise ArgumentError, ~r/must be in 0\.\.11/, fn -> apply_rolled(12) end
  end

  @tag game_mode: :renewal
  test "a status restored at login keeps its rolled outcome" do
    assert :ok =
             StatusInterpreter.apply_status(:player, @player_id, :sc_nibelungen,
               loaded: true,
               val2: 4,
               duration: 30_000,
               state: %{rng: fn -> flunk("a restored status must not roll") end}
             )

    assert %{val2: 4} = StatusStorage.get_status(:player, @player_id, :sc_nibelungen)
  end

  @tag game_mode: :renewal
  test "the status ATK outcome raises status ATK by 20%, truncated" do
    {:ok, {_module, player, _pid}} = UnitRegistry.get_unit(:player, @player_id)
    baseline = Calculator.calculate_stats(player.stats, @player_id)

    assert :ok = apply_rolled(2)

    raised = Calculator.calculate_stats(player.stats, @player_id)
    status_atk = baseline.combat_stats.physical_attack.status_atk

    assert raised.combat_stats.physical_attack.status_atk ==
             status_atk + div(status_atk * 20, 100)
  end

  @tag game_mode: :renewal
  test "the SP outcome takes 30% off after every other SP reduction" do
    {:ok, {_module, player, _pid}} = UnitRegistry.get_unit(:player, @player_id)
    player = put_in(player.stats.modifiers.equipment, %{sp_cost_rate: -10})
    definition = BdRingnibelungen.definition()

    assert Cost.resolve_sp(player, definition, 1, 33) == 29

    assert :ok = apply_rolled(9)

    # 33 at -10% = 29, then 29 - 30% of 29 (8) = 21.
    assert Cost.resolve_sp(player, definition, 1, 33) == 21
  end

  @tag game_mode: :pre_renewal
  test "classic takes the field's value as level-4 weapon ATK without rolling" do
    assert :ok =
             StatusInterpreter.apply_status(:player, @player_id, :sc_nibelungen,
               val1: 3,
               val2: 125,
               duration: 60_000,
               state: %{rng: fn -> flunk("classic must not roll") end}
             )

    assert %{val2: 125} = StatusStorage.get_status(:player, @player_id, :sc_nibelungen)
    assert StatusInterpreter.get_all_modifiers(:player, @player_id) == %{level4_watk: 125}
  end

  @tag game_mode: :pre_renewal
  test "classic gives a non-player holder the value as plain weapon ATK" do
    entry = %StatusEntry{type: :sc_nibelungen, val2: 125, state: %{}}

    assert Nibelungen.modifiers(entry, %{unit_type: :mob}) == %{watk: 125}
    assert Nibelungen.modifiers(entry, %{unit_type: :homunculus}) == %{watk: 125}
  end

  @tag game_mode: :renewal
  test "one cast rolls independently for each party recipient" do
    caster = PlayerState.new(character(81_311, 10))
    recipient = PlayerState.new(character(81_312, 10))
    :ok = UnitRegistry.register_unit(:player, caster.character_id, PlayerState, caster, self())

    :ok =
      UnitRegistry.register_unit(:player, recipient.character_id, PlayerState, recipient, self())

    stub(PartyManager, :get, fn 10 ->
      {:ok,
       %PartyState{
         party_id: 10,
         name: "Nibelungen Party",
         leader_char_id: caster.character_id,
         exp_share: false,
         item_pickup_share: false,
         members: %{
           caster.character_id => member(caster.character_id),
           recipient.character_id => member(recipient.character_id)
         }
       }}
    end)

    :rand.seed(:exsss, {1, 2, 3})

    assert {:ok, _caster} =
             BdRingnibelungen.cast(caster, :self, 1, BdRingnibelungen.definition())

    caster_status = StatusStorage.get_status(:player, caster.character_id, :sc_nibelungen)
    recipient_status = StatusStorage.get_status(:player, recipient.character_id, :sc_nibelungen)

    assert caster_status.val2 == 6
    assert recipient_status.val2 == 0
  end

  @tag game_mode: :renewal
  test "status uses the canonical ensemble exclusion list verbatim" do
    metadata = Nibelungen.metadata()

    assert metadata.end_on_start == @ensemble_statuses
    assert metadata.duration == 60_000
    assert metadata.no_dispel
    assert metadata.properties == [:buff]
  end

  @tag game_mode: :pre_renewal
  test "classic status ends no other ensemble" do
    assert Nibelungen.metadata().end_on_start == []
  end

  defp apply_rolled(roll) do
    StatusInterpreter.apply_status(:player, @player_id, :sc_nibelungen,
      duration: 60_000,
      state: %{rng: fn -> roll end}
    )
  end

  defp member(id), do: Member.new(id, "Player#{id}", 100, true, "prontera")

  defp character(id, party_id \\ 0) do
    %Character{
      id: id,
      account_id: id,
      name: "NibelungenTarget",
      last_map: "prontera",
      last_x: 100,
      last_y: 100,
      class: 19,
      base_level: 100,
      job_level: 50,
      sex: "M",
      str: 10,
      agi: 10,
      vit: 10,
      int: 10,
      dex: 10,
      luk: 10,
      party_id: party_id
    }
  end

  @tag game_mode: :pre_renewal
  test "classic carries the source's instant cast and SP" do
    {:ok, definition} = Catalog.by_id(310)
    assert definition.sp_cost == Enum.to_list(38..50//3)
    assert definition.cast_time == []
    assert definition.fixed_cast_time == []
    assert definition.cooldown == []
  end
end
