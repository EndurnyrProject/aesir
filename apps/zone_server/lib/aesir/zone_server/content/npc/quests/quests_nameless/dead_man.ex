defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsNameless.DeadMan do
  @moduledoc """
  A dead man conceals a medal needed to identify the king.

  ## Behavior

  - Gives the medal during the quest and swaps the visible NPCs.

  ## Credits

  - Original from rAthena, authors and Contributors
    - L0ne_W0lf
    - Koca
    - Yommy
    - brianluau
    - Euphy
    - Everade

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "abbey03",
        x: 232,
        y: 232,
        dir: 4,
        sprite: 956,
        name: "Dead Man",
        scope: :shared,
        unique_name: "Dead Man#King"
      }
    ]

  alias Aesir.ZoneServer.Script.Rathena
  @impl true
  def on_event("OnEnable", ctx) do
    ev_onenable(ctx)
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  def on_event("OnInit", ctx) do
    ev_oninit(ctx)
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  def on_event("OnTimer150000", ctx) do
    ev_ontimer150000(ctx)
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  @impl true
  def on_talk(ctx) do
    cond do
      checkweight(ctx, [{7766, 1}]) == 0 ->
        ctx
        |> mes("^3355FFWait a second!")
        |> mes("Right now, you're carrying")
        |> mes("too many things with you.")
        |> mes("Please come back after")
        |> mes("using the Kafra Service")
        |> mes("to store some of your items.^000000")
        |> close()

      get_char_var(ctx, :aru_monas, 0) == 23 ->
        ctx =
          ctx
          |> mes("^3355FFYou have no idea why")
          |> mes("this dead man is moving")
          |> mes("around, so you decided to")
          |> mes("examine him. In his jacket,")
          |> mes("you find a shining medal...^000000")
          |> next()

        ctx
        |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
        |> mes("This medal...")
        |> mes("This means that")
        |> mes("this man is...!")
        |> set_char_var(:aru_monas, 24)
        |> give_item(7726, 1)
        |> hideonnpc("Dead Man#King")
        |> hideoffnpc("Man#King")
        |> stopnpctimer()
        |> close()

      true ->
        ctx
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  def ev_onenable(ctx) do
    ctx |> initnpctimer() |> hideoffnpc("Dead Man#King")
  end

  def ev_oninit(ctx) do
    hideonnpc(ctx, "Dead Man#King")
  end

  def ev_ontimer150000(ctx) do
    ctx |> hideonnpc("Dead Man#King") |> hideoffnpc("Man#King") |> stopnpctimer()
  end
end
