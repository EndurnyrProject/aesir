defmodule Aesir.ZoneServer.Unit.Player.Handlers.ItemDialogHandler do
  @moduledoc """
  Starts a teleport item's destination menu after its consumption is committed.

  The existing monitored interaction owns the suspended script. Its item
  context has no inline session authority, so all mutations go back through
  the owning player session.
  """

  require Logger

  alias Aesir.ZoneServer.Mmo.ItemManagement.ItemDialogs
  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Interaction
  alias Aesir.ZoneServer.Unit.Player.SessionState

  @gid_base 0x6000_0001
  @gid_count 0x0FFF_FFFF

  @doc "Starts the validated helper without refunding an already consumed item on failure."
  @spec start(SessionState.t() | map(), pos_integer(), ItemDialogs.helper(), [integer()]) ::
          {:noreply, SessionState.t() | map()}
  def start(state, item_id, helper, args) do
    {:ok, module} = ItemDialogs.target({helper, args})
    gid = @gid_base + rem(:erlang.unique_integer([:positive, :monotonic]), @gid_count)
    ctx = Ctx.from_session(state, {:item, item_id})
    ctx = %{ctx | session_state: nil, npc_gid: gid}

    case Interaction.start(self(), module, ctx, &module.call(&1, args)) do
      {:ok, pid} ->
        ref = Process.monitor(pid)
        {:noreply, SessionState.hold_npc_dialog(state, {pid, ref, gid})}

      {:error, reason} ->
        Logger.error("Consumed item #{item_id} could not start its dialog: #{inspect(reason)}")
        {:noreply, state}
    end
  end
end
