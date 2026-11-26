defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsVeins.RachelGuard do
  @moduledoc """
  Guards the high priest and can be distracted during the volcano investigation.

  ## Behavior

  - Distracts Karlum with a message from Lamir and temporarily clears the way.
  - Returns intruders to the hallway.

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
        map: "ra_temin",
        x: 87,
        y: 133,
        dir: 1,
        sprite: 934,
        name: "Rachel Guard",
        scope: :shared,
        unique_name: "Rachel Guard#vol1",
        trigger: {5, 2}
      }
    ]

  alias Aesir.ZoneServer.Script.Rathena
  @impl true
  def on_event("OnInit", ctx) do
    ev_oninit(ctx)
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  def on_event("OnTouch", ctx) do
    ev_ontouch(ctx)
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  @impl true
  def on_talk(ctx) do
    case get_char_var(ctx, :aru_vol, 0) do
      2 ->
        {ctx, _} =
          ctx
          |> mes("[Guard Karlum]")
          |> mes("High Priest Vildt isn't")
          |> mes("here right now. Please")
          |> mes("come back later if you")
          |> mes("wish to see him.")
          |> next()
          |> select(["Think of a Distraction"])

        ctx =
          ctx
          |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
          |> mes("This guy's not going to")
          |> mes("let me pass. Let's see...")
          |> mes("Is there some way I could")
          |> mes("get him to leave? What, or")
          |> mes("even ^FF0000who^000000, could distract him?")
          |> next()

        {ctx, answer} =
          ctx
          |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
          |> mes("Wait a second...")
          |> mes("Of course! I should")
          |> mes("talk to him about...")
          |> next()
          |> input(:string)

        ctx = set_local(ctx, :"input$", answer)

        ctx =
          ctx
          |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
          |> mes("Wait a second...")
          |> mes("Of course! I should")

        ctx =
          ctx
          |> mes(
            Rathena.concat(
              Rathena.concat("talk to him about ^FF0000", get_local(ctx, :"input$", "")),
              "^000000 !!"
            )
          )
          |> next()

        if get_local(ctx, :"input$", "") != "Lamir" do
          ctx
          |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
          |> mes("What the...?")
          |> mes("Where did I think of that?")
          |> mes("That doesn't make any sense...")
          |> close()
        else
          ctx =
            ctx
            |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
            |> mes("That's right! I talked")
            |> mes("to Lamir a while ago.")
            |> mes("If she's right, then this")
            |> mes("guy must be Karlum, the guy")
            |> mes("who's totally in love with her.")
            |> mes("Hmm... I know what I'll say...")
            |> next()

          ctx =
            ctx
            |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
            |> mes("^333333*Ahem*^000000 Excuse me,")
            |> mes("but are you Karlum?")
            |> mes("I've got a message for you.")
            |> next()
            |> mes("[Guard Karlum]")
            |> mes("A message for me?")
            |> mes("Is that why you're still")
            |> mes("loitering around? Well,")
            |> mes("spit it out. I can't waste")
            |> mes("too much time on the job...")
            |> next()

          ctx =
            ctx
            |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
            |> mes("You know ^3131FFLamir^000000, right?")
            |> next()
            |> emotion(:huk)
            |> mes("[Guard Karlum]")
            |> mes("Lamir? Oh... My.")
            |> mes("Oh no! Did something")
            |> mes("bad happen to her?")
            |> mes("Quick, tell me!")
            |> next()

          ctx =
            ctx
            |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
            |> mes("No, nothing like that.")
            |> mes("She just told me that she")
            |> mes("had something important to")
            |> mes("tell you, and that you had to")
            |> mes("come see her when you're free.")
            |> next()

          ctx
          |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
          |> mes("I tried to ask her")
          |> mes("more, but she just kept")
          |> mes("blushing and turning away.")
          |> mes("Is there something going")
          |> mes("on between you too?")
          |> next()
          |> mes("[Guard Karlum]")
          |> mes("...I don't believe it.")
          |> mes("Finally. After all these")
          |> mes("years. She feels the same")
          |> mes("way I feel for her! My midnight")
          |> mes("serenade a few days ago")
          |> mes("must've touched her heart.")
          |> next()
          |> mes("[Guard Karlum]")
          |> mes("Screw this stupid job!")
          |> mes("I've made my choice, and")
          |> mes("I choose true love! I can't")
          |> mes("keep Lamir waiting any longer!")
          |> set_char_var(:aru_vol, 3)
          |> donpcevent("vol_time::OnEnable")
          |> close2()
          |> disablenpc("Rachel Guard#vol1")
        end

      stage when stage > 2 and stage < 5 ->
        ctx =
          ctx
          |> mes("[Guard Karlum]")
          |> mes("Hey! Lamir told me that")
          |> mes("she didn't want to see")
          |> mes("me at all! What's your")
          |> mes("game, huh? Do you think")
          |> mes("I'm that easy to trick?")
          |> next()

        ctx
        |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
        |> mes("What? Is that what")
        |> mes("happened? I could've")
        |> mes("sworn th--Oooh. I get it now.")
        |> mes("She must be playing hard to")
        |> mes("get. That must mean that")
        |> mes("she's reeeeally into you.")
        |> next()
        |> mes("[Guard Karlum]")
        |> mes("Ah! That makes perfect")
        |> mes("sense! No wonder she treated")
        |> mes("me that way! Hahaha! I should")
        |> mes("have figured it out sooner!")
        |> mes("Well then, I should go see")
        |> mes("her and play hard to get too!")
        |> donpcevent("vol_time::OnEnable")
        |> close2()
        |> disablenpc("Rachel Guard#vol1")

      _ ->
        ctx
        |> mes("[Guard Karlum]")
        |> mes("High Priest Vildt isn't")
        |> mes("here right now. Please")
        |> mes("come back later if you")
        |> mes("wish to see him.")
        |> close()
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  def ev_oninit(ctx) do
    enablenpc(ctx, "Rachel Guard#vol1")
  end

  def ev_ontouch(ctx) do
    warp(ctx, "ra_temin", 85, 137)
  end
end
