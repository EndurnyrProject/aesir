defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsNameless.Night do
  @moduledoc """
  Larjes reacts to the island at night.

  ## Behavior

  - On entering the area at the right quest stage, Larjes speaks and returns to the boat.

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
        map: "nameless_n",
        x: 169,
        y: 254,
        dir: 0,
        sprite: -1,
        name: "Night",
        scope: :shared,
        unique_name: "Night#Aru2",
        trigger: {3, 3}
      }
    ]

  alias Aesir.ZoneServer.Script.Rathena
  @impl true
  def on_event("OnTouch", ctx), do: ev_ontouch(ctx)
  @impl true
  def on_talk(ctx) do
    ctx
  end

  def ev_ontouch(ctx) do
    if get_char_var(ctx, :aru_monas, 0) == 20 do
      ctx = hideoffnpc(ctx, "Larjes#Monastery2")

      ctx =
        ctx
        |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
        |> mes("What the hell...!?")
        |> next()
        |> mes("[Larjes]")
        |> mes("So... This is the")
        |> mes("island's true nature.")
        |> next()
        |> mes("[Larjes]")
        |> mes("Someone like me won't")
        |> mes("survive long in a place")
        |> mes("like this. I'm going to wait")
        |> mes("for you in the boat. Learn")

      ctx
      |> mes(
        Rathena.concat(
          Rathena.concat(
            "what you need to learn, and then come back safe, ",
            char_name(ctx, 0)
          ),
          "."
        )
      )
      |> set_char_var(:aru_monas, 21)
      |> close2()
      |> hideonnpc("Larjes#Monastery2")
    else
      ctx
    end
  end
end
