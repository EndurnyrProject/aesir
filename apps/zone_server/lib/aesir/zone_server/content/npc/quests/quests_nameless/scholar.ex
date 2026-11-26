defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsNameless.Scholar do
  @moduledoc """
  An antique appraiser researches the Unlucky Emerald.

  ## Behavior

  - Shares the jewel’s history and directs its owner to a shaman.

  ## Credits

  - Original from rAthena, authors and Contributors
    - L0ne_W0lf
    - Koca
    - Yommy
    - brianluau
    - Euphy
    - Everade

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "comodo",
        x: 139,
        y: 184,
        dir: 3,
        sprite: 742,
        name: "Scholar",
        scope: :shared,
        unique_name: "Scholar#zgang"
      }
    ]

  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  def on_talk(ctx) do
    cond do
      get_char_var(ctx, :jewel_nd, 0) < 9 ->
        ctx
        |> mes("[Scholar]")
        |> mes("I'm an antique appraiser.")
        |> mes("You may think of me as similar")
        |> mes("to jewel appraisers, but I can")
        |> mes("appraise the historical value")
        |> mes("of antiques in addition to their quality and monetary value.")
        |> close()

      get_char_var(ctx, :jewel_nd, 0) == 9 ->
        ctx
        |> mes("[Scholar]")
        |> mes("Oooh. You must be the")
        |> mes("one sent by Ibrahim, right?")
        |> mes("You're the one that found")
        |> mes("that rare emerald, one of")
        |> mes("the accursed jewels?")
        |> next()
        |> mes("[Scholar]")
        |> mes("I'm very interested in the")
        |> mes("Cursed Jewels, and have been")
        |> mes("researching them. You came")
        |> mes("to just the right person if you")
        |> mes("wanted to learn more about")
        |> mes("the emerald that you found.")
        |> set_char_var(:jewel_nd, 11)
        |> close()

      get_char_var(ctx, :jewel_nd, 0) == 10 ->
        {ctx, _} =
          ctx
          |> mes("[Scholar]")
          |> mes("Hello, how may")
          |> mes("I help you today?")
          |> next()
          |> select(["Ask About Cursed Jewel"])

        {ctx, _} =
          ctx
          |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
          |> mes("I came to ask you")
          |> mes("about a Cursed Jewel.")
          |> next()
          |> mes("[Scholar]")
          |> mes("Let's see... Ah, did")
          |> mes("you come to ask about")
          |> mes("the Diamond of Destruction?")
          |> next()
          |> select(["No, it's the Unlucky Emerald."])

        ctx
        |> mes("[Scholar]")
        |> mes("Ah, the Unlucky Emerald?")
        |> mes("Yes, that was the most recent")
        |> mes("Cursed Jewel to be discovered.")
        |> mes("Let's see, where did I put all")
        |> mes("of my notes about that?")
        |> next()
        |> mes("[Scholar]")
        |> mes("Would you mind coming")
        |> mes("back later? I'm not sure")
        |> mes("where I misplaced my notes...")
        |> set_char_var(:jewel_nd, 11)
        |> close()

      get_char_var(ctx, :jewel_nd, 0) == 11 ->
        ctx
        |> mes("[Scholar]")
        |> mes("Ah, let's see now.")
        |> mes("There's a record here")
        |> mes("entitled, ''The Story of the")
        |> mes("Cursed Jewel.'' According")
        |> mes("to this, no one knows where")
        |> mes("these jewels were first found.")
        |> next()
        |> mes("[Scholar]")
        |> mes("The first incident involving")
        |> mes("the jewel involved a Comodo")
        |> mes("resident that used the jewel")
        |> mes("to pay a gambling debt. He")
        |> mes("committed suicide after he")
        |> mes("paid his debt, which is a pity.")
        |> next()
        |> mes("[Scholar]")
        |> mes("He didn't tell anyone")
        |> mes("where he found the jewel")
        |> mes("before he died, so we have")
        |> mes("no way of determining the")
        |> mes("jewel's true origins.")
        |> next()
        |> mes("[Scholar]")
        |> mes("After it was sold, the")
        |> mes("jewel came into a rich man's")
        |> mes("possession. However, he lost")
        |> mes("his fortune and was completely")
        |> mes("ruined after obtaining it. Hence the moniker, ''Unlucky Emerald.''")
        |> next()
        |> mes("[Scholar]")
        |> mes("Then the emerald came into")
        |> mes("the hands of a noble lady")
        |> mes("who mysteriously died at")
        |> mes("a young age. The emerald's")
        |> mes("had thousands of owners")
        |> mes("who just... Died.")
        |> next()
        |> mes("[Scholar]")
        |> mes("What's disturbing is that")
        |> mes("the emerald's curse seems")
        |> mes("to grow stronger with each")
        |> mes("life it takes away. Um, and")
        |> mes("your jewel perfectly matches")
        |> mes("the descriptions, so, uh...")
        |> next()
        |> mes("[Scholar]")
        |> mes("You are the new owner")
        |> mes("of the Unlucky Emerald.")
        |> mes("No one will buy that from")
        |> mes("you while it's still cursed.")
        |> mes("For the sake of your life,")
        |> mes("you must break that curse.")
        |> next()
        |> mes("[Scholar]")
        |> mes("Now, holy spells won't work")
        |> mes("on this kind of curse. You'll")
        |> mes("need to talk to a shaman.")
        |> mes("I think he lives in... Alberta?")
        |> mes("He can summon the dead")
        |> mes("and act as a medium for you.")
        |> next()
        |> mes("[Scholar]")
        |> mes("The idea is for you to talk")
        |> mes("to the spirits killed by this")
        |> mes("emerald through that shaman.")
        |> mes("And I'm sure he'll be pretty")
        |> mes("excited to see that you have")
        |> mes("the Unlucky Emerald with you.")
        |> set_char_var(:jewel_nd, 12)
        |> close()

      get_char_var(ctx, :jewel_nd, 0) == 12 ->
        ctx
        |> mes("[Scholar]")
        |> mes("Please find that shaman")
        |> mes("in Alberta, and ask if he can")
        |> mes("help you break the curse")
        |> mes("on that Unlucky Emerald.")
        |> close()

      get_char_var(ctx, :jewel_nd, 0) > 28 ->
        ctx
        |> mes("[Scholar]")
        |> mes("Wait, you're telling me")
        |> mes("that the emerald was cursed")
        |> mes("by the vindictive spirit of")
        |> mes("some warrior? Interesting...")
        |> mes("I should record this in my")
        |> mes("research notes. Thank you!")
        |> close()

      true ->
        ctx
        |> mes("[Scholar]")
        |> mes("Some jewels are said to")
        |> mes("be possessed by ghosts")
        |> mes("or evil spirits that will bring")
        |> mes("misfortune to their owners,")
        |> mes("drive them to death or")
        |> mes("insanity, that sort of thing.")
        |> close()
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end
end
