defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsRachel.Logan do
  @moduledoc """
  Logan is a servant who helps the search for Phobe.

  ## Behavior

  - Directs the adventurer to Manson for information about Phobe.

  ## Credits

  - Original from rAthena, authors and Contributors
    - L0ne_W0lf
    - Euphy

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "rachel",
        x: 114,
        y: 232,
        dir: 3,
        sprite: 869,
        name: "Logan",
        scope: :shared,
        unique_name: "Logan#ra_in01"
      }
    ]

  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  def on_talk(ctx) do
    cond do
      get_char_var(ctx, :lost_boy, 0) < 1 or get_char_var(ctx, :lost_boy, 0) >= 3 -> greeting(ctx)
      get_char_var(ctx, :lost_boy, 0) == 1 -> discuss_phobe(ctx)
      get_char_var(ctx, :lost_boy, 0) == 2 -> refer_to_manson(ctx)
      true -> ctx
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  defp greeting(ctx) do
    ctx
    |> mes("[Logan]")
    |> mes("I'm just Logan, one")
    |> mes("of the many servants")
    |> mes("working here in Sir Zhed's")
    |> mes("glorious mansion. I've got")
    |> mes("a lot of work to do, so don't")
    |> mes("don't distract me, please.")
    |> close()
  end

  defp discuss_phobe(ctx) do
    ctx =
      ctx
      |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
      |> mes("Excuse me, but do")
      |> mes("you know man named")
      |> mes("Phobe by any chance?")
      |> mes("I heard that he used")
      |> mes("to work around here.")
      |> next()
      |> mes("[Logan]")
      |> mes("Er, may I ask")
      |> mes("you are? Why are")
      |> mes("you looking for him?")
      |> next()

    ctx =
      ctx
      |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
      |> mes("Well, I've just been")
      |> mes("hired to look for him,")
      |> mes("and I was told that asking")
      |> mes("the servants around here")
      |> mes("was a good starting point.")
      |> next()
      |> mes("[Logan]")
      |> mes("Oh, okay. Yeah, Phobe's")
      |> mes("been missing ever since")
      |> mes("he left to buy stuff from")
      |> mes("the market a few days ago.")
      |> mes("I hope the kid is alright.")
      |> next()

    ctx
    |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
    |> mes("Er, kid? Just")
    |> mes("how old is Phobe?")
    |> next()
    |> mes("[Logan]")
    |> mes("He just turned fifteen.")
    |> mes("That's all I know about")
    |> mes("him. Truth be told, I don't")
    |> mes("know much since I just")
    |> mes("started working here. Why don't")
    |> mes("you ask the senior employees?")
    |> next()
    |> mes("[Logan]")
    |> mes("Let's see...")
    |> mes("You could ask Mr. Manson")
    |> mes("inside the mansion. He's")
    |> mes("been working here for a while.")
    |> set_char_var(:lost_boy, 2)
    |> changequest(8089, 8090)
    |> close()
  end

  defp refer_to_manson(ctx) do
    ctx
    |> mes("[Logan]")
    |> mes("If you want to learn")
    |> mes("more about Phobe, you'd")
    |> mes("better ask one of the senior")
    |> mes("employees since I just started")
    |> mes("working here. Mr. Manson in")
    |> mes("the mansion is a good bet.")
    |> close()
  end
end
