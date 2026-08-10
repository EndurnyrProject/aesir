defmodule Aesir.ZoneServer.Unit.Trade.SupervisorTest do
  use ExUnit.Case, async: false

  alias Aesir.ZoneServer.Unit.Trade.Supervisor

  test "starts a temporary trade session" do
    {participant_a, participant_b} = participants()

    assert {:ok, session} = Supervisor.start_child(init_arg(participant_a, participant_b))
    assert Process.alive?(session)

    monitor = Process.monitor(session)
    Process.exit(session, :kill)

    assert_receive {:DOWN, ^monitor, :process, ^session, :killed}
    assert %{active: 0} = DynamicSupervisor.count_children(Supervisor)
  end

  test "uses the per-test supervisor override" do
    supervisor = start_supervised!({Supervisor, name: nil})
    Process.put({Supervisor, :server}, supervisor)
    on_exit(fn -> Process.delete({Supervisor, :server}) end)

    {participant_a, participant_b} = participants()

    assert {:ok, session} = Supervisor.start_child(init_arg(participant_a, participant_b))
    assert %{active: 1} = DynamicSupervisor.count_children(supervisor)
    assert %{active: 0} = DynamicSupervisor.count_children(Supervisor)

    Process.exit(session, :kill)
  end

  defp participants do
    participant_a = spawn(fn -> wait_for_stop() end)
    participant_b = spawn(fn -> wait_for_stop() end)
    on_exit(fn -> stop_participants(participant_a, participant_b) end)
    {participant_a, participant_b}
  end

  defp init_arg(participant_a, participant_b) do
    %{a: %{pid: participant_a, char_id: 1}, b: %{pid: participant_b, char_id: 2}}
  end

  defp wait_for_stop do
    receive do
      :stop -> :ok
    end
  end

  defp stop_participants(participant_a, participant_b) do
    send(participant_a, :stop)
    send(participant_b, :stop)
  end
end
