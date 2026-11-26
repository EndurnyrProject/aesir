defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsNameless.Valdes do
  @moduledoc """
  Valdes is a former knight with information about the Z Gang.

  ## Behavior

  - Requests wine in exchange for a lead on the gang.
  - Calls out to investigators who approach him.

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
        map: "prt_in",
        x: 168,
        y: 18,
        dir: 1,
        sprite: 65,
        name: "Valdes",
        scope: :shared,
        trigger: {2, 2}
      }
    ]

  alias Aesir.ZoneServer.Script.Rathena
  @impl true
  def on_event("OnTouch", ctx) do
    ev_ontouch(ctx)
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  @impl true
  def on_talk(ctx) do
    cond do
      checkweight(ctx, [{907, 100}]) == 0 ->
        ctx
        |> mes("^3355FFWait a second!")
        |> mes("Right now, you're carrying")
        |> mes("too many things with you.")
        |> mes("Please come back after")
        |> mes("using the Kafra Service")
        |> mes("to store some of your items.^000000")
        |> close()

      get_char_var(ctx, :zdan_edq, 0) == 2 ->
        discuss_investigation(ctx)

      get_char_var(ctx, :zdan_edq, 0) == 3 ->
        request_wine(ctx)

      get_char_var(ctx, :zdan_edq, 0) == 4 ->
        ctx
        |> mes("[Valdes]")
        |> mes("I suggest meeting")
        |> mes("Marybell in the Rogue")
        |> mes("Guild, and giving her the")
        |> mes("password, ''^0000FFThe dawn")
        |> mes("is yet to come^000000.''")
        |> close()

      true ->
        ctx
        |> mes("[Valdes]")
        |> mes("^666666*Sigh*^000000 It is my greatest")
        |> mes("wish that the knight master")
        |> mes("will allow me to rejoin the")
        |> mes("corps. However, I doubt that")
        |> mes("he's forgiven my failure. ^666666*Sob*^000000")
        |> mes("It's like my life is over...")
        |> close()
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  defp discuss_investigation(ctx) do
    ctx =
      ctx
      |> mes("[Valdes]")
      |> mes("^666666*Urp*^000000 What?")
      |> mes("You here to... ")
      |> mes("Um, commiserate")
      |> mes("about failing life too?")
      |> next()

    {ctx, choice} =
      ctx
      |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
      |> mes("Are you Valdes?")
      |> mes("I came to ask you")
      |> mes("for your help...")
      |> next()
      |> mes("[Valdes]")
      |> mes("^666666*Hiccup*^000000 Why~?")
      |> mes("I'm-I'm no good")
      |> mes("to anybody anymore!")
      |> next()
      |> select(["Ask About Z Gang", "The chief officer is worried about you.", "Bye!"])

    case choice do
      1 ->
        ctx
        |> mes("[Valdes]")
        |> mes("That Z Gang...")
        |> mes("Ruined my life!")
        |> mes("My career, my pension...")
        |> mes("It's all gone because")
        |> mes("of those damn criminals!")
        |> next()
        |> mes("[Valdes]")
        |> mes("You? Capture them?")
        |> mes("Good luck! Just... Just")
        |> mes("try not to end up like me.")
        |> mes("Oh, you want info-information?")
        |> mes("^666666*Hic*^000000 Heh, scratch my back,")
        |> mes("well, you know the rest.")
        |> next()
        |> mes("[Valdes]")
        |> mes("Heh, I just ran out of wine!")
        |> mes("Gimme, um, ^0000FFMorocc Fruit Wine^000000!")
        |> mes("5 bottles! Then... Maybe...")
        |> mes("I'll tell you want you really")
        |> mes("wanna know. Heh heh~ ^666666*Hic!*^000000")
        |> changequest(3120, 3121)
        |> set_char_var(:zdan_edq, 3)
        |> close()

      2 ->
        ctx
        |> mes("[Valdes]")
        |> mes("R-really? Well...")
        |> mes("I don't care! Just")
        |> mes("let me drink in peace!")
        |> close()

      3 ->
        ctx
        |> mes("[Valdes]")
        |> mes("Wha--? Who do you think")
        |> mes("you're messing with, ^666666*Hic!*^000000")
        |> mes("just comin' by to say ''bye?!''")
        |> mes("I useta be a knight once,")
        |> mes("you know that? I could")
        |> mes("totally kick your--^666666*Urp!*^000000")
        |> close()

      _ ->
        ctx
    end
  end

  defp request_wine(ctx) do
    ctx =
      ctx |> mes("[Valdes]") |> mes("Heeeey yoooou~") |> mes("You bring me wine?") |> next()

    if count_item(ctx, 12049) > 4 do
      ctx =
        ctx
        |> delitem(12049, 5)
        |> mes("[Valdes]")
        |> mes("^666666*Sniff*^000000 Yeeesh, that")
        |> mes("smeells good. This must")
        |> mes("be it. Oh, yeah. Knight's")
        |> mes("honor. First I talk, then")
        |> mes("I can drink theesh...")
        |> next()
        |> mes("[Valdes]")
        |> mes("Well, maybe...")
        |> mes("Just one tashte~")
        |> mes("^666666*Gulp Gulp Gulp*^000000")
        |> next()

      ctx =
        ctx
        |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
        |> mes("You just...")
        |> mes("That was three bottles!")
        |> next()
        |> mes("[Valdes]")
        |> mes("Ah, delicious!")
        |> mes("Alright, fellow,")
        |> mes("now I feel better")
        |> mes("able to speak now~")
        |> next()

      ctx
      |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
      |> mes("(^666666Whaaaat~?^000000)")
      |> next()
      |> mes("[Valdes]")
      |> mes("I assume you already know")
      |> mes("the basic information about")
      |> mes("the Z Gang, their members,")
      |> mes("et cetera. I'm not sure why")
      |> mes("they've gone on such a brazen")
      |> mes("crime spree so suddenly.")
      |> next()
      |> mes("[Valdes]")
      |> mes("Their success is unprecedented:")
      |> mes("they've even managed to elude")
      |> mes("the Rogue Guild repeatedly.")
      |> mes("I investigated them six")
      |> mes("months ago, but I was")
      |> mes("dismissed for my failure.")
      |> next()
      |> mes("[Valdes]")
      |> mes("I am aware that the Z Gang")
      |> mes("has many informers in their")
      |> mes("employ, and that the Rogue")
      |> mes("Guild are still investigating")
      |> mes("the Z Gang on their own.")
      |> next()
      |> mes("[Valdes]")
      |> mes("I suggest meeting one")
      |> mes("of the Rogue agents,")
      |> mes("Marybell, in the Rogue")
      |> mes("Guild. The password you")
      |> mes("must give her is ''^0000FFThe")
      |> mes("dawn is yet to come^000000.''")
      |> next()
      |> mes("[Valdes]")
      |> mes("That is all I can tell you.")
      |> mes("Please give my regards to")
      |> mes("Marybell for me, and catch")
      |> mes("those Z Gang bastards.")
      |> mes("^666666*Sigh*^000000 I think I'll go rest")
      |> mes("a bit now. Good luck!")
      |> changequest(3121, 3122)
      |> set_char_var(:zdan_edq, 4)
      |> close()
    else
      ctx
      |> mes("[Valdes]")
      |> mes("You stinkface!")
      |> mes("Where's my wine?!")
      |> mes("My ^0000FF5 bottles of")
      |> mes("Morocc Fruit Wine^000000?!")
      |> mes("I'm not gonna talk")
      |> mes("to you without it!")
      |> close()
    end
  end

  def ev_ontouch(ctx) do
    if get_char_var(ctx, :zdan_edq, 0) == 2 do
      ctx
      |> mes("[Valdes]")
      |> mes("^666666*Sigh*^000000 Goddamn thieves.")
      |> mes("Why should I even care")
      |> mes("about them?! They're not")
      |> mes("my problem anymore...")
      |> mes("^666666*Hiccup*^000000")
      |> close()
    else
      ctx
    end
  end
end
