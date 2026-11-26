defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsNameless.ChiefOfficer do
  @moduledoc """
  The Chief Officer recruits adventurers to bring the Z Gang to justice.

  ## Behavior

  - Introduces the investigation, answers questions and rewards its completion.

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
        map: "prontera",
        x: 148,
        y: 326,
        dir: 3,
        sprite: 734,
        name: "Chief Officer",
        scope: :shared,
        unique_name: "Chief Officer#edq"
      }
    ]

  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  def on_talk(ctx) do
    cond do
      checkweight(ctx, [{907, 200}]) == 0 ->
        ctx
        |> mes("[Chief Officer]")
        |> mes("You're carrying far too")
        |> mes("much right now. Please")
        |> mes("lighten your load by")
        |> mes("placing your items")
        |> mes("in the Kafra Storage.")
        |> close()

      get_char_var(ctx, :zdan_edq, 0) == 0 and base_level(ctx) > 70 ->
        ctx
        |> mes("[Chief Officer]")
        |> mes("Adventurers, this is")
        |> mes("your chance to protect")
        |> mes("and serve your country!")
        |> mes("Please read the National")
        |> mes("Wanted Notice for more details.")
        |> close()

      get_char_var(ctx, :zdan_edq, 0) == 1 and base_level(ctx) > 70 ->
        ctx
        |> mes("[Chief Officer]")
        |> mes("Attention, attention.")
        |> mes("The Homeland Security Office")
        |> mes("of the Rune-Midgarts Kingdom")
        |> mes("is looking for any information")
        |> mes("regarding the Z Gang.")
        |> next()
        |> mes("[Chief Officer]")
        |> mes("There are three members:")
        |> mes("Louis Von Silokens a.k.a.")
        |> mes("Louis, Martha Hertizan a.k.a.")
        |> mes("Martha, and Catfoii a.k.a.")
        |> mes("Catfoii must be captured!")
        |> changequest(3119, 3120)
        |> set_char_var(:zdan_edq, 2)
        |> close()

      get_char_var(ctx, :zdan_edq, 0) == 1 and base_level(ctx) < 70 ->
        ctx
        |> mes("[Chief Officer]")
        |> mes("Oh, were you interested")
        |> mes("in pursuing the criminals")
        |> mes("listed in the Wanted notice?")
        |> mes("I'm sorry, but you're not")
        |> mes("ready for that kind of task...")
        |> mes("But I encourge you to train!")
        |> mes("Thank you.")
        |> close()

      get_char_var(ctx, :zdan_edq, 0) == 2 ->
        discuss_gang(ctx)

      get_char_var(ctx, :zdan_edq, 0) == 18 ->
        reward_investigator(ctx)

      true ->
        ctx
        |> mes("[Chief Officer]")
        |> mes("All those that oppose")
        |> mes("the peace and safety of")
        |> mes("our kingdom will not be")
        |> mes("spared the fury of our")
        |> mes("righteous swords!")
        |> close()
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  defp discuss_gang(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Chief Officer]")
      |> mes("Hello, Rune-Midgartian.")
      |> mes("What brings you here?")
      |> next()
      |> select(["National Wanted Notice", "Z Gang", "What crimes did Z Gang commit?"])

    case choice do
      1 ->
        ctx
        |> mes("[Chief Officer]")
        |> mes("Ah, were you interested")
        |> mes("in pursuing the Z Gang?")
        |> mes("Please carefully read the")
        |> mes("Wanted notice posted right")
        |> mes("next to me. We desperately")
        |> mes("need help to catch them.")
        |> next()
        |> mes("[Chief Officer]")
        |> mes("If you want to learn")
        |> mes("more about the Z Gang,")
        |> mes("I suggest talking to")
        |> mes("a knight named Valdes.")
        |> mes("He's fairly familiar with")
        |> mes("their brand of antics.")
        |> next()
        |> mes("[Chief Officer]")
        |> mes("Unfortunately, I fear")
        |> mes("that he may be ashamed")
        |> mes("of his failure to catch")
        |> mes("them. However, I am sure")
        |> mes("that he will be of service")
        |> mes("in your quest for justice.")
        |> close()

      2 ->
        {ctx, member} =
          ctx
          |> mes("[Chief Officer]")
          |> mes("You wanted to know more")
          |> mes("about the Z Gang members?")
          |> mes("I don'tknow much about them,")
          |> mes("but I can divulge what")
          |> mes("little I've heard.")
          |> next()
          |> select(["Louis", "Martha", "Catfoii", "Book of Forbidden Mystery?"])

        case member do
          1 ->
            ctx
            |> mes("[Chief Officer]")
            |> mes("Louis Von Silokens was")
            |> mes("the third son of the noble")
            |> mes("Silokens family which was")
            |> mes("ruined many years ago.")
            |> mes("According to record, he failed")
            |> mes("Magic Academy three times.")
            |> next()
            |> mes("[Chief Officer]")
            |> mes("It is believed that he formed")
            |> mes("the Z Gang as a result of")
            |> mes("his personal failure. He")
            |> mes("also stole the Book of")
            |> mes("Forbidden Mystery from")
            |> mes("the Royal Library.")
            |> next()
            |> mes("[Chief Officer]")
            |> mes("We must capture him and")
            |> mes("retrieve that book before")
            |> mes("he can abuse its power.")
            |> mes("We need the help of the")
            |> mes("people in order to find him")
            |> mes("and bring Louis to justice!")
            |> close()

          2 ->
            ctx
            |> mes("[Chief Officer]")
            |> mes("Martha Hertizan is the")
            |> mes("second daughter of Alberta's")
            |> mes("Hertizan family. No one knows")
            |> mes("why she ran away from home")
            |> mes("at the age of twenty.")
            |> next()
            |> mes("[Chief Officer]")
            |> mes("Martha handles the Z Gang's")
            |> mes("finances. It's a shame that")
            |> mes("such a talented merchant")
            |> mes("has stooped to thievery. ")
            |> close()

          3 ->
            ctx
            |> mes("[Chief Officer]")
            |> mes("We initially believed")
            |> mes("that Catfoii was just")
            |> mes("Louis and Martha's pet")
            |> mes("cat... But it's actually a")
            |> mes("master criminal. Approach")
            |> mes("it with extreme caution!")
            |> next()
            |> mes("[Chief Officer]")
            |> mes("That's all I know about")
            |> mes("that animal. The true")
            |> mes("nature of Catfoii is")
            |> mes("shrouded in mystery.")
            |> close()

          4 ->
            ctx
            |> mes("[Chief Officer]")
            |> mes("Out of all their crimes,")
            |> mes("their theft of the Book of")
            |> mes("Forbidden Mystery poses the")
            |> mes("greatest danger to the kingdom.")
            |> mes("If they misuse that book, it")
            |> mes("will cause grave disaster.")
            |> close()

          _ ->
            ctx
        end

      3 ->
        ctx
        |> mes("[Chief Officer]")
        |> mes("That damned Z Gang seems")
        |> mes("to be in the center of all the")
        |> mes("crime that's happening in")
        |> mes("Rune-Midgarts. They caused")
        |> mes("a riot in Geffen by spreading")
        |> mes("rumors about ghosts...")
        |> next()
        |> mes("[Chief Officer]")
        |> mes("They poisoned the")
        |> mes("drinking water in the")
        |> mes("wells of Payon, seized")
        |> mes("countless goods, profited")
        |> mes("off illegal trade... The list")
        |> mes("just keeps going on and on...")
        |> next()
        |> mes("[Chief Officer]")
        |> mes("Out of all their crimes,")
        |> mes("their theft of the Book of")
        |> mes("Forbidden Mystery poses the")
        |> mes("greatest danger to the kingdom.")
        |> mes("If they misuse that book, it")
        |> mes("will cause grave disaster.")
        |> close()

      _ ->
        ctx
    end
  end

  defp reward_investigator(ctx) do
    ctx =
      ctx
      |> mes("[Chief Officer]")
      |> mes("Oh, you were that nice")
      |> mes("adventurer that dropped")
      |> mes("by the other day. How")
      |> mes("may I help you?")
      |> next()
      |> mes("[Chief Officer]")
      |> mes("What's that?! You really")
      |> mes("found the Z Gang's hideout,")
      |> mes("captured them, and retrieved")
      |> mes("the forbidden book?")
      |> next()
      |> delitem(7724, 1)
      |> mes("[Chief Officer]")
      |> mes("Splendid! Just splendid!")
      |> mes("On behalf of the king,")
      |> mes("let me give you a well")
      |> mes("deserved reward. Thank")
      |> mes("you for your work on")
      |> mes("behalf of our kingdom!")
      |> next()
      |> mes("[Chief Officer]")
      |> mes("Your bravery and ardent")
      |> mes("patriotism will forever")
      |> mes("be recorded in the annals")
      |> mes("of Rune-Midgarts history.")
      |> mes("Congratulations! ")
      |> completequest(3134)
      |> set_char_var(:zdan_edq, 19)

    ctx
    |> getexp(if(Rathena.truthy?(checkre(ctx, 3)), do: 100_000, else: 1_000_000), 0)
    |> close()
  end
end
