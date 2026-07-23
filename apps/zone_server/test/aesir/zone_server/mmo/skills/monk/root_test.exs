defmodule Aesir.ZoneServer.Mmo.Skills.Monk.RootTest do
  use ExUnit.Case, async: true
  use Mimic

  import Aesir.TestEtsSetup

  alias Aesir.ZoneServer.Mmo.Skills.Monk.Root
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit.UnitRegistry

  # {skill_id, minimum Root level}
  @throw_spirit_sphere {267, 2}
  @occult_impaction {266, 3}
  @raging_quadruple_blow {272, 4}
  @asura_strike {271, 5}

  setup :set_mimic_from_context
  setup :verify_on_exit!
  setup :setup_ets_tables

  describe "linked_peer/2" do
    test "resolves the peer recorded in the unit's Root state" do
      link_pair(100, {:mob, 200}, 5)

      assert Root.linked_peer(:player, 100) == {:mob, 200}
      assert Root.linked_peer(:mob, 200) == {:player, 100}
    end

    test "returns nil when the unit holds no Root" do
      assert Root.linked_peer(:player, 100) == nil
    end
  end

  describe "follow_up_allowed?/4" do
    test "gates each follow-up by the caller's own minimum Root level" do
      for {skill_id, min_level} <- [
            @throw_spirit_sphere,
            @occult_impaction,
            @raging_quadruple_blow,
            @asura_strike
          ],
          level <- 1..5 do
        reset_pair()
        link_pair(100, {:mob, 200}, level)

        assert Root.follow_up_allowed?(:player, 100, skill_id, {:mob, 200}) == level >= min_level,
               "skill #{skill_id} at level #{level} should be #{level >= min_level}"
      end
    end

    test "a caught non-Monk keys on its own zero level and is allowed nothing" do
      {throw_id, _} = @throw_spirit_sphere
      {asura_id, _} = @asura_strike
      # Monk cast at 5, caught player unlearned (level 0).
      link_pair(100, {:player, 200}, 5, 0)

      refute Root.follow_up_allowed?(:player, 200, throw_id, {:player, 100})
      refute Root.follow_up_allowed?(:player, 200, asura_id, {:player, 100})
    end

    test "a caught Monk keys on its own trained level and may drive follow-ups" do
      {throw_id, _} = @throw_spirit_sphere
      {asura_id, _} = @asura_strike
      # Monk cast at 3, caught is itself a Monk trained to 5.
      link_pair(100, {:player, 200}, 3, 5)

      assert Root.follow_up_allowed?(:player, 200, throw_id, {:player, 100})
      assert Root.follow_up_allowed?(:player, 200, asura_id, {:player, 100})
    end

    test "rejects a target that is not the linked peer" do
      link_pair(100, {:mob, 200}, 5)

      refute Root.follow_up_allowed?(:player, 100, 271, {:mob, 999})
    end

    test "rejects a mismatched link id between the two records" do
      {throw_id, _} = @throw_spirit_sphere

      place_blade_stop(:player, 100, %{peer: {:mob, 200}, link_id: make_ref(), root_level: 5})
      place_blade_stop(:mob, 200, %{peer: {:player, 100}, link_id: make_ref(), root_level: 5})

      refute Root.follow_up_allowed?(:player, 100, throw_id, {:mob, 200})
    end

    test "rejects when the peer no longer holds a Root record" do
      place_blade_stop(:player, 100, %{peer: {:mob, 200}, link_id: make_ref(), root_level: 5})

      refute Root.follow_up_allowed?(:player, 100, 271, {:mob, 200})
    end

    test "rejects an unknown, non-follow-up skill" do
      link_pair(100, {:mob, 200}, 5)

      refute Root.follow_up_allowed?(:player, 100, 999_999, {:mob, 200})
    end
  end

  describe "close/2" do
    test "removing one side cascades to the peer and is idempotent" do
      stub_entity_info()
      link_pair(100, {:mob, 200}, 5)

      assert :ok = Root.close(:player, 100)

      refute StatusStorage.has_status?(:player, 100, :sc_bladestop)
      refute StatusStorage.has_status?(:mob, 200, :sc_bladestop)

      assert :ok = Root.close(:player, 100)
      assert :ok = Root.close(:mob, 200)
    end
  end

  defp place_blade_stop(unit_type, unit_id, state) do
    :ok = StatusStorage.apply_status(unit_type, unit_id, :sc_bladestop, state: state)
  end

  defp link_pair(monk_id, {caught_type, caught_id} = caught, monk_level, caught_level \\ 0) do
    link_id = make_ref()

    place_blade_stop(:player, monk_id, %{peer: caught, link_id: link_id, root_level: monk_level})

    place_blade_stop(caught_type, caught_id, %{
      peer: {:player, monk_id},
      link_id: link_id,
      root_level: caught_level
    })

    link_id
  end

  defp reset_pair do
    StatusStorage.clear_unit_statuses(:player, 100)
    StatusStorage.clear_unit_statuses(:mob, 200)
  end

  defp stub_entity_info do
    Mimic.copy(UnitRegistry)

    stub(UnitRegistry, :get_unit_info, fn _type, id ->
      {:ok, %{unit_id: id, race: :human, element: :neutral, boss_flag: false, stats: %{}}}
    end)
  end
end
