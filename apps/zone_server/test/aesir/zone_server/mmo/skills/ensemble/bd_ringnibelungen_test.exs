defmodule Aesir.ZoneServer.Mmo.Skills.Ensemble.BdRingnibelungenTest do
  use ExUnit.Case, async: false
  use Mimic

  import Aesir.TestEtsSetup

  alias Aesir.Commons.Models.Character
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skills.Ensemble.BdRingnibelungen
  alias Aesir.ZoneServer.Mmo.StatusEffect.Effects.Nibelungen
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Party.Manager, as: PartyManager
  alias Aesir.ZoneServer.Party.Member
  alias Aesir.ZoneServer.Party.State, as: PartyState
  alias Aesir.ZoneServer.Unit.Player.PlayerState
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

  test "definition matches the pinned Ring of Nibelungen data, including decreasing SP" do
    assert {:ok, BdRingnibelungen} = Catalog.active_module_for(:bd_ringnibelungen)
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
    refute function_exported?(BdRingnibelungen, :dynamic_cost, 4)
  end

  test "status stores and exposes each of exactly eleven uniformly selectable bonuses" do
    outcomes = [
      %{aspd_rate: 20},
      %{atk_rate: 20},
      %{matk_rate: 20},
      %{max_hp_rate: 30},
      %{max_sp_rate: 30},
      %{str: 15, agi: 15, vit: 15, int: 15, dex: 15, luk: 15},
      %{hit: 50},
      %{flee: 50},
      %{sp_cost_rate: -30},
      %{hp_regen: 100},
      %{sp_regen: 100}
    ]

    for {expected_modifiers, roll} <- Enum.with_index(outcomes, 1) do
      assert :ok =
               StatusInterpreter.apply_status(:player, @player_id, :sc_nibelungen,
                 duration: 60_000,
                 state: %{
                   rng: fn upper ->
                     assert upper == 11
                     roll
                   end
                 }
               )

      assert %{state: %{outcome: ^roll}} =
               StatusStorage.get_status(:player, @player_id, :sc_nibelungen)

      assert StatusInterpreter.get_all_modifiers(:player, @player_id) == expected_modifiers
    end
  end

  test "rejects a twelfth dud outcome" do
    assert_raise ArgumentError, ~r/must be in 1\.\.11/, fn ->
      StatusInterpreter.apply_status(:player, @player_id, :sc_nibelungen,
        state: %{rng: fn 11 -> 12 end}
      )
    end
  end

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

    assert caster_status.state.outcome == 8
    assert recipient_status.state.outcome == 11
  end

  test "status uses the canonical ensemble exclusion list verbatim" do
    metadata = Nibelungen.metadata()

    assert metadata.end_on_start == @ensemble_statuses
    assert metadata.duration == 60_000
    assert metadata.no_dispel
    assert metadata.properties == [:buff]
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
end
