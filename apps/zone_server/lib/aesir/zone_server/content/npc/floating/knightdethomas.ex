defmodule Aesir.ZoneServer.Content.Npc.Floating.Knightdethomas do
  @moduledoc """
  De Thomas Carlos, Knight of Prontera's 3rd Cavalry, who teaches veteran Swordsmen the
  Moving HP Recovery skill.

  ## Behavior

  - Approaching him as a Swordsman of job level 35+, Knight, or Crusader prompts a pitch for the
    skill and, if accepted, the list of requirements.
  - Talking to him with 200 Empty Bottles and a Moth Wing offers to trade them for the skill.
  - Players who already know the skill get a greeting; unqualified players get an introduction.

  ## Credits

  - Original from rAthena, authors and Contributors
    - kobra_k88
    - Lupus
    - Silentdragon
    - MasterOfMuppets
    - IVBela
    - L0ne_W0lf
    - Masao
    - Euphy

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "izlude_in",
        x: 118,
        y: 175,
        dir: 2,
        sprite: 98,
        name: "Knight De Thomas",
        scope: :renewal,
        trigger: {4, 4}
      },
      %{
        map: "izlude_in",
        x: 175,
        y: 130,
        dir: 2,
        sprite: 98,
        name: "Knight De Thomas",
        scope: :pre_renewal,
        trigger: {4, 4}
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Rathena

  @moving_recovery 144
  @empty_bottle 713
  @moth_wing 1058

  @impl true
  @spec on_event(String.t(), Ctx.t()) :: Ctx.t()
  def on_event("OnTouch", ctx) do
    if veteran_swordman?(ctx), do: pitch_skill(ctx), else: ctx
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    cond do
      not veteran_swordman?(ctx) -> introduce(ctx)
      getskilllv(ctx, @moving_recovery) == 1 -> greet_graduate(ctx)
      has_offering?(ctx) -> offer_skill(ctx)
      true -> missing_items(ctx)
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  defp veteran_swordman?(ctx) do
    Rathena.job_id(base_class(ctx)) == Rathena.job_id(:swordman) and
      (job_level(ctx) >= 35 or
         Rathena.job_id(base_job(ctx)) == Rathena.job_id(:knight) or
         Rathena.job_id(base_job(ctx)) == Rathena.job_id(:crusader))
  end

  defp has_offering?(ctx),
    do: count_item(ctx, @empty_bottle) >= 200 and count_item(ctx, @moth_wing) >= 1

  defp introduce(ctx) do
    ctx
    |> mes("[De Thomas]")
    |> mes("My name is De Thomas Carlos.")
    |> mes("Knight of Prontera's 3rd Calvary.")
    |> mes("I have a certain duty these days.")
    |> mes("Ehem! Need I say more.")
    |> close()
  end

  defp greet_graduate(ctx) do
    ctx
    |> mes("[De Thomas]")
    |> mes("Oh, it's you?")
    |> mes("Long time no see!")
    |> mes("You seem healthier than before.")
    |> mes("Hahahaha!")
    |> mes("Take care! See you again!")
    |> close()
  end

  defp offer_skill(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[De Thomas]")
      |> mes("Welcome back...")
      |> mes("Are you ready to learn Body Movin'?")
      |> next()
      |> select(["Yes.", "No, I'm not ready yet."])

    case choice do
      1 ->
        teach_skill(ctx)

      2 ->
        ctx
        |> mes("[De Thomas]")
        |> mes("Is that so?")
        |> mes("Then come when you are prepared.")
        |> close()

      _ ->
        ctx
    end
  end

  defp teach_skill(ctx) do
    ctx
    |> mes("[De Thomas]")
    |> mes("Let's see.....")
    |> next()
    |> mes("[De Thomas]")
    |> mes("Ok! I shall now teach you...")
    |> mes("...The Body Movin' skill!")
    |> next()
    |> delitem(@empty_bottle, 200)
    |> delitem(@moth_wing, 1)
    |> skill(@moving_recovery, 1, :permanent)
    |> mes("[De Thomas]")
    |> mes("There you go!")
    |> mes("Try it yourself.")
    |> mes("But don't overdo it.")
    |> next()
    |> mes("[De Thomas]")
    |> mes("Oh yeah, I won't be needing your")
    |> mes("armor so you can keep it.")
    |> mes("Good luck now!")
    |> close()
  end

  defp missing_items(ctx) do
    ctx
    |> mes("[De Thomas]")
    |> mes("Hmmm... He's a swordsman...")
    |> mes("You know that I am De Thomas Carlos, right?")
    |> mes("Knight of Prontera's 3rd Calvary.")
    |> mes("De Thomas Carlos!")
    |> next()
    |> mes("[De Thomas]")
    |> mes("You do not have all the items I asked for.")
    |> next()
    |> mes("[De Thomas]")
    |> mes(
      "Remember, I need ^008800200 empty bottles^000000, your armor, and a ^008800Moth Wing^000000. Come back when you have it all."
    )
    |> close()
  end

  defp pitch_skill(ctx) do
    ctx =
      ctx
      |> mes("[De Thomas]")
      |> mes("Oh, no! You must have been hurt! Are you ok?")
      |> mes("You must have fought hard to get such serious injuries..")
      |> mes("Being a swordsman must come with a lot of responsibility and sacrifice.")
      |> next()
      |> mes("[De Thomas]")

    {ctx, choice} =
      ctx
      |> mes(skill_audience(ctx))
      |> mes("I present to you - HP Recovery While Moving!")
      |> mes("Body moving is a splendid skill")
      |> mes("that allows you to regain strength(HP)")
      |> mes("while you are moving!")
      |> next()
      |> mes("[De Thomas]")
      |> mes("It is currently under development")
      |> mes("so it may not recover that much,")
      |> mes("but it will help a little.")
      |> mes("What do you think? Would you like to learn this skill?")
      |> next()
      |> select(["What a nice skill! I want to learn it!", "No, thank you."])

    case choice do
      1 -> explain_requirements(ctx)
      2 -> ctx |> mes("[De Thomas]") |> mes("...") |> close()
      _ -> ctx
    end
  end

  defp skill_audience(ctx) do
    if sex(ctx) == 1,
      do: "For these swordsmen and knights, there is a wonderful skill.",
      else: "For these swordswomen and knights, there is a wonderful skill young lady."
  end

  defp explain_requirements(ctx) do
    {ctx, _} =
      ctx
      |> mes("[De Thomas]")
      |> mes("Very well. I will tell you what you need to learn this skill.")
      |> mes("First, your job level must be higher than ^00880035^000000.")
      |> mes("You will also need ^008800200 empty bottles^000000.")
      |> mes("Why? Because it is proof that you fought fiercely to have used that many potions.")
      |> next()
      |> mes("[De Thomas]")
      |> mes("Also, the armor you used in battle.")
      |> mes("This is also proof of an experienced fighter.")
      |> mes("For the armor... your armor is perfect!")
      |> mes("Bring your armor!")
      |> mes("Last but not least... bring me one ^008800Moth Wing^000000.")
      |> next()
      |> select(["Eh? You need that, too?"])

    ctx
    |> mes("[De Thomas]")
    |> mes("Not really.. I don't really NEED it.")
    |> mes(
      "It's just that my niece has gotten a bug hunting as a holiday task during the summer vacation."
    )
    |> mes("Of course! It would be much easier for me to get it myself.")
    |> mes(
      "but I must work here all the time so I don't exactly have the time to go out and get it."
    )
    |> next()
    |> mes("[De Thomas]")
    |> mes(
      "Don't you think it is pitiful that I have to stay in once place everyday, not being able to go outside?"
    )
    |> mes("Please, find me one...*sniffsniff*")
    |> mes("If you don't...")
    |> close()
  end
end
