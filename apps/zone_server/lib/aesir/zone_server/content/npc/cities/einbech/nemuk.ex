defmodule Aesir.ZoneServer.Content.Npc.Cities.Einbech.Nemuk do
  @moduledoc """
  Asks outsiders what they think of Einbech and reflects on leaving town.

  ## Behavior

  - Responds differently depending on whether the player approves of life in Einbech.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Muad_Dib

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "einbech",
        x: 172,
        y: 113,
        dir: 4,
        sprite: 855,
        name: "Nemuk",
        scope: :shared,
        unique_name: "Nemuk#ein"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Nemuk]")
      |> mes("You seem to be an")
      |> mes("outsider, so let me")
      |> mes("ask you something.")
      |> mes("What do you think ")
      |> mes("of Einbech?")
      |> next()
      |> select(["It's fine.", "It looks tough to live here."])

    case choice do
      1 ->
        ctx
        |> mes("[Nemuk]")
        |> mes("Huh...?")
        |> mes("I'm not sure what")
        |> mes("you've seen, but I'm")
        |> mes("surprised to hear you")
        |> mes("say something like that.")
        |> next()
        |> mes("[Nemuk]")
        |> mes("It's been ten years since")
        |> mes("I've started to think about")
        |> mes("moving out. However, I'm still")
        |> mes(
          "debating it. Now, if I were rich, I'd leave in no time, but it's hard getting the money to move out."
        )
        |> next()
        |> mes("[Nemuk]")
        |> mes("^333333*Sigh...*^000000")
        |> mes("Maybe if I had been")
        |> mes("an adventurer when I was")
        |> mes("younger, I wouldn't have")
        |> mes("these problems today...")
        |> close()

      2 ->
        ctx
        |> mes("[Nemuk]")
        |> mes("I thought so.")
        |> mes("Well, I apologize if")
        |> mes("I put you on the spot.")
        |> next()
        |> mes("[Nemuk]")
        |> mes("Everyone here has been")
        |> mes("having a tough time just")
        |> mes("living day to day for as long")
        |> mes("as I can remember. It's like")
        |> mes("things never seem to get any")
        |> mes("better, no matter what we do.")
        |> next()
        |> mes("[Nemuk]")
        |> mes("I really want to leave,")
        |> mes("but it's just an empty")
        |> mes("wish. My body is trapped")
        |> mes("here while my heart longs")
        |> mes("for a much better life. ^333333*Sigh*^000000")
        |> mes("Is it hopeless? What can I do?")
        |> close()

      _ ->
        ctx
    end
  end
end
