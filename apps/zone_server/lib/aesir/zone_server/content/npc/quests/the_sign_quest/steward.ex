defmodule Aesir.ZoneServer.Content.Npc.Quests.TheSignQuest.Steward do
  @moduledoc """
  Provides the Brayde estate steward's dialogue during The Sign quest.

  ## Behavior

  - Offers visitors a menu before the quest and answers questions during early stages.
  - Shares observations that change as the quest progresses.

  ## Credits

  - Original from rAthena, authors and Contributors
    - SinSloth
    - MasterOfMuppets
    - Kargha
    - L0ne_W0lf
    - Kazukin
    - Kisuka
    - CalciumKid
    - tr0n
    - Euphy
    - Joseph
    - Capuche

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  - Changed the original `sign_q < 14` check to `sign_q < 12` to reach the stage 12 dialogue.
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "prt_in",
        x: 228,
        y: 26,
        dir: 5,
        sprite: 55,
        name: "Steward",
        scope: :shared,
        unique_name: "Steward#sign"
      }
    ]

  alias Aesir.ZoneServer.Content.Npc.Functions.FUpdatesignvars
  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  def on_talk(ctx) do
    {ctx, _} = FUpdatesignvars.call(ctx, [])
    ctx = mes(ctx, "[Vandez]")
    stage = get_char_var(ctx, :sign_q, 0)

    cond do
      stage < 3 ->
        greet_visitor(ctx)

      stage < 12 ->
        answer_questions(ctx)

      stage < 13 ->
        ctx
        |> mes("I recall that")
        |> mes("Master Arian visited")
        |> mes("the master a while ago.")
        |> mes("They spent all night")
        |> mes("discussing something")
        |> mes("related to the master's work.")
        |> next()
        |> mes("[Vandez]")
        |> mes("Goodness, it sounded")
        |> mes("dreadfully serious. The")
        |> mes("term, 'ancient power' is")
        |> mes("usually not mentioned")
        |> mes("quite often in conversation.")
        |> close()

      stage < 15 ->
        ctx
        |> mes("Sometimes I worry")
        |> mes("about Mistress Elle.")
        |> mes("She's one of the most")
        |> mes("beautiful girls in Prontera,")
        |> mes("but does not have a boyfriend.")
        |> next()
        |> mes("[Vandez]")
        |> mes("Many men have given her")
        |> mes("a great deal of attention, but")
        |> mes("she always manages to reject")
        |> mes("every single suitor...")
        |> close()

      stage < 20 ->
        ctx
        |> mes("Many travellers have")
        |> mes("begun to visit the master")
        |> mes("lastly. Apparently, they've")
        |> mes("been led here by the sign")
        |> mes("boards we've posted.")
        |> next()
        |> mes("[Vandez]")
        |> mes("Take heed and")
        |> mes("do not let anyone")
        |> mes("else take the opportunity")
        |> mes("the master has presented")
        |> mes("away from you.")
        |> close()

      stage < 25 ->
        ctx
        |> mes("It's most curious,")
        |> mes("but Elle seems to")
        |> mes("consider that unrefined")
        |> mes("Jesqurienne as her rival.")
        |> mes("Women are truly difficult")
        |> mes("for me to understand...")
        |> close()

      stage < 35 ->
        ctx
        |> mes("Avarice knows no bounds.")
        |> mes("The pastime of gambling")
        |> mes("seems to best represent")
        |> mes("mankind's greed.")
        |> next()
        |> mes("[Vandez]")
        |> mes("Winning or losing, some")
        |> mes("gamblers always seem to find")
        |> mes("some reason to continue when")
        |> mes(
          "it's smarter to stop. Then again, the mind usually doesn't take precedence over the heart..."
        )
        |> close()

      stage < 54 ->
        ctx
        |> mes("Bakerlan is a young,")
        |> mes("brilliant man. Although")
        |> mes("he inherited his company,")
        |> mes("it takes talent to continue")
        |> mes("his father's successes.")
        |> next()
        |> mes("[Vandez]")
        |> mes("It's amazing that Bakerlan")
        |> mes("is also managing to expand")
        |> mes("his business even further.")
        |> mes("Of course, Master Metz has")
        |> mes("had a role in Bakerlan's")
        |> mes("success...")
        |> close()

      stage == 54 ->
        ctx
        |> mes("Oh, congratulations~")
        |> mes("You finally passed all")
        |> mes("of the tests. I know they")
        |> mes("must have been incredibly")
        |> mes("taxing and challenging.")
        |> next()
        |> mes("[Vandez]")
        |> mes("Master Metz has informed")
        |> mes("me that he wishes for you")
        |> mes("to restore find someone")
        |> mes("to restore the Sobbing")
        |> mes("Starlight. I wish you luck")
        |> mes("in that endeavor.")
        |> close()

      stage == 97 or stage == 98 ->
        ctx
        |> mes("Although humans make")
        |> mes("mistakes, there are those")
        |> mes("times when failing cannot")
        |> mes("be an option.")
        |> next()
        |> mes("[Vandez]")
        |> mes("There will always")
        |> mes("be situations where")
        |> mes("you won't be getting")
        |> mes("any second chances.")
        |> mes("Anyways remember that.")
        |> close()

      true ->
        ctx
        |> mes("There will always")
        |> mes("be situations where")
        |> mes("you won't be getting")
        |> mes("any second chances.")
        |> mes("Anyways remember that.")
        |> close()
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  defp greet_visitor(ctx) do
    {ctx, choice} =
      ctx
      |> mes("Welcome to the")
      |> mes("Brayde Estate. How")
      |> mes("may I be of service?")
      |> next()
      |> select(["Nothing.", "I'm here to see Metz.", "Gimmie your cash!"])

    case choice do
      1 ->
        ctx
        |> mes("[Vandez]")
        |> mes("If you do not have")
        |> mes("any business to conduct")
        |> mes("with Master Metz, please")
        |> mes("leave immediately.")
        |> close()

      2 ->
        ctx
        |> mes("[Vandez]")
        |> mes(Rathena.concat("Very good, ", if(sex(ctx) == 1, do: "sir.", else: "madam.")))
        |> mes("Please wait a moment")
        |> mes("while I consult with")
        |> mes("the master in his study.")
        |> close()

      3 ->
        ctx
        |> mes("[Vandez]")
        |> mes("My apologies,")
        |> mes("but I insist that")
        |> mes("you leave the premises")
        |> mes("^FF0000immediately^000000.")
        |> close2()
        |> percent_heal(hp: -30, sp: 0)
        |> warp("prontera", 150, 150)

      _ ->
        ctx
    end
  end

  defp answer_questions(ctx) do
    {ctx, choice} =
      ctx
      |> mes(Rathena.concat(Rathena.concat("Ah, Master ", char_name(ctx, 0)), "."))
      |> mes("Welcome. How may I be")
      |> mes("of service today?")
      |> next()
      |> select(["Who is Arian?", "What is Metz doing?", "How is Elle?"])

    case choice do
      1 ->
        ctx
        |> mes("[Vandez]")
        |> mes("Ah yes, Arian.")
        |> mes("I consider him to be")
        |> mes("a man of few words. The")
        |> mes("words he does choose to")
        |> mes("use are rather harsh and")
        |> mes("brutish, you might say.")
        |> close()

      2 ->
        ctx
        |> mes("[Vandez]")
        |> mes("Although I've served")
        |> mes("the Brayde family for years,")
        |> mes("I'm unfamiliar with Master")
        |> mes("Metz's work. My apologies, but")
        |> mes("I simply cannot even begin to fathom his research...")
        |> close()

      3 ->
        ctx
        |> mes("[Vandez]")
        |> mes("Ah, Mistress Elle")
        |> mes("has been working here")
        |> mes("since she was a very young")
        |> mes("girl. She is almost like")
        |> mes("a granddaughter to me.")
        |> mes("Ha ha-^333333*Ahem*^000000")
        |> close()

      _ ->
        ctx
    end
  end
end
