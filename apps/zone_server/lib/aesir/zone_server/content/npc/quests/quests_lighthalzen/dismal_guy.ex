defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsLighthalzen.DismalGuy do
  @moduledoc """
  Gushaar guides Secret Wing members toward the president.

  ## Behavior

  - Checks the membership card and explains the next mission.
  - Advances the investigation after briefing the player.

  ## Credits

  - Original from rAthena, authors and Contributors
    - L0ne_W0lf
    - Samuray22
    - Gepard
    - Euphy
    - Joseph
    - Capuche
    - JohnnyPlayy
    - Persian
    - Vicious_Pucca
    - aoa00
    - Evera
    - MasterOfMuppets
    - Lupus
    - Lord Gywall
    - DeNy
    - Vicious
    - Playtester
    - Silent
    - SinSloth

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "yuno_fild04",
        x: 165,
        y: 245,
        dir: 4,
        sprite: 89,
        name: "Dismal Guy",
        scope: :shared
      }
    ]

  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  def on_talk(ctx) do
    case get_char_var(ctx, :lhz_boss, 0) do
      stage when stage < 8 ->
        ctx
        |> mes("[Gushaar]")
        |> mes("Decisions, decisions.")
        |> mes("Sometimes it's hard to")
        |> mes("make a choice when it")
        |> mes("isn't clear which one will")
        |> mes("give you the most benefit.")
        |> next()
        |> mes("[Gushaar]")
        |> mes("I think most of the good")
        |> mes("things in life have some")
        |> mes("kind of cost, but they're")
        |> mes("usually worth it. I mean,")
        |> mes("nothing would have any")
        |> mes("worth without any cost, right?")
        |> close()

      8 ->
        choose_tonic(ctx)

      9 ->
        ctx
        |> mes("[Gushaar]")
        |> mes("Alright, first of all,")
        |> mes("you should know why the")
        |> mes("Rekenber Corporation is")
        |> mes("our sworn enemy. Did you")
        |> mes("know that it basically controls")
        |> mes("the Schwarzwald Republic?")
        |> next()
        |> mes("[Gushaar]")
        |> mes("They're so powerful, they")
        |> mes("manipulate everything in the")
        |> mes("economy, media and even the")
        |> mes("politics of this nation. There are other corporations, sure, but")
        |> mes("they're nothing in comparsion.")
        |> next()
        |> mes("[Gushaar]")
        |> mes("Rekenber Corporation...")
        |> mes("They've even got a hold on")
        |> mes("all the other companies, simply")
        |> mes("by bribing politicians to pass")
        |> mes("the bills they want passed.")
        |> mes("This isn't a real republic...")
        |> next()
        |> mes("[Gushaar]")
        |> mes("The ultimate goal of our")
        |> mes("group, ''Secret Wing,'' is to")
        |> mes("establish true independence")
        |> mes("in the Schwarzwald Republic")
        |> mes("by destroying Rekenber Corporation.")
        |> next()
        |> mes("[Gushaar]")
        |> mes("Fortunately, the new president")
        |> mes("of the Schwarzwald Republic,")
        |> mes("Mr. Weierstrass, is sympathetic")
        |> mes("to our cause. He is working with us to bring about a revolution and")
        |> mes("overthrow Rekenber Corporation.")
        |> next()
        |> mes("[Gushaar]")
        |> mes("Your mission will be to")
        |> mes("visit with the president and")
        |> mes("bring back any information")
        |> mes("he may have for us. Remember,")
        |> mes("because of his position, you can only see him during certain hours.")
        |> set_char_var(:lhz_boss, 10)
        |> close()

      10 ->
        ctx
        |> mes("[Gushaar]")
        |> mes("I hope you understand")
        |> mes("''Secret Wing's'' ultimate")
        |> mes("goal now. In any case, you've")
        |> mes("got to meet our president,")
        |> mes("Karl Theodor Weierstrass.")
        |> next()
        |> mes("[Gushaar]")
        |> mes("It won't be easy to see")
        |> mes("such an important man,")
        |> mes("so show your Secret Wing")
        |> mes("Membership Card to his")
        |> mes("secretary and there should")
        |> mes("be very little hassle.")
        |> next()
        |> mes("[Gushaar]")
        |> mes("Because of his schedule,")
        |> mes("you'll only be allowed to see")
        |> mes("him from ^FF00008:00 PM to 11:00 PM^000000,")
        |> mes("and from ^FF000011:00 AM to 2:00PM PST^000000.Good luck on this mission, friend.")
        |> set_char_var(:lhz_boss, 11)
        |> changequest(12_017, 12_018)
        |> close()

      _ ->
        ctx
        |> mes("[Gushaar]")
        |> mes("Rekenber...")
        |> mes("I shall see your")
        |> mes("destruction if it's the")
        |> mes("very last thing I do!")
        |> close()
    end
  end

  defp choose_tonic(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Gushaar]")
      |> mes("Alright. Choose")
      |> mes("your poison. I got")
      |> mes("two different kinds of")
      |> mes("tonics for you, red and blue.")
      |> mes("So which one will you drink?")
      |> next()
      |> select(["????", "Red Tonic", "Blue Tonic"])

    case choice do
      1 ->
        ctx
        |> mes("[Gushaar]")
        |> mes("Well, when you don't")
        |> mes("make a decision, you")
        |> mes("don't take action. And")
        |> mes("when you don't take any")
        |> mes("action, nothing happens.")
        |> mes("Come on, don't be boring~")
        |> close()

      2 ->
        show_card(ctx)

      3 ->
        ctx
        |> mes("[Gushaar]")
        |> mes("Blue...? Huh.")
        |> mes("That shouldn't be")
        |> mes("the one you want.")
        |> mes("Well, if you're who")
        |> mes("I think you are... Are you?")
        |> close()

      _ ->
        ctx
    end
  end

  defp show_card(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Gushaar]")
      |> mes("Red, huh? I like")
      |> mes("your style. But, eh,")
      |> mes("isn't there something")
      |> mes("you want to show me first?")
      |> next()
      |> select(["Oh, right!", "What are you talking about?"])

    case choice do
      1 ->
        if Rathena.truthy?(count_item(ctx, 7348)) do
          ctx
          |> mes("^3355FFYou suavely flash")
          |> mes("your Membership Card")
          |> mes("to Gushaar, who gives")
          |> mes("you an approving nod.^000000")
          |> next()
          |> mes("[Gushaar]")
          |> mes("Yeah, that's what")
          |> mes("I wanted to see. Good,")
          |> mes("you're the one I've been")
          |> mes("waiting here for. Alright,")
          |> mes("just give me a second...")
          |> set_char_var(:lhz_boss, 9)
          |> close()
        else
          ctx
          |> mes("[Gushaar]")
          |> mes("Hey... Umm...")
          |> mes("Aren't you supposed")
          |> mes("to be carrying some")
          |> mes("sort of secret something?")
          |> mes("I'd tell you want it was if we")
          |> mes("weren't so, well, secretive.")
          |> close()
        end

      2 ->
        ctx
        |> mes("[Gushaar]")
        |> mes("Huh?! Oh geez, I almost")
        |> mes("never make this mistake.")
        |> mes("I'm sorry, I thought you might")
        |> mes("have been someone else.")
        |> close()

      _ ->
        ctx
    end
  end
end
