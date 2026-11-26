defmodule Aesir.ZoneServer.Content.Npc.Quests.TheSignQuest.SignW6 do
  @moduledoc """
  Controls the entrance to Serin's chamber.

  ## Behavior

  - Lets medal holders helping another adventurer bypass the chamber lock.
  - Otherwise blocks an occupied chamber or reserves it before entry.

  ## Credits

  - Original from rAthena, authors and Contributors
    - SinSloth
    - MasterOfMuppets
    - Kargha
    - L0ne_W0lf
    - Kazukin
    - Kisuka
    - CalciumKid
    - tr0n
    - Euphy
    - Joseph
    - Capuche

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  - Changed `sign_q != 124 || sign_q != 125 || sign_q != 126` to require all three
    inequalities, excluding the adventurer's own Serin encounter from the medal bypass.
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "que_sign02",
        x: 378,
        y: 235,
        dir: 0,
        sprite: 45,
        name: "sign_w6",
        scope: :shared,
        trigger: {1, 1}
      }
    ]

  alias Aesir.ZoneServer.Content.Npc.Functions.FUpdatesignvars

  @impl true
  def on_event("OnTouch_", ctx) do
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
    {ctx, _} = FUpdatesignvars.call(ctx, [])

    cond do
      count_item(ctx, 7313) == 1 and get_char_var(ctx, :sign_q, 0) not in [124, 125, 126] ->
        warp(ctx, "que_sign01", 197, 190)

      get_server_temp_var(ctx, "sign_w1", 0) == 1 ->
        ctx
        |> mes("^3355FFSome sort of")
        |> mes("strange force")
        |> mes("is blocking you")
        |> mes("from entering.^000000")
        |> close()

      true ->
        ctx
        |> set_server_temp_var("sign_w1", 1)
        |> warp("que_sign01", 197, 190)
    end
  end
end
