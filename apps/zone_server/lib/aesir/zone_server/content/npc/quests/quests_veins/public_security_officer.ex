defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsVeins.PublicSecurityOfficer do
  @moduledoc """
  Controls access to the imprisoned bard Vitre.

  ## Behavior

  - Accepts Lasda’s letter and authorizes a prison visit.

  ## Credits

  - Original from rAthena, authors and Contributors
    - L0ne_W0lf
    - Toms
    - Euphy
    - Joseph
    - Everade

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """
  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "morocc_in",
        x: 79,
        y: 163,
        dir: 0,
        sprite: 748,
        name: "Public Security Officer",
        scope: :shared
      }
    ]

  @impl true
  def on_talk(ctx) do
    quest = get_char_var(ctx, :que_sch, 0)

    cond do
      quest < 7 ->
        ctx
        |> mes("[Krieg]")
        |> mes("I'm in charge of public")
        |> mes("security here in Morocc.")
        |> mes("Lately, there have been")
        |> mes("more incidents disturbing")
        |> mes("the public peace and")
        |> mes("many unsettling rumors...")
        |> close()

      quest == 7 ->
        {ctx, _} =
          ctx
          |> mes("[Krieg]")
          |> mes("Hello, adventurer.")
          |> mes("How may I help you?")
          |> next()
          |> select(["I'd like to see a prisoner, Mr. Vitre."])

        ctx
        |> mes("[Krieg]")
        |> mes("Vitre? I'm sorry, but")
        |> mes("I can't approve of that.")
        |> mes("I'd allow visitors for normal")
        |> mes("prisoners, but not for people")
        |> mes("suspected of espionage.")
        |> mes("That's why he's in jail.")
        |> next()
        |> mes("[Krieg]")
        |> mes("If I knew you personally,")
        |> mes("or if someone I trust can")
        |> mes("vouch for you, then I'd")
        |> mes("reconsider letting you")
        |> mes("meet Vitre. Otherwise,")
        |> mes("I just can't do it.")
        |> set_char_var(:que_sch, 8)
        |> close()

      quest == 8 ->
        ctx
        |> mes("[Krieg]")
        |> mes("I can't let you meet")
        |> mes("Vitre until I'm absolutely")
        |> mes("sure that you're not involved")
        |> mes("with any espionage activities.")
        |> close()

      quest == 9 ->
        {ctx, _} =
          ctx
          |> mes("[Krieg]")
          |> mes("I can't let you meet")
          |> mes("Vitre until I'm absolutely")
          |> mes("sure that you're not involved")
          |> mes("with any espionage activities.")
          |> next()
          |> select(["Here's a letter from Lasda."])

        ctx
        |> mes("[Krieg]")
        |> mes("Lasda? Now there's a")
        |> mes("man I hold in high regard.")
        |> mes("Please let me read what")
        |> mes("he has to say. Hmmm...")
        |> next()
        |> mes("[Krieg]")
        |> mes("Alright, I'll let you visit")
        |> mes("Vitre. I'll send a message")
        |> mes("to the prison ward so that")
        |> mes("he'll let you talk to him.")
        |> set_char_var(:que_sch, 10)
        |> close()

      quest < 26 ->
        ctx
        |> mes("[Krieg]")
        |> mes("Hmm... This is almost too")
        |> mes("difficult for me to handle.")
        |> mes("What should I do?")
        |> close()

      true ->
        ctx
        |> mes("[Krieg]")
        |> mes("I understand that you were")
        |> mes("instrumental in solving a")
        |> mes("problem regarding public")
        |> mes("safety. I'd just like to thank")
        |> mes("you, and apologize for any")
        |> mes("trouble I might have caused.")
        |> close()
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end
end
