defmodule Aesir.ZoneServer.Npc.SessionSupervisor do
  @moduledoc """
  Top-level supervisor for `Aesir.ZoneServer.Npc.Session` processes.

  Owns the public `:npc_session_flags` ETS table (created in `init/1`, so this
  supervisor's own long-lived process is the table owner) and starts
  `Aesir.ZoneServer.Npc.SessionDynamicSupervisor`, which supervises the actual
  per-gid `Npc.Session` processes. Owning the table here, rather than in any
  one session, is what lets a session crash without losing every other
  session's flags.
  """

  use Supervisor

  @flags_table :npc_session_flags
  @display_table :npc_display_overrides
  @dynamic_supervisor Aesir.ZoneServer.Npc.SessionDynamicSupervisor
  @doc "Starts the supervisor."
  @spec start_link(term()) :: Supervisor.on_start()
  def start_link(opts) do
    Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl Supervisor
  def init(_opts) do
    :ets.new(@flags_table, [:set, :public, :named_table, read_concurrency: true])
    :ets.new(@display_table, [:set, :public, :named_table, read_concurrency: true])

    children = [
      {DynamicSupervisor,
       name: @dynamic_supervisor, strategy: :one_for_one, max_restarts: 5, max_seconds: 60}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
