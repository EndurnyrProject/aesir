defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsVeins.Colonel1 do
  @moduledoc """
  Colonel Vito intercepts the player in the volcano camp.

  ## Behavior

  - Advances the investigation and escorts the player to training.
  - Redirects the player again while training is pending.

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
        map: "thor_camp",
        x: 194,
        y: 220,
        dir: 0,
        sprite: -1,
        name: "",
        scope: :shared,
        unique_name: "#Colonel1",
        trigger: {5, 5}
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
    case get_char_var(ctx, :aru_vol, 0) do
      13 ->
        ctx =
          ctx
          |> enablenpc("Colonel Vito#1")
          |> mes("[????]")
          |> mes("You...!")
          |> mes("What are you doing")
          |> mes("just standing around?!")
          |> mes("Aren't you supposed to")
          |> mes("be transporting cargo? ")
          |> mes("Attention to orders!")
          |> next()

        ctx =
          ctx
          |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
          |> mes("Are you talking to me?")
          |> mes("No, I'm from the Veins Geo--")
          |> next()
          |> mes("[Colonel Vito]")
          |> mes("Look at you. You don't")
          |> mes("even have your uniform")
          |> mes("yet. Still a rookie, eh?")
          |> mes("Looks like I'll have to")
          |> mes("personally train you as")
          |> mes("one of our holy knights!")
          |> next()

        ctx
        |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
        |> mes("But I'm not--")
        |> next()
        |> mes("[Colonel Vito]")
        |> mes("You should be honored to")
        |> mes("have the rare opportunity")
        |> mes("to be trained by me, the")
        |> mes("great Colonel Vito. I'll mold")
        |> mes("you into a true warrior for")
        |> mes("Freya! Now follow me!")
        |> changequest(2122, 2123)
        |> set_char_var(:aru_vol, 14)
        |> close2()
        |> disablenpc("Colonel Vito#1")
        |> warp("thor_camp", 156, 68)

      14 ->
        ctx
        |> enablenpc("Colonel Vito#1")
        |> mes("[Colonel Vito]")
        |> mes("What are you still")
        |> mes("doing standing there?")
        |> mes("Don't slack off! Come!")
        |> close2()
        |> disablenpc("Colonel Vito#1")
        |> warp("thor_camp", 156, 68)

      _ ->
        ctx
    end
  end
end
