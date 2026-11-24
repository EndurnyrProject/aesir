defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsHugel.Perfitz do
  @moduledoc """
  Perfitz discusses his son and the proposed shops.

  ## Behavior

  - Advances the Memory Quest and shares his concerns about El Schatt.

  ## Credits

  - Original from rAthena, authors and Contributors
    - MasterOfMuppets
    - SinSloth
    - Samuray22
    - L0ne_W0lf
    - Euphy
    - Capuche

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [%{map: "hugel", x: 100, y: 103, dir: 3, sprite: 866, name: "Perfitz", scope: :shared}]

  @impl true
  def on_talk(ctx) do
    case get_char_var(ctx, :hg_memory, 0) do
      3 ->
        ctx
        |> set_char_var(:hg_memory, 4)
        |> mes("[Perfitz]")
        |> mes("I'm pleased that my son has")
        |> mes("finally set his mind on the")
        |> mes("family business. I didn't know")
        |> mes("he had it in him to become")
        |> mes("such a proactive entrepreneur.")
        |> next()
        |> mes("[Perfitz]")
        |> mes("It's funny... He used to")
        |> mes("deperately fight me when it")
        |> mes("came to building shops where")
        |> mes("that tree has planted. Yes, I'm")
        |> mes("proud that he's grown as a")
        |> mes("business person. Heh heh~")
        |> next()
        |> mes("[Perfitz]")
        |> mes("Although I'm pleased,")
        |> mes("I get this gut feeling that")
        |> mes("something's not right, like")
        |> mes("he's too excited about cutting")
        |> mes("that tree down. Maybe this old")
        |> mes("man is just too suspcious~")
        |> changequest(8059, 8060)
        |> close()

      4 ->
        ctx
        |> mes("[Perfitz]")
        |> mes("It's funny how things")
        |> mes("change. You know, El Schatt")
        |> mes("actually used to protest against my idea of building shops in the")
        |> mes("area when that tree grows. Hmm... I wonder, what happened to him?")
        |> close()

      _ ->
        ctx
        |> mes("[Perfitz]")
        |> mes("Money is very dependable...")
        |> mes("But it's value is relative, and")
        |> mes("can change at any moment.")
        |> mes("Still, at my age, you can't")
        |> mes("live without it. Make sure you")
        |> mes("financially prepare of old age.")
        |> next()
        |> mes("[Perfitz]")
        |> mes("Now, most people assume that")
        |> mes("I have very few friends because")
        |> mes("I trust money more than people.")
        |> mes("That's somewhat true: money")
        |> mes("will never betray you, and few")
        |> mes("friends can be so dependable.")
        |> next()
        |> mes("[Perfitz]")
        |> mes("However, friends that can")
        |> mes("be trusted for life are worth")
        |> mes("more than all the money in the")
        |> mes("world. To a rich man like me,")
        |> mes("those are the only friends")
        |> mes("that are worth having.")
        |> close()
    end
  end
end
