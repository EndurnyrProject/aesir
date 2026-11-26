defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsRachel.Gyoin1 do
  @moduledoc """
  A guarded doorway controls access to the pope’s office.

  ## Behavior

  - Warps authorized visitors and otherwise displays the guard’s message or a locked door.

  ## Credits

  - Original from rAthena, authors and Contributors
    - L0ne_W0lf
    - Euphy

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "ra_temin",
        x: 134,
        y: 131,
        dir: 0,
        sprite: 45,
        name: "gyoin1",
        scope: :shared,
        unique_name: "gyoin1#rachel",
        trigger: {1, 1}
      }
    ]

  alias Aesir.ZoneServer.Script.Rathena
  @impl true
  def on_event("OnTouch", ctx) do
    ev_ontouch(ctx)
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  @impl true
  def on_talk(ctx) do
    ev_ontouch(ctx)
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  def ev_ontouch(ctx) do
    quest = get_char_var(ctx, :ra_tem_q, 0)

    cond do
      quest == 16 ->
        warp(ctx, "ra_temin", 276, 239)

      quest > 16 or Rathena.truthy?(:erlang.band(get_char_var(ctx, :MISC_QUEST, 0), 8192)) ->
        if get_char_var(ctx, :aru_em, 0) in [15, 21] do
          ctx = warp(ctx, "ra_temin", 276, 239)
          if get_char_var(ctx, :ra_tem_q, 0) < 16, do: locked(ctx), else: ctx
        else
          ctx
          |> mes("[Pope's Office Guard]")
          |> mes("I'm sorry, but the pope")
          |> mes("is officiating a service")
          |> mes("now. Please come back")
          |> mes("after the service is ended.")
          |> close()
        end

      quest < 16 ->
        locked(ctx)

      true ->
        ctx
    end
  end

  defp locked(ctx) do
    ctx |> mes("^3355FFThe door is locked.^000000") |> close()
  end
end
