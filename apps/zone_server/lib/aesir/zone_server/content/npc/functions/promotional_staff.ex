defmodule Aesir.ZoneServer.Content.Npc.Functions.PromotionalStaff do
  @moduledoc """
  Promotional staff of the Ash-Vacuum recruitment drive, who pitches the journey beyond
  the time-space gap to curious adventurers.

  ## Behavior

  - Pitches the expedition and asks through a Yes/No menu whether the player wants the
    full story.
  - On "Yes" tells the story of the unknown land and sends the player to the kingdom
    receptionist in the first room of Prontera Castle.
  - On "No" mocks the player for lacking courage, and ends the script on either answer.

  ## Credits

  - Original from rAthena, authors and Contributors
    - L0ne_W0lf
    - Joseph
    - Euphy
    - Capuche

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script quests/quests_13_1.txt
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  import Aesir.ZoneServer.Script.Dsl

  alias Aesir.ZoneServer.Script.Ctx

  @doc """
  Callable rAthena global function `Promotional_Staff()`; throws `{:script_end, ctx}` once
  either answer's dialog ends the calling script.
  """
  @spec call(Ctx.t(), [term()]) :: no_return()
  def call(ctx, _args) do
    {ctx, answer} =
      ctx
      |> mes("[Promotional Staff]")
      |> mes("We are looking for adventurers who are super curious and extremely brave.")
      |> mes("Join us for a wonderful adventure!")
      |> next()
      |> mes("[Promotional Staff]")
      |> mes("Hey, you're a knowledgeable person, right? Are you interested in my story?")
      |> next()
      |> select(["Yes.", "No, thanks."])

    case answer do
      1 -> tell_story(ctx)
      2 -> mock(ctx)
      _ -> halt(ctx)
    end
  end

  defp tell_story(ctx) do
    ctx
    |> mes("[Promotional Staff]")
    |> mes("You're a real adventurer.")
    |> mes("Good for you!")
    |> mes("You won't regret it.")
    |> next()
    |> mes("[Promotional Staff]")
    |> mes("I usually send adventurers to")
    |> mes("newly found places for research.")
    |> mes("It's quite challeging, as nobody's ever been to these places.")
    |> next()
    |> mes("[Promotional Staff]")
    |> mes("The missions are quite dangerous,")
    |> mes("so only those who are courageous")
    |> mes("are qualified for the challenge")
    |> mes("of this mission.")
    |> next()
    |> mes("[Promotional Staff]")
    |> mes(
      "I'm not sure that you're strong enough, but you seem brave. How about going to the kingdom receptionist? He should be in the first room of Prontera Castle."
    )
    |> next()
    |> mes("[Promotional Staff]")
    |> mes("From what I've heard about this place... It's not a new continent.")
    |> mes("I don't know where it is.")
    |> mes("Hmm... Inside of the sky?")
    |> next()
    |> mes("[Promotional Staff]")
    |> mes("Could just be a rumor,")
    |> mes("but I don't know exactly.")
    |> mes("It's not my business.")
    |> next()
    |> mes("[Promotional Staff]")
    |> mes("Anyway, I'm supposed to inform many adventurers about it.")
    |> mes("There's no time to waste!")
    |> close()
    |> halt()
  end

  defp mock(ctx) do
    ctx
    |> mes("[Promotional Staff]")
    |> mes(
      "Huh, I thought you were a real adventurer. You're missing a big opportunity. You're definitely not brave. Absolutely not!"
    )
    |> close()
    |> halt()
  end

  defp halt(ctx), do: throw({:script_end, ctx})
end
