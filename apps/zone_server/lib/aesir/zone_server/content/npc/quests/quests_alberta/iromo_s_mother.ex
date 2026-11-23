defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsAlberta.IromoSMother do
  @moduledoc """
  Iromo's mother worries about her reclusive son.

  ## Behavior

  - Starts Iromo’s quest for eligible adventurers and offers clues about his favorite food.

  ## Credits

  - Original from rAthena, authors and contributors:
    - kobra_k88
    - Lupus
    - Evera
    - DZeroX
    - L0ne_W0lf
    - Kisuka
    - Euphy

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "alberta_in",
        x: 120,
        y: 93,
        dir: 3,
        sprite: 53,
        name: "Iromo's Mother",
        scope: :shared,
        unique_name: "Iromo's Mother#ep3_2"
      }
    ]

  @impl true
  def on_talk(ctx) do
    cond do
      get_char_var(ctx, :ep13_2_hiki, 0) >= 8 ->
        ctx
        |> mes("[Mother]")
        |> mes("Thank you for helping my son.")
        |> mes("But I think we can't do anything")
        |> mes("about him anymore.")
        |> next()
        |> mes("[Mother]")
        |> mes("Iromo was really active and")
        |> mes("curious about the world.")
        |> mes("He wanted to see all the")
        |> mes("sights of the world.")
        |> next()
        |> mes("[Mother]")
        |> mes("But look at him now.")
        |> mes("He doesn't go out anymore.")
        |> mes("He is just stuck inside of his room.")
        |> next()
        |> mes("[Mother]")
        |> mes("He became a timid person.")
        |> mes("If he has an argument with me,")
        |> mes("he doesn't talk to me for a week.")
        |> next()
        |> mes("[Mother]")
        |> mes("You might have")
        |> mes("a hard time getting")
        |> mes("Iromo to talk to you.")
        |> close()

      get_char_var(ctx, :ep13_2_hiki, 0) == 7 ->
        ctx
        |> mes("[Mother]")
        |> mes("Oh, I remember")
        |> mes("what happened last time...")
        |> mes("One day, Iromo came home")
        |> mes("with tears in his eyes")
        |> mes("And he seemed hurt.")
        |> next()
        |> mes("[Mother]")
        |> mes("It was not a big injury.")
        |> mes("I was worried about him so much.")
        |> mes("But, he never tells me what happened that day.")
        |> next()
        |> mes("[Mother]")
        |> mes("After that day, he hasn't talked to people much and doesn't go out at all.")
        |> next()
        |> mes("[Mother]")
        |> mes("I hope he tells me what happened that day.")
        |> mes("Iromo was such a good boy...")
        |> close()

      get_char_var(ctx, :ep13_2_hiki, 0) == 4 or get_char_var(ctx, :ep13_2_hiki, 0) == 5 or
          get_char_var(ctx, :ep13_2_hiki, 0) == 6 ->
        ctx
        |> mes("[Mother]")
        |> mes("Hum.. Iromo's favorite?")
        |> mes("Let me think...")
        |> mes("Actually he likes all kinds of food.")
        |> mes("He is not picky about food.")
        |> next()
        |> mes("[Mother]")
        |> mes("When he went out with friends,")
        |> mes("he spent all his pocket money,")
        |> mes("but I don't know what he has been eating.")
        |> next()
        |> mes("[Mother]")
        |> mes("Oh, why don't you ask Iromo's friend?")
        |> mes("I think he would know about his favorite food.")
        |> close()

      get_char_var(ctx, :ep13_2_hiki, 0) == 2 or get_char_var(ctx, :ep13_2_hiki, 0) == 3 ->
        ctx
        |> mes("[Mother]")
        |> mes("Hum.. Iromo's favorite?")
        |> mes("Let me think...")
        |> mes("Actually he likes all kinds of food.")
        |> mes("He is not picky about food.")
        |> next()
        |> mes("[Mother]")
        |> mes("When he went out with friends,")
        |> mes("he spent all his pocket money,")
        |> mes("but I don't know what he has been eating.")
        |> next()
        |> set_char_var(:ep13_2_hiki, 3)
        |> mes("[Mother]")
        |> mes("Oh, why don't you ask Iromo's friend?")
        |> mes("I think he would know about his favorite food.")
        |> close()

      true ->
        ctx =
          ctx
          |> mes("[Mother]")
          |> mes("This little boy is my son, Iromo.")
          |> next()
          |> mes("[Mother]")
          |> mes("He used to go out all the time.")
          |> mes("He loved playing outside with friends.")
          |> next()
          |> mes("[Mother]")
          |> mes("But, somehow...")
          |> mes("he doesn't go out anymore.")
          |> next()

        ctx =
          if base_level(ctx) > 40 and checkquest(ctx, 10079) == -1 do
            ctx |> set_char_var(:ep13_2_hiki, 1) |> setquest(10079)
          else
            ctx
          end

        ctx
        |> mes("[Mother]")
        |> mes("I am so worried about him...")
        |> mes("What happened to him..?")
        |> close()
    end
  end
end
