defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsNameless.SuspiciousMan do
  @moduledoc """
  A Z Gang informer flees and is confronted during the investigation.

  ## Behavior

  - Runs the encounter on talk or touch and manages its shared timer and visibility.

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
        map: "moc_ruins",
        x: 90,
        y: 67,
        dir: 3,
        sprite: 99,
        name: "Suspicious Man",
        scope: :shared,
        unique_name: "Suspicious Man#1",
        trigger: {4, 4}
      },
      %{
        map: "moc_ruins",
        x: 75,
        y: 171,
        dir: 3,
        sprite: 99,
        name: "Suspicious Man",
        scope: :shared,
        unique_name: "Suspicious Man#2",
        trigger: {4, 4}
      }
    ]

  alias Aesir.ZoneServer.Script.Rathena
  @impl true
  def on_event("OnTimer30000", ctx) do
    ev_ontimer30000(ctx)
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  def on_event("OnInit", ctx) do
    ev_oninit(ctx)
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  def on_event("OnTouch_", ctx) do
    ev_ontouch(ctx)
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  @impl true
  def on_talk(ctx) do
    case get_char_var(ctx, :zdan_edq, 0) do
      9 ->
        investigate(ctx)

      10 ->
        confront(ctx)

      progress when progress < 9 ->
        dismiss(ctx)

      progress when progress < 15 ->
        ctx
        |> mes("[Z Gang Informer]")
        |> mes("Whoa, leave me alone!")
        |> mes("I'm just standing here")
        |> mes("on the road, I didn't")
        |> mes("do anything wrong!")
        |> close()

      _ ->
        ctx
        |> mes("[Former Z Gang Informer]")
        |> mes("You don't have to")
        |> mes("worry about me anymore.")
        |> mes("I've turned over a new")
        |> mes("leaf, got a real job,")
        |> mes("that sort of deal.")
        |> close()
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  defp investigate(ctx) do
    if get_server_temp_var(ctx, "zdan", 0) == 0 do
      encounter(ctx)
    else
      ctx = mes(ctx, "[Suspicious Man]")

      ctx =
        if strnpcinfo(ctx, 2) == "1" do
          ctx
          |> mes("...............................")
          |> mes("...............................")
          |> mes("............................... ")
        else
          mes(ctx, "... ...")
        end

      ctx = next(ctx)

      ctx
      |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
      |> mes("Something's not quite")
      |> mes("right. I should come back")
      |> mes("and investigate this area")
      |> mes("later when there are fewer")
      |> mes("people watching...")
      |> close()
    end
  end

  defp confront(ctx) do
    if get_server_temp_var(ctx, "zdan", 0) > 0 do
      ctx
      |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
      |> mes("Nuts! I was supposed")
      |> mes("to try to do this secretly!")
      |> mes("I better try to investigate")
      |> mes("this area again when no")
      |> mes("one is around here.")
      |> close()
    else
      interrogate(ctx) |> close()
    end
  end

  defp interrogate(ctx) do
    ctx =
      ctx
      |> set_server_temp_var("zdan", 1)
      |> initnpctimer()
      |> mes("[????]")
      |> mes("Eeek...!")
      |> next()

    ctx =
      ctx
      |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
      |> mes("Haha! Got you!")
      |> mes("You're an informer for")
      |> mes("the Z Gang, aren't you?")
      |> next()
      |> mes("[????]")
      |> mes("I... I... d-don't")
      |> mes("know what you're")
      |> mes("talking about!")
      |> mes("I'm innocent!")
      |> next()

    ctx =
      ctx
      |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
      |> mes("Then you're telling")
      |> mes("me this note didn't")
      |> mes("just fall out of your")
      |> mes("pocket? What's this")
      |> mes("about trying to kill me?")
      |> next()
      |> mes("[????]")
      |> mes("Th-that's...")
      |> mes("I'm not--That...!")
      |> next()

    ctx =
      ctx
      |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
      |> mes("You better confess, or")
      |> mes("I'll drag you over to the")
      |> mes("Prontera Knightage or the")
      |> mes("Rogue Guild to take care")
      |> mes("of you. In fact, let's just")
      |> mes("head over to Prontera...")
      |> next()
      |> mes("[Z Gang Informer]")
      |> mes("N-no! I'll tell you")
      |> mes("everything! Please!")
      |> mes("My mother's old! I've")
      |> mes("got kids to feed!")
      |> mes("I... I can't go to jail!")
      |> next()

    ctx =
      ctx
      |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
      |> mes("Alright.")
      |> mes("Let's start by you")
      |> mes("telling me where")
      |> mes("I can find the Z Gang.")
      |> next()
      |> mes("[Z Gang Informer]")
      |> mes("I... I really don't")
      |> mes("know where to find them.")
      |> mes("I'm at the bottom of the")
      |> mes("food chain, I just follow")
      |> mes("their written instructions.")
      |> next()

    ctx =
      ctx
      |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
      |> mes("You know what?")
      |> mes("Never mind. I'm won't")
      |> mes("take you to be jailed by")
      |> mes("the Prontera Knights.")
      |> mes("I'll drop you off")
      |> mes("at the Rogues.")
      |> next()
      |> mes("[Z Gang Informer]")
      |> mes("...............................")
      |> mes("Their secret hideout is in")
      |> mes("South Morocc, and you can't")
      |> mes("enter the place without the")
      |> mes("secret password.")
      |> next()

    ctx =
      ctx
      |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
      |> mes("Nice. Now, you better")
      |> mes("stop running with the")
      |> mes("Z Gang. Otherwise, I'm")
      |> mes("not going to be so merciful")
      |> mes("the next time I see you.")
      |> next()
      |> mes("[Z Gang Informer]")
      |> mes("Anything you want!")
      |> mes("J-just let me liiive!")
      |> next()

    ctx
    |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
    |> mes("I should head back to")
    |> mes("Marybell, and see if she's")
    |> mes("learned any new information.")
    |> changequest(3127, 3128)
    |> set_char_var(:zdan_edq, 11)
    |> set_server_temp_var("zdan", 0)
    |> stopnpctimer()
  end

  defp dismiss(ctx) do
    ctx =
      if strnpcinfo(ctx, 2) == "1" do
        mes(ctx, "[Suspicious Man]")
      else
        mes(ctx, "[Thug]")
      end

    ctx
    |> mes("What? Get lost!")
    |> mes("Listen, you don't")
    |> mes("want to mess with")
    |> mes("me. Just. Don't.")
    |> close()
  end

  def ev_ontimer30000(ctx) do
    set_server_temp_var(ctx, "zdan", 0)
  end

  def ev_oninit(ctx) do
    hideonnpc(ctx, "Suspicious Man#2")
  end

  def ev_ontouch(ctx) do
    if get_char_var(ctx, :zdan_edq, 0) == 9 and get_server_temp_var(ctx, "zdan", 0) == 0 do
      encounter(ctx)
    else
      ctx
    end
  end

  defp encounter(ctx) do
    ctx =
      ctx
      |> set_server_temp_var("zdan", 1)
      |> initnpctimer()
      |> mes("[????]")
      |> mes("I know you've")
      |> mes("been pursuing us!")
      |> mes("Grrrr... DIE NOW!")
      |> specialeffect(:steal)
      |> next()

    ctx =
      ctx
      |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
      |> mes("Wh-who are you?")
      |> next()
      |> mes("[????]")
      |> mes("Y-you're stronger")
      |> mes("than I thought!")
      |> mes("Run awaaaaay!")

    ctx =
      if strnpcinfo(ctx, 2) == "1" do
        ctx |> hideonnpc("Suspicious Man#1") |> hideoffnpc("Suspicious Man#2")
      else
        ctx |> hideonnpc("Suspicious Man#2") |> hideoffnpc("Suspicious Man#1")
      end

    ctx = ctx |> set_server_temp_var("zdan", 0) |> stopnpctimer() |> next()

    ctx =
      ctx
      |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "] "))
      |> mes("Huh? That man must")
      |> mes("have dropped this")
      |> mes("note in his haste")
      |> mes("to get away from here.")
      |> mes("Let's see what it says...")
      |> next()

    ctx =
      ctx
      |> mes(Rathena.concat(Rathena.concat("^666666Kill ", char_name(ctx, 0)), ", meow."))
      |> mes("That arrogant do-gooder")
      |> mes("is looking into us too much.")
      |> mes("Fail to kill him, and death")
      |> mes("will be too good for you, meow.^000000")
      |> next()

    ctx
    |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
    |> mes("That must have been")
    |> mes("an informer for the Z Gang.")
    |> mes("He can't have gotten too far:")
    |> mes("I have a chance to catch him!")
    |> changequest(3126, 3127)
    |> set_char_var(:zdan_edq, 10)
    |> close()
  end
end
