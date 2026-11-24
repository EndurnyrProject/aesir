defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsGonryun.YoungMan do
  @moduledoc """
  Neil tells adventurers about his recovery from illness.

  ## Behavior

  - Advances the Broken Sword quest by describing the doctor who cured him.

  ## Credits

  - Original from rAthena, authors and Contributors
    - KarLaeda
    - L0ne_W0lf
    - Paradox924X

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "prontera",
        x: 275,
        y: 86,
        dir: 2,
        sprite: 97,
        name: "Young man",
        scope: :shared,
        unique_name: "Young man#SaYumMoon"
      }
    ]

  @impl true
  def on_talk(ctx) do
    if get_char_var(ctx, :b_sword, 0) < 20 do
      ctx
      |> mes("[Neil]")
      |> mes("Oh man, it feels so good")
      |> mes("to be out of the hospital...")
      |> mes("I thought I was going to be")
      |> mes("there forever~!")
      |> next()
      |> mes("[Neil]")
      |> mes("Listen guy, appreciate")
      |> mes("your health, 'cuz almost")
      |> mes("nothing is worse than")
      |> mes("being really really sick...")
      |> close()
    else
      continue_story(ctx)
    end
  end

  defp continue_story(ctx) do
    ctx =
      ctx
      |> mes("[Neil]")
      |> mes("Not long ago, I was in the")
      |> mes("hospital, stuck lying in bed...")
      |> mes("No one knew what was wrong")
      |> mes("with me...but I grew weaker")
      |> mes("everyday...")
      |> next()
      |> mes("[Neil]")
      |> mes("But then, this ^FF5000doctor from Juno^000000")
      |> mes("arrived, and she helped me")
      |> mes("recover in no time!")
      |> mes("Though...I still can't walk so well.")
      |> next()
      |> mes("[Neil]")
      |> mes("All the other doctors had said")
      |> mes("my case was hopeless, and that")
      |> mes("I'd never recover. Luckily,")
      |> mes("this Juno doctor was able to")
      |> mes("find a cure...")
      |> next()
      |> mes("[Neil]")
      |> mes("It was a miracle!")
      |> mes("I'm so happy to be alive!")

    ctx =
      if get_char_var(ctx, :b_sword, 0) == 20 do
        set_char_var(ctx, :b_sword, 21)
      else
        ctx
      end

    close(ctx)
  end
end
