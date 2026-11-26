defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsRachel.Saint1 do
  @moduledoc """
  Controls access to the Holy Ground.

  ## Behavior

  - Opens the entrance for eligible adventurers or those using the small key.

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
        x: 28,
        y: 319,
        dir: 0,
        sprite: 45,
        name: "saint1",
        scope: :shared,
        unique_name: "saint1#rachel",
        trigger: {4, 2}
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
    cond do
      get_char_var(ctx, :ra_tem_q, 0) > 21 or
          Rathena.truthy?(:erlang.band(get_char_var(ctx, :MISC_QUEST, 0), 8192)) ->
        warp(ctx, "ra_san01", 140, 135)

      get_char_var(ctx, :ra_tem_q, 0) == 21 ->
        use_key(ctx)

      true ->
        ctx |> mes("^3355FFThe door is locked.^000000") |> close()
    end
  end

  defp use_key(ctx) do
    {ctx, choice} =
      ctx
      |> mes("^3355FFThis must be the")
      |> mes("entrance to the Holy")
      |> mes("Ground. However, the")
      |> mes("door in your way is locked.^000000.")
      |> next()
      |> select(["Quit", "Use Small Key"])

    if choice == 2 do
      ctx
      |> mes("^3355FFYou insert the Small")
      |> mes("Key that you found in")
      |> mes("High Priest Zhed's room,")
      |> mes("and find that it is able")
      |> mes("to unlock this door.^000000")
      |> close2()
      |> warp("ra_san01", 140, 135)
    else
      close(ctx)
    end
  end
end
