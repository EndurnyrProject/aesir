defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsHugel.Makkie do
  @moduledoc """
  Makkie supplies a medicine ingredient for Morriphen and Siria.

  ## Behavior

  - Gives the player Red Plant Stem Powder and recounts his time with Dono and Morriphen.

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
    spawn: [%{map: "lhz_in03", x: 193, y: 28, dir: 3, sprite: 83, name: "Makkie", scope: :shared}]

  @impl true
  def on_talk(ctx) do
    case get_char_var(ctx, :hg_bio, 0) do
      4 ->
        provide_powder(ctx)

      v when v in [1, 2, 3] ->
        ctx
        |> mes("[Makkie]")
        |> mes("Gosh, I'm so bored~")
        |> mes("I wouldn't even mind")
        |> mes("having some work to do.")
        |> close()

      5 ->
        ctx
        |> mes("[Makkie]")
        |> mes("Hm? Shouldn't you hurry")
        |> mes("and get that bag of Red")
        |> mes("Plant Stem Powder to")
        |> mes("Dono as soon as you can?")
        |> close()

      v when v in [6, 7, 8, 9] ->
        ctx
        |> mes("[Makkie]")
        |> mes("Hey, have you seen")
        |> mes("Morriphen and Dono")
        |> mes("lately? I hope they're")
        |> mes("doing alright. Maybe")
        |> mes("I should go see them")
        |> mes("soon, for old time's sake.")
        |> close()

      _ ->
        ctx
        |> mes("[Makkie]")
        |> mes("Hey, welcome to the")
        |> mes("Lighthalzen Pub. Relax,")
        |> mes("and make yourself at home~")
        |> close()
    end
  end

  defp provide_powder(ctx) do
    ctx
    |> mes("[Makkie]")
    |> mes("Hello, how may")
    |> mes("I help you today?")
    |> next()
    |> mes("[#{char_name(ctx, 0)}]")
    |> mes("Hi, I'm here to get")
    |> mes("some Red Plant Stem")
    |> mes("Powder for Dono. It's")
    |> mes("pretty important, actually.")
    |> next()
    |> mes("[Makkie]")
    |> mes("Ah, I see. He must need")
    |> mes("it to prepare medicine for")
    |> mes("Morriphen and Siria, am")
    |> mes("I right? Okay, just give me")
    |> mes("a moment. While you're waiting, go ahead and relax, look around...")
    |> next()
    |> mes("^3355FFMakkie sifted the powder")
    |> mes("into a bag for you, you see")
    |> mes("a picture of Makkie, Dono,")
    |> mes("and Morriphen wearing white")
    |> mes("lab coats on the table.^000000")
    |> next()
    |> mes("[Makkie]")
    |> mes("Oh, that? Yeah, that was")
    |> mes("taken when Dono, Morriphen")
    |> mes("and I worked for the")
    |> mes("Rekenber Corporation. I know")
    |> mes("they look eccentric, but they're really good guys, trust me.")
    |> next()
    |> mes("[Makkie]")
    |> mes("Yeah, I used to work under")
    |> mes("Dono, actually. He was head")
    |> mes("of the Genetic Engineering")
    |> mes("Department, and Morriphen")
    |> mes("was doing other research.")
    |> mes("Those were some good times.")
    |> next()
    |> mes("[Makkie]")
    |> mes("Suddenly, me, Dono, and")
    |> mes("everyone else working under")
    |> mes("him was just fired! I was new")
    |> mes("at the time, so I was only able")
    |> mes("to learn why we were fired much")
    |> mes("later than everyone else.")
    |> next()
    |> mes("[Makkie]")
    |> mes("It turns out that there")
    |> mes("was a fire, possibly arson,")
    |> mes("in the Rekenber genetic labs.")
    |> mes("Dono assumed full responsibility, though everyone who worked for")
    |> mes("him just knows he didn't do it.")
    |> next()
    |> mes("[Makkie]")
    |> mes("So that's how we ended")
    |> mes("up at our current jobs.")
    |> mes("Strangely enough, Morriphen")
    |> mes("disappeared at the same time.")
    |> mes("I don't know what happened to him since our days at Rekenber...")
    |> next()
    |> mes("[Makkie]")
    |> mes("Anyway, when Morriphen")
    |> mes("showed up again, he ended up")
    |> mes("needing the medicine we're")
    |> mes("making. I sure wish I had a")
    |> mes("best friend like Dono or")
    |> mes("Morriphen. Those two are close.")
    |> next()
    |> mes("[Makkie]")
    |> mes("Yeah, Dono sure is a nice guy.")
    |> mes("He even helped me get this job~")
    |> mes("Anyway, if you see him, or if")
    |> mes("you visit Morriphen, please")
    |> mes("give them my regards. Here you")
    |> mes("are: Red Plant Stem Powder.")
    |> next()
    |> mes("^3355FFYou receive a small bag")
    |> mes("of Red Plant Stem Powder.^000000")
    |> set_char_var(:hg_bio, 5)
    |> changequest(11012, 11013)
    |> next()
    |> mes("[#{char_name(ctx, 0)}]")
    |> mes("Oh! Thanks so much")
    |> mes("for the powder. Now,")
    |> mes("I better hurry and give")
    |> mes("this to Dono. Goodbye~")
    |> close()
  end
end
