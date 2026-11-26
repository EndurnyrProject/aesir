defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsProntera.Marjana do
  @moduledoc """
  Marjana advises investigators about poison.

  ## Behavior

  - At the appropriate quest stage, explains poison detection and advances the investigation.
  - Her events enable or disable her appearance.

  ## Credits

  - Original from rAthena, authors and Contributors
    - kobra_k88
    - L0ne_W0lf
    - Lupus
    - Silent
    - Evera
    - Samuray22
    - SinSloth
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
        map: "que_job01",
        x: 10,
        y: 16,
        dir: 5,
        sprite: 885,
        name: "Marjana",
        scope: :shared,
        unique_name: "Marjana#poison"
      }
    ]

  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  def on_event("OnInit", ctx) do
    ev_oninit(ctx)
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  def on_event("OnEnable", ctx) do
    ev_onenable(ctx)
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  @impl true
  def on_talk(ctx) do
    if get_char_var(ctx, :prt_curse, 0) == 24 do
      ctx =
        ctx
        |> mes("[Marjana]")
        |> mes("What business brings")
        |> mes("you here? I'm giving")
        |> mes("you 4 minutes to speak")
        |> mes("with me, so be direct.")
        |> next()

      ctx =
        ctx
        |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
        |> mes("I want to learn")
        |> mes("more about poison")
        |> mes("and confirm if it was")
        |> mes("used to kill someone.")
        |> next()
        |> mes("[Marjana]")
        |> mes("Poison? You've come")
        |> mes("to just the right person.")
        |> mes("If I don't know the answer,")
        |> mes("I doubt you'll find anyone")
        |> mes("else that would. Ask away.")
        |> next()

      ctx =
        ctx
        |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
        |> mes("Is it true that an")
        |> mes("Assassin's poison")
        |> mes("can be so powerful,")
        |> mes("that just one drop")
        |> mes("can kill a person?")
        |> next()
        |> mes("[Marjana]")
        |> mes("It's true that such powerful")
        |> mes("poison exists, but such deadly")
        |> mes("poison is usually only used by")
        |> mes("Assassin Crosses. Generally,")
        |> mes("normal Assassins use poisons")
        |> mes("that are much less potent.")
        |> next()

      ctx =
        ctx
        |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
        |> mes("Alright. Can you make")
        |> mes("a poison that leaves a")
        |> mes("specific mark on the body?")
        |> next()
        |> mes("[Marjana]")
        |> mes("Sure. There's all kinds of")
        |> mes("poisons that exist that I'm")
        |> mes("sure you can't even imagine.")
        |> mes("However, poisons that leave")
        |> mes("specific marks are difficult to")
        |> mes("use, and few can handle them.")
        |> next()
        |> mes("[Marjana]")
        |> mes("The types of marks")
        |> mes("that are left behind all")
        |> mes("depend on the materials")
        |> mes("used to create the poison.")
        |> mes("Since some materials are")
        |> mes("exclusive to certain areas...")
        |> next()
        |> mes("[Marjana]")
        |> mes("Well, the type of mark")
        |> mes("that was left behind could")
        |> mes("actually serve as some kind")
        |> mes("of clue. What was the mark")
        |> mes("on the victim's body?")
        |> next()

      ctx
      |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
      |> mes("We're not sure if")
      |> mes("poison was used yet,")
      |> mes("but there are marks that")
      |> mes("look like snake scales")
      |> mes("left on the bodies.")
      |> next()
      |> mes("[Marjana]")
      |> mes("Hmm. You know, if I had")
      |> mes("to guess, I would say that")
      |> mes("poison was probably used.")
      |> mes("But the poison would have")
      |> mes("to originate from outside of")
      |> mes("the Rune-Midgarts Kingdom...")
      |> next()
      |> mes("[Marjana]")
      |> mes("Yeah...")
      |> mes("The materials used to")
      |> mes("make those snake scale")
      |> mes("marks... Some of them can't")
      |> mes("even be found here on the")
      |> mes("Midgard continent.")
      |> next()
      |> mes("[Marjana]")
      |> mes("We're running out of time.")
      |> mes("Listen, you can confirm whether")
      |> mes("poison was used to kill someone")
      |> mes("by mixing a Yellow Gemstone with a Green Potion, and sprinkling")
      |> mes("the solution on the body.")
      |> next()
      |> mes("[Marjana]")
      |> mes("If poison was used, the")
      |> mes("solution with react with")
      |> mes("the body. But this method")
      |> mes("won't work if too much time")
      |> mes("has passed after the murder.")
      |> mes("You better try this soon...")
      |> set_char_var(:prt_curse, 25)
      |> close()
    else
      ev_oninit(ctx)
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  def ev_oninit(ctx) do
    disablenpc(ctx, "Marjana#poison")
  end

  def ev_onenable(ctx) do
    enablenpc(ctx, "Marjana#poison")
  end
end
