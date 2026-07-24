defmodule Aesir.ZoneServer.Mmo.Combat.DevotionRerouteTest do
  use ExUnit.Case, async: true
  use Mimic

  import Aesir.TestEtsSetup

  alias Aesir.ZoneServer.Mmo.Combat.DamageApplication
  alias Aesir.ZoneServer.Mmo.Combat.TargetResolver
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit.SpatialIndex
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @devotee_id 1
  @crusader_id 2
  @attacker_id 3
  @range 10

  defmodule LivingUnit do
    @moduledoc false
    defstruct []
    def living?(_state), do: true
  end

  setup :set_mimic_from_context
  setup :verify_on_exit!
  setup :setup_ets_tables

  # A raw process answering the session apply_damage cast, forwarding the
  # delivered damage to the test process. A real cast target proves the redirect
  # is asynchronous.
  defp spawn_session(label) do
    test_pid = self()
    spawn_link(fn -> session_loop(test_pid, label) end)
  end

  defp session_loop(test_pid, label) do
    receive do
      {:"$gen_cast", {:unit, {:apply_damage, damage, attacker_id}}} ->
        send(test_pid, {label, damage, attacker_id})
        session_loop(test_pid, label)

      _other ->
        session_loop(test_pid, label)
    end
  end

  defp arm_devotion(link_id) do
    :ok =
      StatusStorage.apply_status(:player, @devotee_id, :sc_devotion,
        caster_id: @crusader_id,
        state: %{peer: {:player, @crusader_id}, link_id: link_id, range: @range}
      )

    :ok =
      StatusStorage.apply_status(:player, @crusader_id, :sc_devoted_by,
        caster_id: @crusader_id,
        state: %{
          links: %{@devotee_id => %{peer: {:player, @devotee_id}, link_id: link_id}}
        }
      )
  end

  defp stub_unit_info do
    stub(UnitRegistry, :get_unit_info, fn :player, _id ->
      {:ok, %{unit_id: 0, unit_type: :player, stats: %{max_hp: 100, hp: 100}}}
    end)
  end

  defp stub_alive_crusader(crusader_pid) do
    stub(UnitRegistry, :get_unit, fn :player, id ->
      if id == @crusader_id do
        {:ok, {LivingUnit, %LivingUnit{}, crusader_pid}}
      else
        {:error, :not_found}
      end
    end)

    stub(TargetResolver, :resolve, fn :player, @crusader_id ->
      {:ok, crusader_pid, %{}, :player}
    end)
  end

  defp stub_dead_crusader do
    stub(UnitRegistry, :get_unit, fn :player, _id -> {:error, :not_found} end)
  end

  defp stub_positions(crusader_pos) do
    stub(SpatialIndex, :get_unit_position, fn :player, id ->
      case id do
        @devotee_id -> {:ok, {100, 100, "prontera"}}
        @crusader_id -> {:ok, crusader_pos}
      end
    end)
  end

  defp in_range_pos, do: {105, 105, "prontera"}
  defp out_of_range_pos, do: {200, 200, "prontera"}
  defp other_map_pos, do: {105, 105, "geffen"}

  defp melee_hit, do: %{dmg_type: :physical, is_short: true, element: :neutral}

  describe "devotion damage reroute" do
    test "redirects the full computed damage to the crusader; devotee takes zero" do
      devotee = spawn_session(:devotee)
      crusader = spawn_session(:crusader)
      arm_devotion(make_ref())
      stub_alive_crusader(crusader)
      stub_positions(in_range_pos())

      {final, hit_info} =
        DamageApplication.prepare_unit_damage(
          :player,
          @devotee_id,
          100,
          melee_hit(),
          @attacker_id
        )

      assert final == 0
      assert hit_info.pre_delivery_prepared? == true

      assert_receive {:crusader, 100, @attacker_id}

      DamageApplication.apply_unit_damage(
        :player,
        devotee,
        @devotee_id,
        final,
        hit_info,
        @attacker_id
      )

      assert_receive {:devotee, 0, @attacker_id}
      refute_receive {:crusader, _, _}
    end

    test "redirect that would kill the crusader still leaves the devotee unharmed" do
      crusader = spawn_session(:crusader)
      arm_devotion(make_ref())
      stub_alive_crusader(crusader)
      stub_positions(in_range_pos())

      {final, _hit_info} =
        DamageApplication.prepare_unit_damage(
          :player,
          @devotee_id,
          200,
          melee_hit(),
          @attacker_id
        )

      assert final == 0
      assert_receive {:crusader, 200, @attacker_id}
    end

    test "does not reroute self-damage (attacker equals target)" do
      crusader = spawn_session(:crusader)
      arm_devotion(make_ref())
      stub_unit_info()
      stub_alive_crusader(crusader)
      stub_positions(in_range_pos())

      {final, _hit_info} =
        DamageApplication.prepare_unit_damage(
          :player,
          @devotee_id,
          100,
          melee_hit(),
          @devotee_id
        )

      assert final == 100
      refute_receive {:crusader, _, _}
    end

    test "does not reroute an already reflected packet" do
      crusader = spawn_session(:crusader)
      arm_devotion(make_ref())
      stub_unit_info()
      stub_alive_crusader(crusader)
      stub_positions(in_range_pos())

      {final, _hit_info} =
        DamageApplication.prepare_unit_damage(
          :player,
          @devotee_id,
          100,
          Map.put(melee_hit(), :reflected, true),
          @attacker_id
        )

      assert final == 100
      refute_receive {:crusader, _, _}
    end

    test "applies to the devotee normally when there is no devotion link" do
      _crusader = spawn_session(:crusader)
      stub_positions(in_range_pos())

      {final, _hit_info} =
        DamageApplication.prepare_unit_damage(
          :player,
          @devotee_id,
          100,
          melee_hit(),
          @attacker_id
        )

      assert final == 100
      refute_receive {:crusader, _, _}
    end

    test "removes both link sides and hits the devotee when the crusader is out of range" do
      crusader = spawn_session(:crusader)
      link_id = make_ref()
      arm_devotion(link_id)
      stub_unit_info()
      stub_alive_crusader(crusader)
      stub_positions(out_of_range_pos())

      {final, _hit_info} =
        DamageApplication.prepare_unit_damage(
          :player,
          @devotee_id,
          100,
          melee_hit(),
          @attacker_id
        )

      assert final == 100
      assert StatusStorage.get_status(:player, @devotee_id, :sc_devotion) == nil
      assert StatusStorage.get_status(:player, @crusader_id, :sc_devoted_by) == nil
      refute_receive {:crusader, _, _}
    end

    test "removes both link sides when the crusader is dead" do
      arm_devotion(make_ref())
      stub_unit_info()
      stub_dead_crusader()
      stub_positions(in_range_pos())

      {final, _hit_info} =
        DamageApplication.prepare_unit_damage(
          :player,
          @devotee_id,
          100,
          melee_hit(),
          @attacker_id
        )

      assert final == 100
      assert StatusStorage.get_status(:player, @devotee_id, :sc_devotion) == nil
      assert StatusStorage.get_status(:player, @crusader_id, :sc_devoted_by) == nil
    end

    test "removes both link sides when the crusader is on another map" do
      crusader = spawn_session(:crusader)
      arm_devotion(make_ref())
      stub_unit_info()
      stub_alive_crusader(crusader)
      stub_positions(other_map_pos())

      {final, _hit_info} =
        DamageApplication.prepare_unit_damage(
          :player,
          @devotee_id,
          100,
          melee_hit(),
          @attacker_id
        )

      assert final == 100
      assert StatusStorage.get_status(:player, @devotee_id, :sc_devotion) == nil
      assert StatusStorage.get_status(:player, @crusader_id, :sc_devoted_by) == nil
      refute_receive {:crusader, _, _}
    end
  end
end
