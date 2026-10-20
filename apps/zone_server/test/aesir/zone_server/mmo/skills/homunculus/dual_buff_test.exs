defmodule Aesir.ZoneServer.Mmo.Skills.Homunculus.DualBuffTest do
  @moduledoc """
  The owner and the Homunculus receive a dual buff independently: a refused
  application on either one does not stop the other and never fails the cast.
  """

  use ExUnit.Case, async: false

  import Mimic

  alias Aesir.ZoneServer.Mmo.Skills.Homunculus.HamiDefence
  alias Aesir.ZoneServer.Mmo.Skills.Homunculus.HlifAvoid
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Unit.Homunculus.HomunculusState

  setup :set_mimic_from_context
  setup :verify_on_exit!

  @owner_id 100
  @world_gid 1_500_001

  defp homunculus do
    %HomunculusState{
      id: 1,
      owner_character_id: @owner_id,
      owner_session_pid: self(),
      class_id: 6_001,
      name: "Lif",
      lifecycle: :active,
      level: 50,
      hp: 1_000,
      max_hp: 1_000,
      sp: 100,
      max_sp: 100,
      world_gid: @world_gid,
      map_name: "prontera",
      x: 10,
      y: 10,
      action_state: :idle,
      movement_state: :standing
    }
  end

  test "Defence still starts on the Homunculus when the owner refuses it" do
    test_pid = self()
    caster = homunculus()

    stub(StatusInterpreter, :apply_status, fn unit_type, id, :sc_defence, _params ->
      send(test_pid, {:applied, unit_type, id})
      if unit_type == :player, do: {:error, :immune}, else: :ok
    end)

    assert {:ok, ^caster} = HamiDefence.cast(caster, :self, 5, HamiDefence.definition())

    assert_received {:applied, :player, @owner_id}
    assert_received {:applied, :homunculus, @world_gid}
  end

  test "Avoid still starts on the owner when the Homunculus refuses it" do
    test_pid = self()
    caster = homunculus()

    stub(StatusInterpreter, :apply_status, fn unit_type, id, :sc_avoid, _params ->
      send(test_pid, {:applied, unit_type, id})
      if unit_type == :homunculus, do: {:error, :immune}, else: :ok
    end)

    assert {:ok, ^caster} = HlifAvoid.cast(caster, :self, 5, HlifAvoid.definition())

    assert_received {:applied, :player, @owner_id}
    assert_received {:applied, :homunculus, @world_gid}
  end
end
