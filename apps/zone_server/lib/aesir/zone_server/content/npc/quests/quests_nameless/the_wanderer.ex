defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsNameless.TheWanderer do
  @moduledoc """
  A restless warrior spirit recounts the events surrounding a cursed emerald.

  ## Behavior

  - Reveals the warrior's memories as the emerald quest progresses.
  - Appears temporarily when summoned and hides after key conversations.

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
        map: "gef_fild08",
        x: 182,
        y: 185,
        dir: 0,
        sprite: 739,
        name: "The Wanderer",
        scope: :shared
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

  def on_event("OnTimer60000", ctx) do
    ev_ontimer60000(ctx)
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  @impl true
  def on_talk(ctx) do
    cond do
      get_char_var(ctx, :jewel_nd, 0) < 21 ->
        ctx
        |> mes("[The Wanderer]")
        |> mes("I'm just a wanderer")
        |> mes("drifting through this")
        |> mes("world. Please just")
        |> mes("leave me in peace.")
        |> close()

      get_char_var(ctx, :jewel_nd, 0) == 21 ->
        if count_item(ctx, 7725) > 0 do
          ctx
          |> mes("[The Wanderer]")
          |> mes("That... That looks")
          |> mes("just like the emerald")
          |> mes("I used to own. Hmmm...")
          |> mes("Did you come looking for me?")
          |> next()
          |> mes("[The Wanderer]")
          |> mes("Get rid of that thing right")
          |> mes("now. It's an evil jewel that")
          |> mes("causes tragedy wherever")
          |> mes("it goes. I remember... I got")
          |> mes("that jewel from monsters...")
          |> next()
          |> mes("[The Wanderer]")
          |> mes("I was just a simple man,")
          |> mes("dreaming of becoming the")
          |> mes("world's greatest warrior.")
          |> mes("I had that emerald on me")
          |> mes("when we encountered a huge")
          |> mes("group of vicious Cobolds.")
          |> next()
          |> mes("[The Wanderer]")
          |> mes("No matter how many")
          |> mes("we killed, there was")
          |> mes("just no end to them...")
          |> mes("And then... We... We...")
          |> mes("I... It hurts too much")
          |> mes("to recall what happened...")
          |> set_char_var(:jewel_nd, 22)
          |> hideonnpc("The Wanderer")
          |> stopnpctimer()
          |> close()
        else
          ctx
          |> mes("[The Wanderer]")
          |> mes("Why have you summoned me?")
          |> mes("I'm just the soul of a fallen")
          |> mes("warrior, seeking peace.")
          |> mes("Please don't bother me")
          |> mes("if you can avoid it.")
          |> close()
        end

      get_char_var(ctx, :jewel_nd, 0) == 22 ->
        ctx
        |> mes("[The Wanderer]")
        |> mes("You again? Why do you still")
        |> mes("hold the jewel?! Didn't I just")
        |> mes("what happened to me and")
        |> mes("my comrades! We all died")
        |> mes("that day, that day the")
        |> mes("Cobolds overpowered us!")
        |> next()
        |> mes("[The Wanderer]")
        |> mes("Just let me return")
        |> mes("to my slumber.")
        |> set_char_var(:jewel_nd, 23)
        |> close()

      get_char_var(ctx, :jewel_nd, 0) == 25 ->
        {ctx, _} =
          ctx
          |> mes("[The Wanderer]")
          |> mes("Why have you called")
          |> mes("me here again? What")
          |> mes("is it you want from me?")
          |> mes("Can't you leave me alone?")
          |> next()
          |> select(["Were you really killed by Cobolds?"])

        ctx
        |> mes("[The Wanderer]")
        |> mes("Argh! What is it you're")
        |> mes("trying to say?! Leave now!")
        |> hideonnpc("The Wanderer")
        |> stopnpctimer()
        |> close()

      get_char_var(ctx, :jewel_nd, 0) == 26 ->
        {ctx, _} =
          ctx
          |> mes("[The Wanderer]")
          |> mes("Still you pester me.")
          |> mes("Unfortunately, the power")
          |> mes("of the jewel compels me")
          |> mes("to return to this plane...")
          |> mes("What is it this time?")
          |> next()
          |> select(["You weren't killed by Cobolds, were you?"])

        {ctx, _} =
          ctx
          |> mes("[The Wanderer]")
          |> mes("How many times must I tell")
          |> mes("you? Are you saying that")
          |> mes("I'm lying about the deaths")
          |> mes("of my comrades? Forget it.")
          |> mes("The dead shouldn't talk.")
          |> mes("It's a waste of my time.")
          |> next()
          |> mes("[The Wanderer]")
          |> mes("Take care, young")
          |> mes("adventurer, and don't")
          |> mes("reopen the wounds of")
          |> mes("the past anymore.")
          |> set_char_var(:jewel_nd, 27)
          |> next()
          |> recall_last_moment()
          |> recount_death()

        confront_warrior(ctx)

      get_char_var(ctx, :jewel_nd, 0) == 27 ->
        {ctx, _} =
          ctx
          |> mes("[The Wanderer]")
          |> mes("What is it?")
          |> mes("What could you")
          |> mes("possibly have to")
          |> mes("say to me this time?")
          |> next()
          |> recall_last_moment()
          |> recount_death()

        confront_warrior(ctx)

      get_char_var(ctx, :jewel_nd, 0) == 28 ->
        {ctx, _} =
          ctx
          |> mes("[The Wanderer]")
          |> mes("Why you...")
          |> next()
          |> select(["How did your comrades die?"])

        confront_warrior(ctx)

      get_char_var(ctx, :jewel_nd, 0) == 29 ->
        ctx |> mes("[The Wanderer]") |> mes("Leave me alone!") |> close()

      get_char_var(ctx, :jewel_nd, 0) > 29 ->
        ctx
        |> mes("[The Wanderer]")
        |> mes("Shut up! Stop harassing")
        |> mes("me! I can't... I don't...!")
        |> close()

      true ->
        ctx |> mes("[The Wanderer]") |> mes(".........") |> close()
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  def ev_oninit(ctx) do
    hideonnpc(ctx, "The Wanderer")
  end

  def ev_onenable(ctx) do
    ctx |> hideoffnpc("The Wanderer") |> initnpctimer()
  end

  def ev_ontimer60000(ctx) do
    ctx |> hideonnpc("The Wanderer") |> stopnpctimer()
  end

  defp recount_death(ctx) do
    ctx
    |> mes("[The Wanderer]")
    |> mes("I was killed... No, wait.")
    |> mes("I survived the battle with")
    |> mes("the Cobolds. Then, some")
    |> mes("coward killed me from")
    |> mes("behind, and stole my")
    |> mes("emerald. That must be it!")
    |> next()
    |> select(["How did your comrades die?"])
  end

  defp confront_warrior(ctx) do
    {ctx, _} =
      ctx
      |> mes("[The Wanderer]")
      |> mes("The Cobolds killed them!")
      |> mes("I was too weak to protect")
      |> mes("my comrades. Too weak...")
      |> mes("When I came back to my")
      |> mes("senses, they were all...")
      |> next()
      |> emotion(:think)
      |> mes("[The Wanderer]")
      |> mes("I'm not sure what")
      |> mes("happened. There was")
      |> mes("blood coming into my eyes...")
      |> mes("I remember slashing, and")
      |> mes("stabbing, and... And slashing.")
      |> next()
      |> select(["You slashed everything..."])

    ctx
    |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
    |> mes("You slashed everything...")
    |> mes("Even the comrades you")
    |> mes("were supposed to protect.")
    |> next()
    |> mes("[The Wanderer]")
    |> mes("I... I did...?")
    |> mes("I... No! Shut up!")
    |> mes("Stop it! I couldn't...")
    |> mes("Get out of here now!")
    |> mes("You're trying to trick me!")
    |> set_char_var(:jewel_nd, 29)
    |> hideonnpc("The Wanderer")
    |> stopnpctimer()
    |> close()
  end

  defp recall_last_moment(ctx) do
    {ctx, choice} =
      select(ctx, ["You killed your comrades!", "Do you remember your last moment?"])

    if choice == 1 do
      ctx
      |> mes("[The Wanderer]")
      |> mes("Did I...? Ha. Haha!")
      |> mes("adventurer, but that sounds")
      |> mes("like something from a trashy")
      |> mes("novel. Hah hah hah hah!")
      |> next()
      |> recall_last_moment()
    else
      ctx
      |> mes("[The Wanderer]")
      |> mes("It's a little hazy...")
      |> mes("I... We tried to kill as")
      |> mes("many Cobolds as we ")
      |> mes("could... Everyone was...")
      |> mes("Everyone was dead.")
      |> mes("Everyone but me.")
      |> next()
      |> mes("[The Wanderer]")
      |> mes("I was all alone.")
      |> mes("We killed all the")
      |> mes("Cobolds, but I was...")
      |> mes("Then... The next thing...")
      |> mes("I was covered in blood.")
      |> mes("Then, something appeared?")
      |> next()
      |> mes("[The Wanderer]")
      |> mes("No, it can't have been.")
      |> mes("A human soldier like me?")
      |> set_char_var(:jewel_nd, 28)
      |> next()
    end
  end
end
