defmodule Aesir.ZoneServer.Unit.Mob.MobSessionDeferredSkillTest do
  @moduledoc """
  Covers the `{:skill, {:deferred, module, payload}}` dispatch clause on
  MobSession, mirroring PlayerSession's handler: `Skill.defer/3` arms this
  message on the calling process, so a mob-cast deferring skill (e.g.
  WZ_JUPITEL) sends it here.
  """

  use ExUnit.Case, async: false
  use Mimic

  import Aesir.TestEtsSetup
  import ExUnit.CaptureLog

  alias Aesir.ZoneServer.Map.Cell
  alias Aesir.ZoneServer.Mmo.Skills.Bard.BaFrostjoker
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Unit.Mob.MobSession
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.Movement
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.SpatialIndex
  alias Aesir.ZoneServer.Unit.UnitRegistry

  setup :verify_on_exit!
  setup :set_mimic_from_context
  setup :setup_ets_tables

  setup do
    Mimic.copy(Cell)
    :ok
  end

  defmodule Deferrer do
    @moduledoc false
    def deferred(%{reply_to: reply_to} = payload, mob_state) do
      send(reply_to, {:deferred_called, payload, mob_state})
      :ok
    end
  end

  defmodule Undeferrable do
    @moduledoc false
  end

  describe "session dispatch" do
    test "invokes deferred/2 with the payload and the mob's own state" do
      payload = %{reply_to: self(), skill: :example}
      state = %{instance_id: 1}

      assert {:noreply, ^state} =
               MobSession.handle_info({:skill, {:deferred, Deferrer, payload}}, state)

      assert_received {:deferred_called, ^payload, ^state}
    end

    test "logs and drops a deferred message for a module without deferred/2" do
      state = %{instance_id: 1}

      log =
        capture_log(fn ->
          assert {:noreply, ^state} =
                   MobSession.handle_info({:skill, {:deferred, Undeferrable, %{}}}, state)
        end)

      assert log =~ inspect(Undeferrable)
      assert log =~ "deferred/2"
    end

    test "delivers Frost Joker at the matching epoch and cancels it after mob teleport" do
      caster = mob_state()
      target = %PlayerState{character_id: 2, map_name: caster.map_name, x: 101, y: 100}

      register(:mob, caster.instance_id, caster)
      register(:player, target.character_id, target)

      test_pid = self()

      scheduler = fn module, payload, 3_000 ->
        send(test_pid, {:deferred, module, payload})
        make_ref()
      end

      assert {:ok, ^caster} =
               BaFrostjoker.cast(
                 caster,
                 {:unit, caster.instance_id},
                 5,
                 BaFrostjoker.definition(),
                 scheduler
               )

      assert_receive {:deferred, BaFrostjoker, payload}

      expect(StatusInterpreter, :apply_status, fn :player, 2, :sc_freeze, params ->
        send(test_pid, {:frozen, params})
        :ok
      end)

      assert {:noreply, ^caster} =
               MobSession.handle_info({:skill, {:deferred, BaFrostjoker, payload}}, caster)

      assert_receive {:frozen, params}
      assert params[:caster_id] == caster.instance_id
      assert params[:source_type] == :mob

      stub(Cell, :random_traversable, fn "frost_mob_map" -> {:ok, {150, 160}} end)
      stub(Movement, :set_position, fn :mob, 1, _state, "frost_mob_map" -> :ok end)

      assert {:noreply, teleported} = MobSession.handle_cast({:movement, :teleport}, caster)
      assert teleported.deferred_epoch == caster.deferred_epoch + 1

      assert {:noreply, ^teleported} =
               MobSession.handle_info({:skill, {:deferred, BaFrostjoker, payload}}, teleported)

      refute_receive {:frozen, _params}
    end
  end

  defp mob_state do
    %MobState{
      instance_id: 1,
      mob_id: 1,
      mob_data: nil,
      spawn_ref: nil,
      x: 100,
      y: 100,
      map_name: "frost_mob_map",
      deferred_epoch: 7,
      hp: 100,
      max_hp: 100,
      sp: 100,
      max_sp: 100,
      spawned_at: 0
    }
  end

  defp register(unit_type, unit_id, state) do
    :ok = UnitRegistry.register_unit(unit_type, unit_id, state.__struct__, state, self())
    :ok = SpatialIndex.add_unit(unit_type, unit_id, state.x, state.y, state.map_name)
  end
end
