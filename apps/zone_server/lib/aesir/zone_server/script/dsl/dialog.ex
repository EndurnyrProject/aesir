defmodule Aesir.ZoneServer.Script.Dsl.Dialog do
  @moduledoc """
  Blocking dialog buildins for the script DSL: the page buffer (`mes/2`), the
  suspending primitives (`next/1`, `select/2`, `input/2`, `progressbar/3`,
  `sleep/2`, `sleep2/2`), and the close button (`close/1`, `close2/1`), plus
  the shared suspension plumbing (`flush`/`await`) and the dialog idle
  deadline.

  Imported into scripts via the `Aesir.ZoneServer.Script.Dsl` facade.
  """

  require Logger

  alias Aesir.Net.Cutin
  alias Aesir.Net.NpcDialog
  alias Aesir.Net.NpcInteract
  alias Aesir.ZoneServer.Network.MessageRouter
  alias Aesir.ZoneServer.Npc.Session, as: NpcSession
  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Dsl.Variables
  alias Aesir.ZoneServer.Unit.Player.PlayerSession
  alias Aesir.ZoneServer.Unit.UnitRegistry

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
  def mes(%Ctx{page: page} = ctx, text), do: %{ctx | page: page ++ [text], mes_active: true}

  @doc """
  Flushes the buffered page as a `NEXT` frame, blocks for the client's
  acknowledgement, clears the buffer, and returns the context.

  With no `mes` box open (`Ctx.mes_active`) it fails and the script goes on
  without waiting, as the reference's `next` does. Halts `:no_player` on a
  detached ctx without flushing or blocking.
  """
  @spec next(Ctx.t()) :: Ctx.t()
  def next(%Ctx{mes_active: false} = ctx), do: Ctx.fail(ctx, :next, :no_mes)
  def next(%Ctx{game_state: nil} = ctx), do: Ctx.halt(ctx, :no_player)

  def next(%Ctx{} = ctx) do
    ctx = pause(ctx)
    flush(ctx, :NEXT, [])
    await(ctx, :continue)
    %{ctx | page: []}
  end

  @doc """
  Flushes the buffered page as a `MENU` frame with `options`, blocks for the
  client's choice, and returns `{ctx, choice}`.

  Empty labels are hidden, but `choice` retains its original 1-based logical
  position and is stored in the player's temporary `menu` variable. A
  cancel/ESC ends the interaction without returning. Invalid selections
  disconnect the session instead of reaching a script branch.
  """
  @spec select(Ctx.t(), [String.t()]) :: {Ctx.t(), pos_integer()}
  def select(%Ctx{game_state: nil} = ctx, _options), do: Ctx.halt(ctx, :no_player)

  def select(%Ctx{} = ctx, options) do
    visible = options |> Enum.with_index(1) |> Enum.reject(fn {label, _} -> label == "" end)
    ctx = pause(ctx)
    flush(ctx, :MENU, Enum.map(visible, &elem(&1, 0)))
    choice = await(ctx, :choice)

    if is_integer(choice) and choice > 0 and choice <= length(visible) do
      {_label, logical} = Enum.at(visible, choice - 1)
      ctx = Variables.set_temp_var(%{ctx | page: []}, :menu, logical)
      {ctx, logical}
    else
      PlayerSession.disconnect(ctx.session_pid)
      exit(:normal)
    end
  end

  @doc """
  Flushes the buffered page as an input frame, blocks for the client's value,
  and returns `{ctx, value}`.

  `kind` is `:int` (an `INPUT_INT` frame returning a number) or `:string` (an
  `INPUT_STR` frame returning a string). The page buffer is cleared. On a
  detached ctx, halts `:no_player` without flushing or
  blocking.
  """
  @spec input(Ctx.t(), :int) :: {Ctx.t(), integer()}
  @spec input(Ctx.t(), :string) :: {Ctx.t(), String.t()}
  def input(%Ctx{game_state: nil} = ctx, _kind), do: {Ctx.halt(ctx, :no_player), nil}

  def input(%Ctx{} = ctx, :int) do
    ctx = pause(ctx)
    flush(ctx, :INPUT_INT, [])
    {%{ctx | page: []}, await(ctx, :number)}
  end

  def input(%Ctx{} = ctx, :string) do
    ctx = pause(ctx)
    flush(ctx, :INPUT_STR, [])
    {%{ctx | page: []}, await(ctx, :input)}
  end

  @doc """
  Shows the close button: flushes any remaining buffered page as a `CLOSE`
  frame, then, after a `mes`, waits until the player closes the window and
  returns the context.

  This is the reference's `close` and `close2` alike once a `mes` box is
  open (`Ctx.mes_active`): the script waits for the player (so the dialogs
  it took over are lost, `PlayerSession.script_paused/2`) and the player
  stays in the dialog until they close it. Ending the script after a
  `close` is the caller's job: a transpiled `close` throws
  `{:script_end, ctx}` itself and a hand-written script returns. With no
  `mes` box open it sends the frame and returns at once, as the reference's
  `close` ends the script without waiting; use `close2/1` to wait anyway.
  Halts `:no_player` on a detached ctx without flushing.
  """
  @spec close(Ctx.t()) :: Ctx.t()
  def close(%Ctx{game_state: nil} = ctx), do: Ctx.halt(ctx, :no_player)

  def close(%Ctx{mes_active: false} = ctx) do
    ctx = end_timer_run(ctx)
    flush(ctx, :CLOSE, [])
    %{ctx | page: []}
  end

  def close(%Ctx{} = ctx), do: close2(ctx)

  @doc """
  Flushes any remaining buffered page as a `CLOSE` frame, waits until the
  player closes the window, and returns the context so the script goes on
  (rAthena `close2`).

  Unlike `close/1` it waits even with no `mes` box open. Halts `:no_player`
  on a detached ctx without flushing.
  """
  @spec close2(Ctx.t()) :: Ctx.t()
  def close2(%Ctx{game_state: nil} = ctx), do: Ctx.halt(ctx, :no_player)

  def close2(%Ctx{} = ctx) do
    ctx = pause(ctx)
    flush(ctx, :CLOSE, [])
    await(ctx, :close)
    %{ctx | page: [], mes_active: false}
  end

  # The script is about to wait for the player: its timer label run closes,
  # and its session drops the dialogs it took over
  # (`PlayerSession.script_paused/2`). Sent before the frame, so it reaches the
  # session ahead of the player's answer. An item script running inline in
  # its session never waits.
  @spec pause(Ctx.t()) :: Ctx.t()
  defp pause(ctx) do
    ctx = end_timer_run(ctx)
    if ctx.session_pid, do: PlayerSession.script_paused(ctx.session_pid, self())
    ctx
  end

  # The script stops running for now, so its timer label run (`Npc.Session`)
  # closes, as the reference restores the NPC's timer fields once
  # `run_script` returns.
  @spec end_timer_run(Ctx.t()) :: Ctx.t()
  defp end_timer_run(%Ctx{timer_run: nil} = ctx), do: ctx

  defp end_timer_run(%Ctx{timer_run: gid} = ctx) do
    NpcSession.end_run(gid)
    %{ctx | timer_run: nil}
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
  # Cancel and idle timeout clear any displayed cutin first (rAthena
  # `pc_close_npc`), since the script's own `cutin "", 255` never runs.
  @spec await(Ctx.t(), :continue | :choice | :number | :input | :progress | :close) ::
          boolean() | integer() | String.t()
  defp await(%Ctx{npc_gid: gid, session_ref: session_ref} = ctx, expected) do
    receive do
      {:npc_interact, %NpcInteract{npc_id: ^gid, response: {^expected, value}}} ->
        value

      {:npc_interact, %NpcInteract{npc_id: ^gid, response: {:cancel, _}}} ->
        abandon(ctx)

      {:npc_interact, %NpcInteract{}} ->
        await(ctx, expected)

      {:DOWN, ^session_ref, :process, _pid, _reason} ->
        exit(:normal)
    after
      # Exit :normal (not a custom reason) so the abandoned-window cleanup
      # doesn't spam the supervisor's task-terminated error log. The session
      # clears the lock on the monitor :DOWN regardless of reason.
      dialog_idle_timeout() -> abandon(ctx)
    end
  end

  @spec abandon(Ctx.t()) :: no_return()
  defp abandon(%Ctx{connection_pid: connection_pid}) do
    MessageRouter.send_to(connection_pid, %Cutin{image: "", type: 255})
    exit(:normal)
  end

  @doc """
  Detaches the player, then pauses the running script for `ms` milliseconds
  and resumes it without a player (rAthena `sleep`, which calls
  `script_detach_rid` before it sleeps).

  An NPC interaction frees its player session from the dialog lock first, so
  the player can act while the script sleeps; from then on the script runs
  with the `Ctx.detached/2` shape and player commands end it. A boot `OnInit`
  waiting on this script (`ctx.awaiter`) is released before the pause, as
  rAthena's `OnInit` run moves on once a script sleeps.

  A non-positive duration fails the command and the script goes on without
  pausing or detaching. An item script running inline in its player session
  cannot pause without blocking that session, so it fails the command too.
  """
  @spec sleep(Ctx.t(), integer()) :: Ctx.t()
  def sleep(%Ctx{status: {:error, _}} = ctx, _ms), do: ctx

  def sleep(%Ctx{session_pid: nil, session_state: state} = ctx, _ms) when state != nil,
    do: Ctx.fail(ctx, :sleep, :inline_script)

  def sleep(%Ctx{} = ctx, ms) when is_integer(ms) and ms > 0 do
    ctx = ctx |> end_timer_run() |> release_player() |> release_awaiter()
    Process.sleep(ms)
    ctx
  end

  def sleep(%Ctx{} = ctx, ms), do: Ctx.fail(ctx, :sleep, {:invalid_duration, ms})

  @spec release_player(Ctx.t()) :: Ctx.t()
  defp release_player(%Ctx{session_pid: nil} = ctx), do: Ctx.detach(ctx)

  defp release_player(%Ctx{session_pid: session_pid, session_ref: session_ref} = ctx) do
    _ = PlayerSession.detach_script(session_pid, self())
    if session_ref, do: Process.demonitor(session_ref, [:flush])
    Ctx.detach(ctx)
  end

  @spec release_awaiter(Ctx.t()) :: Ctx.t()
  defp release_awaiter(%Ctx{awaiter: nil} = ctx), do: ctx

  defp release_awaiter(%Ctx{awaiter: awaiter} = ctx) do
    send(awaiter, {:script_suspended, self()})
    %{ctx | awaiter: nil}
  end

  @doc """
  Pauses the running script for `ms` milliseconds while keeping its unit
  attached (rAthena `sleep2`), then resumes.

  The player is let go for the pause, as the reference detaches the script
  state when the script sleeps: the dialog the script took over holds them
  again, or they are free to act (`PlayerSession.detach_script/2`). On waking
  the script attaches again (`PlayerSession.attach_script/4`), taking over
  whatever dialog holds the player then, and reads their current snapshot;
  a player gone meanwhile halts `{:error, :no_player}`. A monster attached
  instead (`Ctx.attached_unit`) only has to still exist, else the script
  ends `{:error, :no_unit}`.

  A non-positive duration, or no unit attached, fails the command and the
  script goes on without pausing. An item script running inline in its
  player session sleeps inside that session.
  """
  @spec sleep2(Ctx.t(), integer()) :: Ctx.t()
  def sleep2(%Ctx{status: {:error, _}} = ctx, _ms), do: ctx

  def sleep2(%Ctx{} = ctx, ms) when not is_integer(ms) or ms <= 0 do
    Logger.warning("sleep2: non-positive duration #{inspect(ms)}, skipping")
    ctx
  end

  def sleep2(%Ctx{game_state: nil, attached_unit: nil} = ctx, _ms),
    do: Ctx.fail(ctx, :sleep2, :no_player)

  def sleep2(%Ctx{game_state: nil, attached_unit: {:mob, instance_id}} = ctx, ms) do
    ctx = end_timer_run(ctx)
    Process.sleep(ms)

    case UnitRegistry.get_unit(:mob, instance_id) do
      {:ok, _unit} -> ctx
      {:error, :not_found} -> Ctx.halt(ctx, :no_unit)
    end
  end

  def sleep2(%Ctx{session_pid: nil} = ctx, ms) do
    Process.sleep(ms)
    ctx
  end

  def sleep2(%Ctx{session_pid: session_pid} = ctx, ms) do
    ctx = end_timer_run(ctx)
    _ = PlayerSession.detach_script(session_pid, self())
    Process.sleep(ms)

    case PlayerSession.attach_script(session_pid, self(), ctx.npc_gid, true) do
      {:ok, %{game_state: game_state}} -> %{ctx | game_state: game_state}
      _gone -> Ctx.halt(ctx, :no_player)
    end
  end

  @doc """
  Displays a progress bar over the attached character's head for `seconds`
  then blocks until the client reports completion.
  The player session starts the bar and holds the work flag that blocks the
  player's skill, item and NPC requests until the client reports the bar full.
  A report before the bar fills, an item use or a walk cancels it and ends the
  script. Halts `:no_player` on a detached ctx.
  """
  @spec progressbar(Ctx.t(), String.t() | integer(), integer()) :: Ctx.t()
  def progressbar(%Ctx{status: {:error, _}} = ctx, _color, _seconds), do: ctx
  def progressbar(%Ctx{game_state: nil} = ctx, _color, _seconds), do: Ctx.halt(ctx, :no_player)

  def progressbar(%Ctx{session_pid: nil} = ctx, _color, seconds)
      when is_integer(seconds) and seconds > 0,
      do: Ctx.halt(ctx, :no_player)

  def progressbar(%Ctx{} = ctx, color, seconds) when is_integer(seconds) and seconds > 0 do
    op = {:progressbar, ctx.npc_gid, parse_color(color), seconds}

    case PlayerSession.script_apply(ctx.session_pid, op) do
      {:ok, _game_state} ->
        ctx = pause(ctx)
        await(ctx, :progress)
        ctx

      {:error, reason} ->
        Ctx.fail(ctx, :progressbar, reason)
    end
  end

  def progressbar(%Ctx{} = ctx, _color, seconds) do
    Logger.warning("progressbar: non-positive duration #{inspect(seconds)}, skipping")
    ctx
  end

  @spec parse_color(term()) :: non_neg_integer()
  defp parse_color(color) when is_binary(color) do
    case Integer.parse(color, 16) do
      {value, ""} when value >= 0 -> value
      _ -> 0
    end
  end

  defp parse_color(color) when is_integer(color) and color >= 0, do: color
  defp parse_color(_color), do: 0
end
