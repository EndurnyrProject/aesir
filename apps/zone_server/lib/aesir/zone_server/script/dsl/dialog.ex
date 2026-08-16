defmodule Aesir.ZoneServer.Script.Dsl.Dialog do
  @moduledoc """
  Blocking dialog buildins for the script DSL: the page buffer (`mes/2`), the
  suspending primitives (`next/1`, `select/2`, `input/2`, `progressbar/3`,
  `sleep2/2`), and the terminal `close/1`, plus the shared suspension plumbing
  (`flush`/`await`) and the dialog idle deadline.

  Imported into scripts via the `Aesir.ZoneServer.Script.Dsl` facade.
  """

  require Logger

  alias Aesir.Net.NpcDialog
  alias Aesir.Net.NpcInteract
  alias Aesir.Net.ProgressBar
  alias Aesir.ZoneServer.Network.MessageRouter
  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Unit.Broadcast

  @typedoc "The dialog frame kind, mirroring the `NpcDialog.Expect` proto enum."
  @type expect :: :NEXT | :MENU | :INPUT_INT | :INPUT_STR | :CLOSE

  # Idle deadline for a blocking dialog suspension. The client freezes the
  # player during a dialog, so a `receive` that never returns means the player
  # abandoned the window; the interaction exits and the session clears the lock.
  # Read from app env at call time so tests can shrink it.
  @default_dialog_idle_timeout :timer.seconds(60)

  @spec dialog_idle_timeout() :: timeout()
  defp dialog_idle_timeout do
    Application.get_env(:zone_server, :dialog_idle_timeout, @default_dialog_idle_timeout)
  end

  @doc """
  Appends a line to the context's dialog page buffer and returns the context.

  Pure: composes with `|>` and sends nothing. The buffered lines flush, joined
  with `"\\n"`, at the next terminal dialog op (`next/1`, `select/2`, `input/2`,
  `close/1`). Halts `:no_player` on a detached ctx (no player to dialog with)
  without buffering the line.
  """
  @spec mes(Ctx.t(), String.t()) :: Ctx.t()
  def mes(%Ctx{game_state: nil} = ctx, _text), do: Ctx.halt(ctx, :no_player)
  def mes(%Ctx{page: page} = ctx, text), do: %{ctx | page: page ++ [text]}

  @doc """
  Flushes the buffered page as a `NEXT` frame, blocks for the client's
  acknowledgement, clears the buffer, and returns the context.

  Halts `:no_player` on a detached ctx without flushing or blocking.
  """
  @spec next(Ctx.t()) :: Ctx.t()
  def next(%Ctx{game_state: nil} = ctx), do: Ctx.halt(ctx, :no_player)

  def next(%Ctx{} = ctx) do
    flush(ctx, :NEXT, [])
    await(ctx, :continue)
    %{ctx | page: []}
  end

  @doc """
  Flushes the buffered page as a `MENU` frame with `options`, blocks for the
  client's choice, and returns `{ctx, choice}`.

  `choice` is the 1-based index the client selected; a cancel/ESC response
  yields `0`. The page buffer is cleared. On a detached ctx, halts `:no_player`
  and returns `{ctx, nil}` without flushing or blocking.
  """
  @spec select(Ctx.t(), [String.t()]) :: {Ctx.t(), non_neg_integer() | nil}
  def select(%Ctx{game_state: nil} = ctx, _options), do: {Ctx.halt(ctx, :no_player), nil}

  def select(%Ctx{} = ctx, options) do
    flush(ctx, :MENU, options)
    {%{ctx | page: []}, await(ctx, :choice)}
  end

  @doc """
  Flushes the buffered page as an input frame, blocks for the client's value,
  and returns `{ctx, value}`.

  `kind` is `:int` (an `INPUT_INT` frame returning a number) or `:string` (an
  `INPUT_STR` frame returning a string). The page buffer is cleared. On a
  detached ctx, halts `:no_player` and returns `{ctx, nil}` without flushing or
  blocking.
  """
  @spec input(Ctx.t(), :int | :string) :: {Ctx.t(), integer() | String.t() | nil}
  def input(%Ctx{game_state: nil} = ctx, _kind), do: {Ctx.halt(ctx, :no_player), nil}

  def input(%Ctx{} = ctx, :int) do
    flush(ctx, :INPUT_INT, [])
    {%{ctx | page: []}, await(ctx, :number)}
  end

  def input(%Ctx{} = ctx, :string) do
    flush(ctx, :INPUT_STR, [])
    {%{ctx | page: []}, await(ctx, :input)}
  end

  @doc """
  Flushes any remaining buffered page as a `CLOSE` frame and returns the context.

  Does not block: the script returns and the interaction process exits `:normal`.
  Halts `:no_player` on a detached ctx without flushing.
  """
  @spec close(Ctx.t()) :: Ctx.t()
  def close(%Ctx{game_state: nil} = ctx), do: Ctx.halt(ctx, :no_player)

  def close(%Ctx{} = ctx) do
    flush(ctx, :CLOSE, [])
    %{ctx | page: []}
  end

  @spec flush(Ctx.t(), expect(), [String.t()]) :: :ok
  defp flush(%Ctx{} = ctx, expect, options) do
    dialog = %NpcDialog{
      npc_id: ctx.npc_gid,
      text: Enum.join(ctx.page, "\n"),
      expect: expect,
      options: options
    }

    MessageRouter.send_to(ctx.connection_pid, dialog)
  end

  # The single shared blocking receive for every suspending dialog primitive.
  #
  # Blocks until an NpcInteract for this NPC carrying the expected response arm
  # arrives, returning the arm's value. A message for a different npc_id, or
  # carrying an unexpected response arm, is dropped and the wait continues.
  # Three paths end the wait by exiting the interaction process (which, via the
  # session's monitor, clears the lock): a `cancel`/ESC for this NPC at any
  # suspension point (design §Part 2 "cancel/ESC … clear the lock" — promptly,
  # not only on menus), the session dying — observed through the monitor the
  # interaction holds in `ctx.session_ref` — and the idle deadline for an
  # abandoned window. (Sphinx Mask's "No deal" is an explicit menu option, a
  # `:choice`, not an ESC, so uniform exit-on-cancel does not lose any flow.)
  @spec await(Ctx.t(), atom()) :: term()
  defp await(%Ctx{npc_gid: gid, session_ref: session_ref} = ctx, expected) do
    receive do
      {:npc_interact, %NpcInteract{npc_id: ^gid, response: {^expected, value}}} ->
        value

      {:npc_interact, %NpcInteract{npc_id: ^gid, response: {:cancel, _}}} ->
        exit(:normal)

      {:npc_interact, %NpcInteract{}} ->
        await(ctx, expected)

      {:DOWN, ^session_ref, :process, _pid, _reason} ->
        exit(:normal)
    after
      # Exit :normal (not a custom reason) so the abandoned-window cleanup
      # doesn't spam the supervisor's task-terminated error log. The session
      # clears the lock on the monitor :DOWN regardless of reason.
      dialog_idle_timeout() -> exit(:normal)
    end
  end

  @doc """
  Pauses the running script for `ms` milliseconds while keeping the player
  attached (rAthena `sleep2`), then resumes. Runs inside the interaction
  coroutine, so only this script waits - the player session is untouched. If
  the player session died while sleeping, halts `{:error, :no_player}` instead
  of resuming. A non-positive duration warns and skips the pause.
  """
  @spec sleep2(Ctx.t(), integer()) :: Ctx.t()
  def sleep2(%Ctx{status: {:error, _}} = ctx, _ms), do: ctx
  def sleep2(%Ctx{game_state: nil} = ctx, _ms), do: Ctx.halt(ctx, :no_player)

  def sleep2(%Ctx{} = ctx, ms) when is_integer(ms) and ms > 0 do
    Process.sleep(ms)

    if ctx.session_pid == nil or Process.alive?(ctx.session_pid) do
      ctx
    else
      Ctx.halt(ctx, :no_player)
    end
  end

  def sleep2(%Ctx{} = ctx, ms) do
    Logger.warning("sleep2: non-positive duration #{inspect(ms)}, skipping")
    ctx
  end

  @doc """
  Displays a progress bar over the attached character's head for `seconds`
  then blocks until the client reports completion.
  Blocks like the other dialog primitives: the interaction suspends on a
  `receive` until the client signals completion (`NpcInteract.progress`); a
  moving character makes the client cancel instead, ending the script (the same
  cancel path `select`'s ESC uses). Halts `:no_player` on a detached ctx.
  """
  @spec progressbar(Ctx.t(), String.t(), integer()) :: Ctx.t()
  def progressbar(%Ctx{status: {:error, _}} = ctx, _color, _seconds), do: ctx
  def progressbar(%Ctx{game_state: nil} = ctx, _color, _seconds), do: Ctx.halt(ctx, :no_player)

  def progressbar(%Ctx{char_id: char_id} = ctx, _color, seconds)
      when is_integer(seconds) and seconds > 0 do
    Broadcast.to_player(char_id, %ProgressBar{seconds: seconds})
    await(ctx, :progress)
    ctx
  end

  def progressbar(%Ctx{} = ctx, _color, seconds) do
    Logger.warning("progressbar: non-positive duration #{inspect(seconds)}, skipping")
    ctx
  end
end
