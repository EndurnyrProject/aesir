defmodule Aesir.ZoneServer.Content.Npc.Cities.Aldebaran.FussyMan do
  @moduledoc """
  Pleads for help finding his missing pet chicken.

  ## Credits

  - Original from rAthena, authors and Contributors
    - rAthena Dev Team
    - L0ne_W0lf

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "aldeba_in",
        x: 152,
        y: 47,
        dir: 4,
        sprite: 97,
        name: "Fussy Man",
        scope: :shared,
        unique_name: "Fussy Man#alde"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Fussy Man]")
      |> mes("Aaaaarrrggghhh...I AM IN TROUBLE!")
      |> mes("My little chicken has left me!")
      |> mes("Oh, my god! Oh, my god!")
      |> next()
      |> select(["What do you call the chicken?", ". . . . ."])

    if choice == 1 do
      ask_about_name(ctx)
    else
      lament_missing_chicken(ctx)
    end
  end

  defp ask_about_name(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Fussy Man]")
      |> mes("I used to call it 'Amazing Picky'...")
      |> mes("*Sob* What should I do! How could this happen!")
      |> mes("Please, please help me to find my sweet little chicken!")
      |> next()
      |> select(["What? That is such a boring name!", ". . . . ."])

    if choice == 1 do
      ctx
      |> mes("[Fussy Man]")
      |> mes("Don't be so ridiculous!")
      |> mes("'Amazing Picky' is the most wonderful and the most unique name")
      |> mes("in this world, and my chicken deserves the name!")
      |> close()
    else
      lament_missing_chicken(ctx)
    end
  end

  defp lament_missing_chicken(ctx) do
    ctx
    |> mes("[Fussy Man]")
    |> mes("You don't care, do you?")
    |> mes(
      "I am only child in my family, so I have been thinking of my little chicken as my brother!"
    )
    |> mes("I want my chicken back...*Sob*")
    |> close()
  end
end
