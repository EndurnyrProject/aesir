defmodule Aesir.ZoneServer.Content.Npc.Cities.Payon.Woman246158 do
  @moduledoc """
  Gossips about Payon's fortune teller and flirts with visitors.

  ## Behavior

  - Tailors her greeting to the visitor's sex.
  - Explains where to find the fortune teller when asked.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Muad Dib
    - Darkchild
    - DracoRPG
    - L0ne_W0lf

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "payon",
        x: 246,
        y: 158,
        dir: 5,
        sprite: 66,
        name: "Woman",
        scope: :shared,
        unique_name: "Woman#2payon",
        trigger: {0, 0}
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx =
      ctx
      |> mes("[Jim's Mother]")
      |> mes("Oh boy~")
      |> mes("There she goes again.")
      |> mes("Without a doubt, that")
      |> mes("woman is the town gossip.")
      |> next()
      |> mes("[Jim's Mother]")
      |> mes("Please don't judge the rest")
      |> mes(
        "of the people living in Payon by her behavior. She's the only loudmouth. I guess she's just too excited about what the fortune teller told her."
      )
      |> next()
      |> mes("[Jim's Mother]")
      |> greet_visitor()

    {ctx, choice} =
      ctx
      |> next()
      |> select(["Fortune Teller...? ", "Well, see you later~"])

    if choice == 1 do
      explain_fortune_teller(ctx)
    else
      say_goodbye(ctx)
    end
  end

  defp greet_visitor(ctx) do
    if sex(ctx) == get_char_var(ctx, :SEX_MALE, 0) do
      ctx
      |> mes("Ooh...!")
      |> mes("You've got")
      |> mes("such broad shoulders!")
      |> mes("Will you go out with me?")
      |> mes("I'll treat you to")
      |> mes("a nice dinner~")
    else
      ctx
      |> mes("My, you're a pretty girl!")
      |> mes("I'm sure you're always busy")
      |> mes("beating the boys away with a stick...")
      |> mes("Or a well timed insult joke.")
    end
  end

  defp explain_fortune_teller(ctx) do
    ctx
    |> mes("[Jim's Mother]")
    |> mes("Oh yes...")
    |> mes(
      "There's an extraordinary fortune teller in the Central Palace of Payon. The more Zeny you pay her, the better fortune you'll get!"
    )
    |> next()
    |> mes("[Jim's Mother]")
    |> mes("She told me")
    |> mes("I would meet")
    |> mes("a nice guy this month.")
    |> mes("Hohohoho~ ")
    |> close()
  end

  defp say_goodbye(ctx) do
    ctx
    |> mes("[Jim's Mother]")
    |> mes("Mmmm...?")
    |> mes("You don't have")
    |> mes("any time to stay")
    |> mes("and chit-chat with me?")
    |> close()
  end
end
