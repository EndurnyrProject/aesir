defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsNameless.Ishmael do
  @moduledoc """
  Helps Niren by forging a document for the player.

  ## Behavior

  - Accepts the file and requests a Sardonyx to replace her stolen pen.
  - Exchanges the gemstone for a forged file and advances the quest.

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
        map: "ra_fild03",
        x: 139,
        y: 355,
        dir: 5,
        sprite: 914,
        name: "Ishmael",
        scope: :shared,
        unique_name: "Ishmael#em"
      }
    ]

  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  def on_talk(ctx) do
    cond do
      checkweight(ctx, [{907, 200}]) == 0 ->
        ctx
        |> mes("^3355FFWait a second!")
        |> mes("Right now, you're carrying")
        |> mes("too many things with you.")
        |> mes("Please come back after")
        |> mes("using the Kafra Service")
        |> mes("to store some of your items.^000000")
        |> close()

      get_char_var(ctx, :aru_em, 0) < 17 ->
        ctx
        |> mes("[Ishmael]")
        |> mes("I-I don't know you, do I?")
        |> mes("Sorry, but would you, um,")
        |> mes("just step away? I... I don't")
        |> mes("like being too close to")
        |> mes("other people. Please!")
        |> emotion(:profusely_sweat)
        |> close()

      get_char_var(ctx, :aru_em, 0) == 17 ->
        {ctx, choice} =
          ctx
          |> mes("[Ishmael]")
          |> mes("I-I don't know you, do I?")
          |> mes("Sorry, but would you, um,")
          |> mes("just step away? Wait, you")
          |> mes("don't have something you")
          |> mes("need from me, do you?")
          |> emotion(:profusely_sweat)
          |> next()
          |> select(["Give Her Niren's File", "Leave Her Alone"])

        case choice do
          1 ->
            if count_item(ctx, 7343) > 0 do
              ctx
              |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
              |> mes("You know High Priestess")
              |> mes("Niren, right? This is from her.")
              |> next()
              |> mes("[Ishmael]")
              |> mes("Oh, really? Okay, just...")
              |> mes("Just toss the file over")
              |> mes("to me. I-I don't want")
              |> mes("you coming any closer.")
              |> emotion(:profusely_sweat)
              |> next()
              |> mes("[Ishmael]")
              |> mes("I'll be glad to help out")
              |> mes("the priestess. Even though")
              |> mes("we're natives, she's never")
              |> mes("discriminated against us.")
              |> mes("Hmm... What does she want?")
              |> next()
              |> mes("[Ishmael]")
              |> mes("Let's see... She wants")
              |> mes("me to forge a copy of this")
              |> mes("file? Piece of cake, I'm an")
              |> mes("expert at forging writing!")
              |> mes("Just give me a moment and--")
              |> next()
              |> emotion(:huk)
              |> mes("[Ishmael]")
              |> mes("Dang it! I completely forgot!")
              |> mes("Someone stole my pen yesterday!")
              |> mes("Now how am I gonna do this...?")
              |> next()
              |> emotion(:cry)
              |> mes("[Ishmael]")
              |> mes("My pen was made of a very")
              |> mes("rare gemstone called ^FF0000Sardonyx^000000.")
              |> mes("*Sob* I don't think anyone")
              |> mes("sells Sardonyx in Arunafeltz.")
              |> mes("You can only get that in the")
              |> mes("countries next to us...")
              |> next()
              |> mes("[Ishmael]")
              |> mes("I really want to help")
              |> mes("High Priestess Niren...")
              |> mes("I can't let her down after")
              |> mes("she's been so good to us...")
              |> set_char_var(:aru_em, 18)
              |> delitem(7343, 1)
              |> changequest(2137, 2138)
              |> close()
            else
              ctx
              |> mes("^3355FFYou seem to have")
              |> mes("misplaced Niren's file...^000000")
              |> close()
            end

          2 ->
            ctx
            |> mes("[Ishmael]")
            |> mes("I... I don't see you")
            |> mes("backing away. Stay back,")
            |> mes("and don't you dare touch me!")
            |> close()

          _ ->
            ctx
        end

      get_char_var(ctx, :aru_em, 0) == 18 ->
        if count_item(ctx, 725) > 0 do
          {ctx, choice} =
            ctx
            |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
            |> mes("Would you be able to forge")
            |> mes("a copy of High Priestess")
            |> mes("Niren's file if you had")
            |> mes("this gemstone?")
            |> next()
            |> mes("[Ishmael]")
            |> mes("Oh, you found")
            |> mes("a Sardonyx for me?")
            |> mes("It looks perfect!")
            |> next()
            |> mes("[Ishmael]")
            |> mes("Er, but, um...")
            |> mes("Would you please")
            |> mes("not come any closer?")
            |> mes("I still... Uh... I don't mean")
            |> mes("to be rude... It's just...")
            |> mes("I'm just not good with...")
            |> emotion(:profusely_sweat)
            |> next()
            |> mes("[Ishmael]")
            |> mes("If you just toss the")
            |> mes("Sardonyx over here,")
            |> mes("I'll be able to forge")
            |> mes("your copy right away.")
            |> next()
            |> select(["Don't Give It to Her", "Give It to Her"])

          case choice do
            1 ->
              ctx
              |> mes("[Ishmael]")
              |> mes("Huh? I thought you")
              |> mes("needed my help? I can't")
              |> mes("do anything unless you")
              |> mes("give me that gemstone.")
              |> close()

            2 ->
              ctx
              |> mes("[Ishmael]")
              |> mes("Yay, thank you so much!")
              |> mes("Now I can get to work~")
              |> next()
              |> mes("^3355FF*Scribble*")
              |> mes("*Scribble*^000000")
              |> specialeffect(:comboattack2)
              |> next()
              |> mes("^3355FF*Scribble*")
              |> mes("*Scribble*^000000")
              |> specialeffect(:comboattack4)
              |> next()
              |> mes("^3355FF*Scribble*")
              |> mes("*Scribble*^000000")
              |> mes("^3355FF*Scribble*")
              |> mes("*Scribble*^000000")
              |> specialeffect(:comboattack4)
              |> specialeffect(:steal)
              |> emotion(:aha)
              |> next()
              |> mes("[Ishmael]")
              |> mes("There you go! I made the")
              |> mes("best quality copy I could for")
              |> mes("you since High Priestess")
              |> mes("Niren requested for it.")
              |> mes("Would you please send")
              |> mes("her my regards? Heh heh~")
              |> next()
              |> mes("^3355FFYou received a file")
              |> mes("containing a forged")
              |> mes("written approval for")
              |> mes("vacation from Ishmael.^000000")
              |> delitem(725, 1)
              |> set_char_var(:aru_em, 19)
              |> give_item(7343, 1)
              |> changequest(2138, 2139)
              |> close()

            _ ->
              ctx
          end
        else
          ctx
          |> emotion(:cry)
          |> mes("[Ishmael]")
          |> mes("If only I only had")
          |> mes("my precious pen made")
          |> mes("of Sardonyx! Waaaah~!")
          |> close()
        end

      true ->
        ctx
        |> mes("[Ishmael]")
        |> mes("High Priestess Niren is")
        |> mes("such a nice lady. I have to")
        |> mes("help her out whenever I get")
        |> mes("the chance. Er, do you mind")
        |> mes("stepping back a bit? I just...")
        |> mes("I don't like being near people!")
        |> close()
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end
end
