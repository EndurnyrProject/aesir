defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsVeins.Sahedi do
  @moduledoc """
  Sahedi receives and acts on the volcano investigation reports.

  ## Behavior

  - Advances the investigation and returns a report after the warning.

  ## Credits

  - Original from rAthena, authors and Contributors
    - L0ne_W0lf
    - Toms
    - Euphy
    - Joseph
    - Everade

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "thor_camp",
        x: 250,
        y: 104,
        dir: 3,
        sprite: 934,
        name: "Sahedi",
        scope: :shared,
        unique_name: "Sahedi#vol"
      }
    ]

  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  def on_talk(ctx) do
    cond do
      max_weight(ctx) - weight(ctx) < 2000 or checkweight(ctx, [{1201, 1}]) == 0 ->
        ctx
        |> mes("^3355FFWait a second!")
        |> mes("Right now, you're carrying")
        |> mes("too many things with you.")
        |> mes("Please come back after")
        |> mes("using the Kafra Service")
        |> mes("to store some of your items.^000000")
        |> close()

      get_char_var(ctx, :aru_vol, 0) == 12 ->
        receive_report(ctx)

      get_char_var(ctx, :aru_vol, 0) > 12 and get_char_var(ctx, :aru_vol, 0) < 23 ->
        await_investigation(ctx)

      get_char_var(ctx, :aru_vol, 0) == 23 ->
        report_eruption(ctx)

      true ->
        ctx |> mes("[Sahedi]") |> mes("Argh, I'm so busy!") |> close()
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  defp receive_report(ctx) do
    ctx =
      ctx
      |> mes("[Sahedi]")
      |> mes("I'm sorry, but I don't")
      |> mes("think I know you. Only")
      |> mes("authorized personnel is")
      |> mes("allowed in this area, so")
      |> mes("if you don't have any")
      |> mes("reason to be here...")
      |> next()

    ctx =
      ctx
      |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
      |> mes("I'm a research student working")
      |> mes("under Director Gio for the")
      |> mes("Veins Geological Research")
      |> mes("Institute. Would you please")
      |> mes("stamp this temperature")
      |> mes("report for me?")
      |> next()

    ctx =
      ctx
      |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
      |> mes("Um, Gio is sick right")
      |> mes("now, so that's why he")
      |> mes("had me fill out this report")
      |> mes("form and submit it for him.")
      |> next()
      |> mes("[Sahedi]")
      |> mes("Ah, so that's why his")
      |> mes("report's late this time.")
      |> mes("I'm sorry to hear that.")
      |> mes("And here I thought he was")
      |> mes("just wasting his time on")
      |> mes("women and alcohol...")
      |> next()
      |> mes("[Sahedi]")
      |> mes("Let's see...")
      |> next()
      |> emotion(:huk)
      |> mes("[Sahedi]")
      |> mes("Oh God! Why is the")
      |> mes("temperature so high?!")
      |> mes("We've had a few reports")
      |> mes("like this in the past, but...")
      |> mes("Is this... How bad is this?")
      |> next()

    ctx = emotion(ctx, :profusely_sweat, playerattached(ctx))

    ctx =
      ctx
      |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
      |> mes("Oh... Oh, no!")
      |> mes("Yikes! I guess if it's")
      |> mes("higher than normal...")
      |> mes("It might be bad?")
      |> next()
      |> mes("[Sahedi]")
      |> mes("What should I do?")
      |> mes("Should I activate")
      |> mes("the alarm? I don't...")
      |> mes("I don't wanna die!")
      |> next()

    ctx
    |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
    |> mes("You might want to calm")
    |> mes("down first. I'll take a look")
    |> mes("around the camp, so please")
    |> mes("don't say anything that will")
    |> mes("make anyone else panic for now.")
    |> next()
    |> mes("[Sahedi]")
    |> mes("Okay...")
    |> mes("Please go ahead, and")
    |> mes("see if this camp will be")
    |> mes("safe from any disaster.")
    |> changequest(2121, 2122)
    |> set_char_var(:aru_vol, 13)
    |> delitem(7342, 1)
    |> close()
  end

  defp await_investigation(ctx) do
    ctx =
      ctx
      |> mes("[Sahedi]")
      |> mes("So, are we in any")
      |> mes("danger? Does it look")
      |> mes("like this volcano will")
      |> mes("erupt anytime soon?")
      |> next()

    ctx
    |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
    |> mes("Oh, I'm not finished")
    |> mes("investigating yet. Would")
    |> mes("you please wait a bit longer?")
    |> next()
    |> mes("[Sahedi]")
    |> mes("Sure, sure. Just make")
    |> mes("sure that you do a real")
    |> mes("thorough check of everything")
    |> mes("in the volcano for me, yeah?")
    |> close()
  end

  defp report_eruption(ctx) do
    ctx =
      ctx
      |> mes("[Sahedi]")
      |> mes("So, are we in any")
      |> mes("danger? Does it look")
      |> mes("like this volcano will")
      |> mes("erupt anytime soon?")
      |> next()
      |> ask_about_eruption()
      |> emotion(:huk)
      |> mes("[Sahedi]")
      |> mes("Huh? Are you serious?")
      |> mes("Thor Volcano's gonna")
      |> mes("erupt?! We-we have to")
      |> mes("get the hell out of here!")
      |> mes("It'll be a disaster, just")
      |> mes("like it happened in the past!")
      |> next()

    ctx = emotion(ctx, :spark, playerattached(ctx))

    ctx =
      ctx
      |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
      |> mes("Yes, I agree. There's")
      |> mes("a good chance of an...")
      |> mes("explosion that'll cause")
      |> mes("a lot of collateral damage.")
      |> next()
      |> mes("[Sahedi]")
      |> mes("What are our chances?")
      |> mes("How much time do we")
      |> mes("have to evacuate?")
      |> next()

    ctx = emotion(ctx, :spark, playerattached(ctx))

    ctx
    |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
    |> mes("Well... Uh...")
    |> mes("According to my data...")
    |> mes("Analysis... There's a 75%")
    |> mes("chance of eruption within")
    |> mes("the next thirty days.")
    |> next()
    |> mes("[Sahedi]")
    |> mes("What?! We must report")
    |> mes("this to the high priest")
    |> mes("immediately! Aitra!")
    |> next()
    |> enablenpc("Aitra#vol")
    |> mes("[Aitra]")
    |> mes("Yes, sir!")
    |> next()
    |> mes("[Sahedi]")
    |> mes("This is an emergency.")
    |> mes("Bring this message to")
    |> mes("the high priest as soon")
    |> mes("as possible. And don't")
    |> mes("forget to pack all your")
    |> mes("things before you leave.")
    |> next()
    |> mes("[Aitra]")
    |> mes("Huh?")
    |> mes(" ...Yes, sir.")
    |> next()
    |> disablenpc("Aitra#vol")
    |> mes("[Sahedi]")
    |> mes("Oh, this is a nightmare...")
    |> mes("Will you please take your")
    |> mes("report to your director, Gio?")
    |> mes("Hopefully he'll have some")
    |> mes("advice for what we can")
    |> mes("do about this disaster...")
    |> changequest(2128, 60211)
    |> set_char_var(:aru_vol, 24)
    |> give_item(7342, 1)
    |> close()
  end

  defp ask_about_eruption(ctx) do
    {ctx, choice} = select(ctx, ["Yes", "No"])

    if choice == 1 do
      ctx
      |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
      |> mes("I guess I can't hide it")
      |> mes("from you... The recent")
      |> mes("activity of this volcano")
      |> mes("has recently been fairly...")
      |> mes("disconcerting.")
      |> next()
    else
      ctx =
        ctx
        |> mes("^3355FFWait... You should take")
        |> mes("advantage of this situation.")
        |> mes("This could be your chance to")
        |> mes("intervene in the conflict")
        |> mes("between two contries!^000000")
        |> next()
        |> mes("^3355FFYou might not be able")
        |> mes("to stop their war, but")
        |> mes("maybe you can distract")
        |> mes("them with the threat")
        |> mes("of natural disaster...^000000")
        |> next()

      ask_about_eruption(ctx)
    end
  end
end
