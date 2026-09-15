defmodule Aesir.ZoneServer.Content.Npc.Cities.Einbech.RyanDanger do
  @moduledoc """
  Delivers a drunken and unsettling tavern monologue to the player.

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
        map: "ein_in01",
        x: 277,
        y: 95,
        dir: 7,
        sprite: 855,
        name: "Ryan Danger",
        scope: :shared,
        unique_name: "Ryan Danger#air#einbech"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    player_header = "[#{char_name(ctx, 0)}]"

    ctx
    |> mes("[R.D. Kim]")
    |> mes("Oooh...")
    |> next()
    |> mes("[R.D. Kim]")
    |> mes("Oooh...")
    |> mes("Momma.")
    |> next()
    |> mes("[R.D. Kim]")
    |> mes("Oooh...")
    |> mes("Momma.")
    |> mes("You are so...")
    |> next()
    |> mes("[R.D. Kim]")
    |> mes("Oooh...")
    |> mes("Momma.")
    |> mes("You are so...")
    |> mes("^FF0000Hot^000000!")
    |> next()
    |> mes("[R.D. Kim]")
    |> mes("Why don't you take off")
    |> mes("those heavy, uncomfortable")
    |> mes("clothes? I'll buy you whatever")
    |> mes("you want, it's on me! C'mon~")
    |> next()
    |> mes(player_header)
    |> mes("N-no...!")
    |> mes("I-I-I-I...")
    |> mes("^666666(This is the")
    |> mes("shadiest guy")
    |> mes("I've ever seen!)^000000")
    |> next()
    |> mes("[R.D. Kim]")
    |> mes("Hm? No...?")
    |> mes("Absolutely no?")
    |> mes("Are you sure?")
    |> mes("Alright, alright.")
    |> mes("I'm sorry, I apologize.")
    |> mes("I was totally out of line.")
    |> next()
    |> mes("[R.D. Kim]")
    |> mes("...")
    |> mes("Or am I?")
    |> mes("Bwahahahaha!")
    |> next()
    |> mes(player_header)
    |> mes("(Th-this guy")
    |> mes("must be drunk out")
    |> mes("of his freakin' mind!)")
    |> close()
  end
end
