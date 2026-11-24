defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsHugel.Girl do
  @moduledoc """
  Wintzil Trony tells the player about her father.

  ## Behavior

  - Directs the player to her father’s bookshelf during the rebellion quest.

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
    spawn: [
      %{
        map: "hu_in01",
        x: 310,
        y: 380,
        dir: 5,
        sprite: 891,
        name: "Girl",
        scope: :shared,
        unique_name: "Girl#hugel"
      }
    ]

  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  def on_talk(ctx) do
    progress = get_char_var(ctx, :hg_tre, 0)

    cond do
      progress < 47 ->
        ctx |> mes("[Girl]") |> mes("Bah, I am bored.") |> close()

      progress == 47 ->
        learn_about_father(ctx)

      progress > 48 ->
        ctx
        |> mes("[Wintzil Trony]")
        |> mes("I am bored and bored! When is my mom coming back?")
        |> close()

      true ->
        ctx
        |> mes("[Wintzil Trony]")
        |> mes("If you promise me that you will not break it,")
        |> mes("you can take a look at the shelf.")
        |> close()
    end
  end

  defp learn_about_father(ctx) do
    ctx
    |> mes("[Girl]")
    |> mes("Hehe...are you from another city?")
    |> mes("Heheh.")
    |> next()
    |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
    |> mes("Hey, little lady?")
    |> mes("By any chance, do you know a man named \"Wintzil Trony\"?")
    |> next()
    |> mes("[Girl]")
    |> mes("There is no man named Wintzil Trony.")
    |> next()
    |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
    |> mes("Huh?")
    |> next()
    |> mes("[Girl]")
    |> mes("I am the Wintzil Trony.")
    |> mes("I am a girl, not a man.")
    |> next()
    |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
    |> mes(
      "..............................................................................................................."
    )
    |> next()
    |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
    |> mes("(^3131FFOh dear Odin, am I on a test?")
    |> mes("Or are you trying to make sure that I still have a good memory?")
    |> mes("How could...how could...how could this little child")
    |> mes("is the last mercenary soldier?! This is absurd!)")
    |> next()
    |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
    |> mes("Well...lady,")
    |> next()
    |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
    |> mes("Are you sure that you are the last mer....no, no.")
    |> mes("Then do you have any family member who shares the same name as yours?")
    |> mes("Like your father, for instance.")
    |> next()
    |> mes("[Wintzil Trony]")
    |> mes("I said, I am the only Wintzil Trony in my family.")
    |> mes("And I don't have a father.")
    |> mes("My mom is out of Hugel to sell Hugel's principal products.")
    |> next()
    |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
    |> mes("Did...did your father pass away?")
    |> next()
    |> mes("[Wintzil Trony]")
    |> mes("I can't help it. He was too old.")
    |> next()
    |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
    |> mes("Well...do you remember what your father")
    |> mes("used to do when he was alive?")
    |> next()
    |> mes("[Wintzil Trony]")
    |> mes("My father sowed seeds.")
    |> next()
    |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
    |> mes("(^3131FFGosh, she is not helping! This is not good!^000000)")
    |> next()
    |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
    |> mes("Well, lady, I think that people usually")
    |> mes("say \"cultivate a field\" instead of saying \"sowing seeds\".")
    |> mes("Did you know that?")
    |> next()
    |> mes("[Wintzil Trony]")
    |> mes("^3131FFBut my father had only one arm,")
    |> mes("so he couldn't do such a hard work like cultivating a field.^000000")
    |> mes("But, it was alright. I could help him because I am strong enough.")
    |> mes("I cultivated fields with my mom and my father.")
    |> mes("Do you want to know how strong I am? Look at this! Yap!")
    |> next()
    |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
    |> mes(".................!")
    |> next()
    |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
    |> mes("Umm...lady, can you show me your father's picture")
    |> mes("or something that used to belong to him?")
    |> next()
    |> mes("[Wintzil Trony]")
    |> mes("Beh~ You are just like the guy who came by a long time ago.")
    |> mes("He kept asking me things over and over again,")
    |> mes("then he became upset and left.")
    |> next()
    |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
    |> mes("(He might be the news reporter from the Light News.)")
    |> next()
    |> mes("[Wintzil Trony]")
    |> mes("My father was a farmer. That's all I can say.")
    |> mes("Beeeeh~")
    |> next()
    |> mes("[Wintzil Trony]")
    |> mes("I am living in a house that is pretty empty.")
    |> mes("All my father left to us is the shelf at the upstairs.")
    |> next()
    |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
    |> mes("Do you mind if I take a look at your father's shelf?")
    |> next()
    |> mes("[Wintzil Trony]")
    |> mes("Sure!")
    |> mes("It is filled with books, and they don't look that interesting.")
    |> mes("But, can you be careful to treat the shelf? It is a keepsake from my father.")
    |> set_char_var(:hg_tre, 48)
    |> close()
  end
end
