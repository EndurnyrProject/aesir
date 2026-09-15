defmodule Aesir.ZoneServer.Content.Npc.Cities.Lutie.Hashokii do
  @moduledoc """
  Performs as Lutie's clown and shares part of Snowysnow's story.

  ## Behavior

  - Talks about devising a show for Charu Charu and Marcell.
  - At story stage 8, reveals how Snowysnow protected the orphans and advances the story to stage 9.

  ## Credits

  - Original from rAthena, authors and Contributors
    - rAthena Dev Team

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [%{map: "xmas", x: 146, y: 136, dir: 4, sprite: 715, name: "Hashokii", scope: :shared}]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Hashokii]")
      |> mes("Meeee~RrrrrYYYY Christmas~!")
      |> mes("La La La~!")
      |> mes("Dum di Dum di Dum!")
      |> next()
      |> select(["Yo Clown boy, what's up?", "About Snowysnow", "Quit conversation"])

    case choice do
      1 -> discuss_show(ctx)
      2 -> discuss_snowysnow(ctx)
      3 -> say_goodbye(ctx)
      _ -> ctx
    end
  end

  defp discuss_show(ctx) do
    ctx
    |> mes("[Hashokii]")
    |> mes("La La La~!")
    |> mes("Dum di Dum di Dum!")
    |> mes("Ooh, I'm trying to think of a good show to put on for Charu Charu and Marcell!")
    |> next()
    |> mes("[Hashokii]")
    |> mes(
      "They are getting smarter and wittier everyday, and now it seems that they don't laugh at my best jokes anymore. How did they get to be so clever?"
    )
    |> next()
    |> mes("[Hashokii]")
    |> mes(
      "Well, if I work hard enough, they can't help but laugh at my hilarious jokes! So... I better start inventing better jokes. Like, pronto."
    )
    |> next()
    |> mes("[Hashokii]")
    |> mes("La La La~!")
    |> mes("Dum di Dum di Dum")
    |> mes("Merry Christmas!")
    |> close()
  end

  defp discuss_snowysnow(ctx) do
    if get_char_var(ctx, :xmas_npc, 0) == 8 do
      reveal_orphans_story(ctx)
    else
      praise_snowysnow(ctx)
    end
  end

  defp reveal_orphans_story(ctx) do
    ctx
    |> mes("[Hashokii]")
    |> mes("Dum di Dum di Dum")
    |> mes("Ah ha! So you wanna learn more about Snowyshow! Let's see...")
    |> next()
    |> mes("[Hashokii]")
    |> mes("Well, there are two naughty kids,")
    |> mes("^3355FF' Charu Charu '^000000 and")
    |> mes(
      "^3355FF' Marcell '^000000. They attend my show regularly. I'm guessing you've heard the story from Cantata?"
    )
    |> next()
    |> mes("[Hashokii]")
    |> mes(
      "Anyway, the two babies that were protected in Snowysnow's bosom? Yup, that's them. But Charu Charu and Marcell don't seem to know that Snowysnow saved them."
    )
    |> next()
    |> mes("[Hashokii]")
    |> mes(
      "Snowysnow told me the story of how he let his body fly into the air to block the giant fire ball that was about to hit them when they were babies. For their sake, he was willing to sacrifice himself."
    )
    |> next()
    |> mes("[Hashokii]")
    |> mes(
      "Why don't you go meet those 2 children? They might tell you the story we've never got the chance to hear. Okay then, good luck~! Bye bye!"
    )
    |> set_char_var(:xmas_npc, 9)
    |> close()
  end

  defp praise_snowysnow(ctx) do
    ctx
    |> mes("[Hashokii]")
    |> mes("Ah... ^3355FFSnowysnow^000000?")
    |> mes(
      "Of course I know him! Anyone who doesn't know Snowysnow is a total stranger around here! Sometimes, he and I share a nice chat..."
    )
    |> next()
    |> mes("[Hashokii]")
    |> mes(
      "He makes such a good audience for my show. But to be honest, I'm not sure if he really likes it or not. Most people don't seem to care for my jokes."
    )
    |> next()
    |> mes("[Hashokii]")
    |> mes(
      "It totally baffles me! How could they not like the best jokes in the world?! Sheeeeesh~"
    )
    |> next()
    |> mes("[Hashokii]")
    |> mes("Hmmm, sorry!")
    |> mes("Anyway, Snowysnow")
    |> mes("is a great guy!")
    |> mes("La La La~!")
    |> mes("Dum di Dum di Dum")
    |> mes("Merry Christmas- !!")
    |> close()
  end

  defp say_goodbye(ctx) do
    ctx
    |> mes("[Hashokii]")
    |> mes("La La La~!")
    |> mes("Dum di Dum di Dum")
    |> mes("Merry Christmas~!")
    |> close()
  end
end
