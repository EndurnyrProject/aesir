defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsHugel.Ashe1620 do
  @moduledoc """
  Ashe helps volunteers at the Odin Shrine excavation.

  ## Behavior

  - Her advice changes with quest progress and collected runes.

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
    spawn: [%{map: "hu_in01", x: 16, y: 20, dir: 4, sprite: 95, name: "Ashe", scope: :shared}]

  @rune_of_darkness 7511

  @impl true
  def on_talk(ctx) do
    case get_char_var(ctx, :hg_odin, 0) do
      0 ->
        ctx
        |> mes("[Ashe]")
        |> mes("Hello, may I help you?")
        |> mes("Please understand that")
        |> mes("unauthorized personnel")
        |> mes("are prohibited from entering")
        |> mes("this area. Have you come to")
        |> mes("assist in the expedition?")
        |> close()

      1 ->
        ctx
        |> mes("[Ashe]")
        |> mes("Oh, you've here in response")
        |> mes("to the recruitment notice?")
        |> mes("Well then, let me give you")
        |> mes("a brief idea about the work.")
        |> mes("First off, we can't pay you any")
        |> mes("money, so you'd be a volunteer.")
        |> next()
        |> mes("[Ashe]")
        |> mes("Instead, you're allowed to")
        |> mes("keep whatever you excavate")
        |> mes("in the Odin Shrine, so long")
        |> mes("as we don't need it for our")
        |> mes("research. This opportunity")
        |> mes("might prove worthwhile to you.")
        |> next()
        |> mes("[Ashe]")
        |> mes("Now, we should be working")
        |> mes("together with the Schwaltvalt")
        |> mes("Republic's Research Team, but")
        |> mes("our leaders aren't getting along at all. There's just a huge")
        |> mes("clash of personalities...")
        |> next()
        |> mes("[Ashe]")
        |> mes("In any case, if you'd")
        |> mes("like to join us in our")
        |> mes("efforts to uncover the")
        |> mes("secrets of the past, then")
        |> mes("please speak to Ms. Laurence.")
        |> close()

      v when v in [2, 12] ->
        ctx
        |> mes("[Ashe]")
        |> mes("So you're off to the")
        |> mes("Odin Shrine? Good luck,")
        |> mes("and be careful, alright?")
        |> close()

      v when v in [3, 13] ->
        ctx
        |> mes("[Ashe]")
        |> mes("Oh, you're back")
        |> mes("earlier than I thought!")
        |> mes("I think someone with")
        |> mes("your talent can be")
        |> mes("a really big help to us!")
        |> close()

      4 ->
        ctx
        |> mes("[Ashe]")
        |> mes("Hm? You've decided to")
        |> mes("help the Schwarzwald Team?")
        |> mes("That's fine, but I'm afraid")
        |> mes("Ms. Laurence may be a little")
        |> mes("upset by that. Well, it's fine")
        |> mes("with me. I don't really care.")
        |> close()

      v when v in [5, 6] ->
        ctx
        |> mes("[Ashe]")
        |> mes("How's the work coming")
        |> mes("along? I know the team")
        |> mes("leaders hate each other,")
        |> mes("but they should recognize")
        |> mes("that one person's victory")
        |> mes("in research is victory for all.")
        |> close()

      14 ->
        ctx |> mes("[Ashe]") |> mes("Please keep up") |> mes("the good work~") |> close()

      15 ->
        if count_item(ctx, @rune_of_darkness) > 4 do
          ctx
          |> mes("[Ashe]")
          |> mes("Well, it looks like")
          |> mes("everything turned out")
          |> mes("alright in the end, huh?")
          |> mes("Good work getting those runes.")
          |> close()
        else
          ctx
          |> mes("[Ashe]")
          |> mes("Oh, dear, you don't")
          |> mes("look very well. Did")
          |> mes("something happen?")
          |> close()
        end

      16 ->
        ctx
        |> mes("[Ashe]")
        |> mes("I know that Ms. Laurence")
        |> mes("can be... vocally aggressive,")
        |> mes("but I'm sure that she really")
        |> mes("appreciates all of your hard")
        |> mes("work. Thank you so much for")
        |> mes("all of your efforts~")
        |> close()

      17 ->
        ctx
        |> mes("[Ashe]")
        |> mes("Why does Ms. Laurence")
        |> mes("have to be this way?")
        |> mes("I honestly think this")
        |> mes("rivalry is awfully petty...")
        |> close()

      19 ->
        ctx
        |> mes("[Ashe]")
        |> mes("Ehm...")
        |> mes("Don't worry")
        |> mes("about it~")
        |> close()

      20 ->
        ctx
        |> mes("[Ashe]")
        |> mes("Please don't ask")
        |> mes("me about anything...")
        |> mes("Besides, I mean")
        |> mes("you no harm~")
        |> close()

      _ ->
        ctx
    end
  end
end
