defmodule Aesir.ZoneServer.Content.Npc.Cities.Morocc.FlyMan do
  @moduledoc """
  Describes Dragon Fly and fears Satan Morocc’s destructive power.

  ## Behavior

  - Explains Dragon Fly after the player selects the sole inquiry.

  ## Credits

  - Original from rAthena, authors and Contributors
    - kobra_k88
    - L0ne_W0lf

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "moc_ruins",
        x: 174,
        y: 120,
        dir: 4,
        sprite: 54,
        name: "Fly Man",
        scope: :shared,
        unique_name: "Fly Man#moc"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Armani]")
      |> mes("Ooh, Woooowwww.")
      |> next()
      |> mes("[Armani]")
      |> mes(
        "I... I really saw it.... The Fly Lord gets shattered in pieces in a blink of an eye..."
      )
      |> next()
      |> mes("[Armani]")
      |> mes("What is really going on? Would it be possible for us to survive??")
      |> next()
      |> select(["The Fly Lord?!"])

    case choice do
      1 ->
        ctx
        |> mes("[Armani]")
        |> mes("Yes, yes! I'm talking about the Dragon Fly, master of all flies!!")
        |> mes("The Dragon Fly is a special one that stays in the North-east of the town.")
        |> next()
        |> mes("[Armani]")
        |> mes("It's so much stronger than the other flies.")
        |> next()
        |> mes("[Armani]")
        |> mes(
          "And when you kill it, there's even a chance that you might earn a ^880000Clip^000000 item!"
        )
        |> next()
        |> mes("[Armani]")
        |> mes("Anyways, don't you think the Satan Morocc is so cruel?")
        |> mes(
          "They may not be the same kind, but still isn't it cruel to take that monster's soul with a single blow?"
        )
        |> next()
        |> mes("[Armani]")
        |> mes("What should we do when this dreadful evil has come to life again!")
        |> close()

      _ ->
        ctx
    end
  end
end
