defmodule Aesir.ZoneServer.Mmo.JobManagement.Definition do
  @moduledoc """
  Behaviour for job definitions.

  Each job is a plain Elixir module that `use`s this behaviour and implements
  `job/0`, returning a fully-populated `Aesir.ZoneServer.Mmo.JobManagement.Job`
  struct. All data is inline (or referenced from shared `Tables` modules), so it
  lives in the BEAM constant pool with no runtime parsing.

  ## Example

      defmodule Aesir.ZoneServer.Mmo.JobManagement.Jobs.Novice do
        use Aesir.ZoneServer.Mmo.JobManagement.Definition

        alias Aesir.ZoneServer.Mmo.JobManagement.Job
        alias Aesir.ZoneServer.Mmo.JobManagement.Tables

        @impl true
        def job do
          %Job{
            id: 0,
            name: :novice,
            base_hp: Tables.BasepointsNovice.base_hp(),
            ...
          }
        end
      end
  """

  alias Aesir.ZoneServer.Mmo.JobManagement.Job

  @doc "Returns the fully-populated job struct."
  @callback job() :: Job.t()

  defmacro __using__(_opts) do
    quote do
      @behaviour Aesir.ZoneServer.Mmo.JobManagement.Definition
    end
  end
end
