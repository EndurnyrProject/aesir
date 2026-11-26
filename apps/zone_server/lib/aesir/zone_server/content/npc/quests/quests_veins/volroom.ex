defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsVeins.Volroom do
  @moduledoc """
  An abandoned room reveals a clue in the volcano investigation.

  ## Behavior

  - Shows a letter and advances the investigation when the player enters.

  ## Credits

  - Original from rAthena, authors and Contributors
    - L0ne_W0lf
    - Toms
    - Euphy
    - Joseph
    - Everade

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "ve_in",
        x: 280,
        y: 223,
        dir: 0,
        sprite: -1,
        name: "",
        scope: :shared,
        unique_name: "#volroom",
        trigger: {2, 2}
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
      get_char_var(ctx, :aru_vol, 0) == 6 ->
        ctx
        |> describe_room()
        |> next()
        |> mes("^3355FFOne particular piece")
        |> mes("of paper catches your")
        |> mes("attention. You pick it")
        |> mes("up and give it a read.^000000")
        |> next()
        |> mes("[Paper]")
        |> mes("''^333333The regularly scheduled")
        |> mes("geological survey had been")
        |> mes("postponed for over a week.")
        |> mes("Please submit your report")
        |> mes("to us as soon as possible.^000000''")
        |> next()
        |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
        |> mes("Although the sender's")
        |> mes("name isn't on this letter,")
        |> mes("I can guess who wrote it. ")
        |> mes("Speaking of which...")
        |> mes("Where's the geologist?")
        |> set_char_var(:aru_vol, 7)
        |> close()

      get_char_var(ctx, :aru_vol, 0) < 6 ->
        ctx |> describe_room() |> close()

      true ->
        ctx
    end
  end

  defp describe_room(ctx) do
    ctx
    |> mes("^3355FFThis house looks like")
    |> mes("it's been abandoned for")
    |> mes("a while: the floor is thickly")
    |> mes("covered with dust and many")
    |> mes("pieces of discarded paper.^000000")
  end
end
