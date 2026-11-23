defmodule Aesir.ZoneServer.Content.Npc.Functions.FCherno do
  @moduledoc """
  Presents the Cherno family introduction.

  ## Behavior

  - Ends the interaction if the player declines and returns to the caller after the family conversation.

  ## Credits

  - Original from rAthena, authors and contributors:
    - Samuray22
    - SinSloth
    - L0ne_W0lf
    - brianluau
    - Joseph
    - Euphy
    - Capuche

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  import Aesir.ZoneServer.Script.Dsl, warn: false

  @doc "Callable rAthena global function; returns `{ctx, return_value}`."
  def call(ctx, _args) do
    ctx =
      ctx
      |> specialeffect(:comboattack1, :area, "#exp_ein")
      |> mes("^33355F*Bang*^000000")
      |> next()
      |> specialeffect(:comboattack2, :area, "#exp_ein")
      |> mes("^33355F*Bang*^000000")
      |> next()
      |> specialeffect(:comboattack3, :area, "#exp_ein")
      |> mes("^33355F*Bang*^000000")
      |> next()
      |> specialeffect(:poisonattack, :area, "#exp_ein")
      |> mes("^33355F*Crash!*^000000")
      |> mes(".....")

    ctx = emotion(ctx, :sweat, getnpcid(ctx, "Theo Cherno"))

    ctx =
      ctx
      |> emotion(:sweat, getnpcid(ctx, "Tarsha Cherno"))
      |> next()
      |> mes("[Theo Cherno]")
      |> mes("Honey...")
      |> mes("I think there's")
      |> mes("a critical structural")
      |> mes("problem with the joint.")
      |> next()
      |> mes("[Tarsha Cherno]")
      |> mes("They must not")
      |> mes("be connected right.")
      |> mes("Maybe if we... Hmmm.")
      |> next()
      |> mes("[Theo Cherno]")
      |> mes("Well, let's call")
      |> mes("it a day and finish")
      |> mes("this tomorrow, yeah?")
      |> next()

    {ctx, choice} =
      ctx
      |> emotion(:question, getnpcid(ctx, "Tarsha Cherno"))
      |> mes("[Tarsha Cherno]")
      |> mes("Oh~")
      |> mes("I didn't know we")
      |> mes("had a guest. Hello,")
      |> mes("how are you doing?")
      |> mes("Are you interested in")
      |> mes("any of our inventions?")
      |> next()
      |> select(["Nothing.", "Your daughter asked me to visit you."])

    case choice do
      1 ->
        ctx =
          ctx
          |> mes("[Theo Cherno]")
          |> mes("Oh yes, my wife are")
          |> mes("I are keeping ourselves")
          |> mes("busy by conducting research.")
          |> mes("We're trying to invent new")
          |> mes("things for better living.")
          |> mes("It's what we do...")
          |> close()

        throw({:script_end, ctx})

      2 ->
        ctx = emotion(ctx, :sweat, getnpcid(ctx, "Tarsha Cherno"))

        ctx =
          ctx
          |> emotion(:sweat, getnpcid(ctx, "Theo Cherno"))
          |> mes("[Tarsha Cherno]")
          |> mes("Hahaha, Elle?")
          |> mes("Why would our")
          |> mes("daughter send")
          |> mes("you to visit us?")
          |> next()

        ctx =
          ctx
          |> mes("[#{char_name(ctx, 0)}]")
          |> mes("Well, uh...")
          |> mes("She wanted me to")
          |> mes("check if her mom")
          |> mes("was sick or sad")
          |> mes("...Or something?")
          |> next()

        ctx =
          ctx
          |> emotion(:huk, getnpcid(ctx, "Tarsha Cherno"))
          |> mes("[Tarsha Cherno]")
          |> mes("Oh my god...!")
          |> mes("What is she thinking?")
          |> mes("I apologize for troubling")
          |> mes("you over this kind of silly")
          |> mes("mistake, adventurer!")
          |> next()
          |> mes("[Theo Cherno]")
          |> mes("But wait, darling.")
          |> mes("I agree that sometimes")
          |> mes("you look like the loneliest")
          |> mes("person in the world, gazing")
          |> mes("out that window with those")
          |> mes("impossibly wistful eyes.")
          |> next()
          |> mes("[Tarsha Cherno]")
          |> mes("Oh, I must be")
          |> mes("making my family")
          |> mes("very anxious. But")
          |> mes("don't you worry, love.")
          |> mes("I'm very happy with")
          |> mes("you and Elle.")
          |> next()
          |> mes("[Tarsha Cherno]")
          |> mes("And...")
          |> mes("Kind adventurer,")
          |> mes("may I ask your name?")
          |> next()

        ctx =
          ctx
          |> mes("[#{char_name(ctx, 0)}]")
          |> mes("I am called,")

        ctx =
          ctx
          |> mes("#{char_name(ctx, 0)}.")
          |> emotion(:smile)
          |> next()
          |> mes("[Tarsha Cherno]")

        ctx =
          ctx
          |> mes("#{char_name(ctx, 0)},")
          |> mes("I appreciate your")
          |> mes("concern for us. Would")
          |> mes("you stay for a cup of tea?")
          |> next()
          |> mes("[Tarsha Cherno]")
          |> mes("Now, please pardon the")
          |> mes("mess. My husband and I are")
          |> mes("mechanical engineers focused")
          |> mes("on creating machines that would")
          |> mes("reduce the risk of mining ores.")
          |> next()
          |> mes("[Tarsha Cherno]")
          |> mes("Since we work at home, we")
          |> mes("can't avoid having machine")
          |> mes("parts lying here and there")
          |> mes("sometimes. In any case, we're")
          |> mes("hoping we create a machine that could make miners' lives safer...")
          |> next()

        ctx =
          ctx
          |> mes("[#{char_name(ctx, 0)}]")
          |> mes("Ah...")
          |> mes("So that's why")
          |> mes("there's so many")
          |> mes("interesting things")
          |> mes("in your house...")
          |> next()
          |> mes("^3355FFYou begin to")
          |> mes("take a look around")
          |> mes("the Cherno household.^000000")

        {ctx, nil}

      _ ->
        throw({:script_end, ctx})
    end
  end
end
